@tool
class_name PropZoneBaker
extends RefCounted

## The engine behind PropNavZones3D and PropNavZones2D: bakes a navmesh in square zones (a
## PropZoneGrid), so a change re-bakes only the zones it touches. On the main thread it parses the
## source geometry (or reuses the last parse) and reads the props' shapes into projected
## obstructions, only those near the zones that bake. The zones bake on worker threads, and the
## PropNavIndex of the whole navmesh is built on one too, so the main thread only swaps
## references. Each zone bakes with its own filter and border, so its piece meets the next one
## exactly on the zone line. The pieces wait in a result until `apply()`, always in zone order: the
## outcome depends only on the inputs, never on which zone finished first. With `manual_apply` a
## result of a change in play waits for the game to call `apply()`; the kit's own bakes (the start,
## a stale saved bake) are applied at once. A request while a bake runs waits and is joined with
## the next ones. With `follow`, a prop that enters or leaves the tree under `root` re-bakes where
## it stands. The node owns the regions: `piece_changed` says which zone gets which piece.

## A result of a change in play waits for `apply()` (`manual_apply`): the zones it re-baked.
signal bake_ready(zones: PackedInt32Array)
## The pieces of `zones` are in force.
signal applied(zones: PackedInt32Array)
## Zone `zone` has a new piece (null = nothing walkable there).
signal piece_changed(zone: int, piece: Resource)
## A saved bake does not match the props it would be used with.
signal stale

var is_3d := true
## The settings of every piece: a NavigationMesh (3D) or a NavigationPolygon (2D).
var template: Resource
## What gets parsed, and under which the obstruction nodes are looked for.
var root: Node
var grid := PropZoneGrid.new()
## Non-walkable margin baked around each zone (world units), so the pieces meet exactly.
var border := 0.0
## 3D: floor (x) and ceiling (y) of every zone's bake (y <= x: the parse's, with a margin).
var height_range := Vector2.ZERO
var group: StringName = PropObstructions.GROUP
var sides := 6
var merge_gap := 0.0
var carve := false
## True: a result waits for `apply()`. False: it is applied when ready.
var manual_apply := false
## Build a PropNavIndex with every bake.
var with_index := true
## Re-bake where a prop enters or leaves the tree under `root` (from `start_following()` on).
var follow := false
## True when the pieces in force are a saved bake's, with no bake since.
var from_saved := false
## Optional: `func() -> int`, a number from the game that changes when what the navmesh is baked
## from changes besides the props (the terrain's heights, a building's place). It joins the
## props' fingerprint, so a saved bake goes stale when either changes.
var extra_fingerprint := Callable()
var stats := PropNavStats.new()
## The pieces in force, one per zone (null = not baked yet, or nothing walkable).
var pieces: Array[Resource] = []
## The index of the pieces in force (null without `with_index`, or before the first bake).
var index: PropNavIndex

var _area := Rect2()
var _zone_size := 64.0
var _parsed: Resource
var _parsed_obstructions: Array = []
var _nodes_by_zone: Dictionary[int, Array] = {}
var _indexed := -1
var _outside := 0
var _warned_layers := false
var _job := PackedInt32Array()
var _job_pieces: Dictionary[int, Resource] = {}
var _waiting := 0
## The running bake: a WorkerThreadPool group task (one element per zone of the job), and the
## piece each element bakes. -1 = none; -2 = collected by `wait()`.
var _bake_group := -1
var _job_list: Array[Resource] = []
var _index_task := -1
var _next_index: PropNavIndex
## The running job came from the game (waits for `apply()` with `manual_apply`) or the kit.
var _job_by_game := false
var _job_saved := false
var _saved_fingerprint := 0
var _bake_started_us := 0
var _has_result := false
var _queued := false
var _queued_all := false
var _queued_reparse := false
var _queued_by_game := false
var _queued_rects: Array[Rect2] = []
var _following := false
## Props seen entering, and the areas of props that left, since the last flush.
var _arrived: Array[Node] = []
var _left: Array[Rect2] = []
var _flush_queued := false
## Last known area of each obstruction node (instance id), and the nodes followed out.
var _rect_of: Dictionary[int, Rect2] = {}
var _watched: Dictionary[int, bool] = {}


## Sets what to bake: the zones of side `zone_size` over `area` (empty = the parsed geometry's
## bounds) with a border of `zone_border` (0 = from the template's agent radius and cell size).
func configure(
	what: Resource, under: Node, area: Rect2, zone_size: float, zone_border: float
) -> void:
	template = what
	root = under
	_area = area
	_zone_size = zone_size
	var cell := _cell_size()
	var auto := maxf(_agent_radius() * 2.0 + cell * 2.0, cell * 8.0)
	border = zone_border if zone_border > 0.0 else auto
	border = ceilf(border / cell - 0.001) * cell
	var off := fmod(zone_size, cell)
	if off > 0.001 and cell - off > 0.001:
		push_warning(
			"PropZoneBaker: zone size %s is not a multiple of the cell size %s" % [zone_size, cell]
		)
	if area.has_area():
		_set_grid(PropZoneGrid.new(area, zone_size))


## Re-bakes the zones whose baking area touches one of `rects` (ground plane, world units).
## `reparse` = parse the geometry again (it changed); false = only the props changed. `by_game`
## false: the kit's own bake, applied at once even with `manual_apply`.
func request(rects: Array[Rect2], reparse := true, by_game := true) -> void:
	if is_busy():
		_queue(rects, false, reparse, by_game)
		return
	_start(rects, false, reparse, by_game)


## Re-bakes every zone.
func request_all(reparse := true, by_game := true) -> void:
	if is_busy():
		_queue([], true, reparse, by_game)
		return
	_start([], true, reparse, by_game)


## Re-bakes where `node` stood when last seen and where it stands now: it moved or changed shape.
func request_prop(node: Node) -> void:
	var rects: Array[Rect2] = []
	var id := node.get_instance_id()
	if _rect_of.has(id):
		rects.append(_rect_of[id])
	var now := PropObstructions.area_of(node, is_3d, sides)
	if now.has_area():
		rects.append(now)
		_rect_of[id] = now
	# The index of nodes by zone no longer knows where it is.
	_indexed = -1
	if not rects.is_empty():
		request(rects, false)


## From now on a prop that enters or leaves the tree under `root` re-bakes where it stands (with
## `follow`). Before, the start covers every prop there is.
func start_following() -> void:
	_following = true


## For SceneTree.node_added: notes a node that entered under `root`. Whether it is a prop is
## looked at the end of the frame, so a group added right after `add_child()` counts.
func on_node_added(node: Node) -> void:
	if not follow or not _following or root == null:
		return
	if root.is_ancestor_of(node):
		_arrived.append(node)
		_flush_later()


## True while props that entered or left wait to be re-baked (until the end of the frame).
func has_pending() -> bool:
	return _flush_queued


## True while a bake or its index runs, or a result waits for `apply()`.
func is_busy() -> bool:
	return _waiting > 0 or _index_task >= 0 or _has_result


## True when nothing is running: a result, if any, is ready for `apply()` without waiting.
func is_done() -> bool:
	return _waiting == 0 and _index_task < 0


## True when a baked result waits for `apply()`.
func has_result() -> bool:
	return _has_result


## Swaps the waiting result in, in zone order, then starts any waiting request.
func apply() -> void:
	if not _has_result:
		return
	_has_result = false
	var zones := _job.duplicate()
	zones.sort()
	for zone in zones:
		pieces[zone] = _job_pieces.get(zone)
		piece_changed.emit(zone, pieces[zone])
	if with_index:
		index = _next_index
	_next_index = null
	_job_pieces.clear()
	from_saved = _job_saved
	applied.emit(zones)
	_run_queue()


## Blocks until the zones baking now and the index are done: for a node about to be freed or a
## game that quits, so no worker is left running on its data.
func wait() -> void:
	if _bake_group >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_bake_group)
		_bake_group = -2
	if _index_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_index_task)
		_index_task = -2


## Puts `saved` in force with its index (built on a worker first, so both swap in together).
## False when it holds no pieces; when it was cut on another grid (zone size, border or area), so
## it cannot be used at all; or when it does not match the props and settings and `rebake` is on.
## The last two emit `stale`, and the caller bakes every zone. Without `rebake` a stale bake on
## the same grid is used as it is.
func load_saved(saved: PropNavBake, rebake := true) -> bool:
	if saved == null or saved.pieces.is_empty():
		return false
	var saved_grid := PropZoneGrid.new(saved.area, saved.zone_size)
	var same_grid := (
		is_equal_approx(saved.zone_size, _zone_size)
		and is_equal_approx(saved.border, border)
		and saved_grid.zone_count() == saved.pieces.size()
		and (not _area.has_area() or saved_grid.area().is_equal_approx(grid.area()))
	)
	if not same_grid:
		stale.emit()
		return false
	var previous := grid
	# The props are indexed by zone on the saved grid.
	_set_grid(saved_grid)
	_saved_fingerprint = saved.fingerprint
	if saved.fingerprint != fingerprint():
		stale.emit()
		if rebake:
			_set_grid(previous)
			return false
	_job = grid.all()
	_job_by_game = false
	_job_saved = true
	_job_pieces.clear()
	for zone in saved.pieces.size():
		_job_pieces[zone] = saved.pieces[zone]
	stats.parse_ms = 0.0
	stats.obstruct_ms = 0.0
	stats.bake_ms = 0.0
	stats.obstructions = 0
	stats.zones_baked = 0
	stats.zones_total = grid.zone_count()
	if with_index:
		_start_index(saved.pieces.duplicate())
	else:
		_finish()
	return true


## When the pieces in force are a saved bake's: checks it against the props and settings again
## (the game's `extra_fingerprint` changed). A mismatch emits `stale` and, with `rebake`, bakes
## every zone.
func recheck_saved(rebake: bool) -> void:
	if not from_saved or _saved_fingerprint == fingerprint():
		return
	from_saved = false
	stale.emit()
	if rebake:
		request_all(true, false)


## The pieces in force as a PropNavBake, with the props' fingerprint.
func to_saved() -> PropNavBake:
	var out := PropNavBake.new()
	out.zone_size = grid.size
	out.area = grid.area()
	out.border = border
	out.pieces = pieces.duplicate()
	out.fingerprint = fingerprint()
	return out


## A number that changes when what a bake depends on changes: every obstruction under `root`, the
## template's settings, how the zones are cut, and the game's own (`extra_fingerprint`).
func fingerprint() -> int:
	var list := _walk([])
	var extra: int = extra_fingerprint.call() if extra_fingerprint.is_valid() else 0
	var props := PropObstructions.fingerprint(list)
	var settings := [_zone_size, border, _area, height_range, sides, merge_gap, carve]
	for property in template.get_property_list():
		var key: String = property["name"]
		if property["usage"] & PROPERTY_USAGE_STORAGE and not key.begins_with("resource_"):
			settings.append(template.get(key))
	return hash([props, extra, hash(settings)])


func _start(rects: Array[Rect2], everything: bool, reparse: bool, by_game: bool) -> void:
	if root == null or not root.is_inside_tree() or template == null:
		push_error("PropZoneBaker: set a template and a root in the scene tree first")
		return
	var started := Time.get_ticks_usec()
	stats.parse_ms = 0.0
	if reparse or _parsed == null:
		_parse()
		stats.parse_ms = (Time.get_ticks_usec() - started) / 1000.0
	if grid.zone_count() == 0:
		_set_grid(PropZoneGrid.new(_parsed_bounds(), _zone_size))
	var zones := grid.all() if everything else _zones_for(rects)
	if zones.is_empty():
		return
	started = Time.get_ticks_usec()
	var within: Array[Rect2] = []
	for zone in zones:
		within.append(grid.zone_rect(zone).grow(border + merge_gap))
	var list := _walk(within) if everything else _indexed_obstructions(zones, within)
	list = PropObstructions.merged(list, merge_gap, _cell_size())
	_restore_parsed_obstructions()
	if is_3d:
		PropObstructions.add_3d(_parsed as NavigationMeshSourceGeometryData3D, list, carve)
	else:
		PropObstructions.add_2d(_parsed as NavigationMeshSourceGeometryData2D, list, carve)
	stats.obstruct_ms = (Time.get_ticks_usec() - started) / 1000.0
	stats.obstructions = list.size()
	stats.zones_baked = zones.size()
	stats.zones_total = grid.zone_count()
	_job = zones
	_job_by_game = by_game
	_job_saved = false
	_job_pieces.clear()
	_job_list.clear()
	for zone in zones:
		_job_list.append(_piece_for(zone))
	_waiting = zones.size()
	_bake_started_us = Time.get_ticks_usec()
	# Own worker tasks (not the server's async bake), so `wait()` can collect them without the
	# main thread. High priority: low-priority tasks get only part of the pool's threads.
	_bake_group = WorkerThreadPool.add_group_task(
		_bake_piece.bind(_job_list.duplicate(), _parsed, is_3d, _map_cell()),
		zones.size(),
		-1,
		true,
		"PropKit navmesh zones"
	)


## On a worker thread: bakes piece `index` of `list` from `source`.
func _bake_piece(
	index: int, list: Array[Resource], source: Resource, three_d: bool, map_cell: float
) -> void:
	if three_d:
		NavigationServer3D.bake_from_source_geometry_data(
			list[index] as NavigationMesh, source as NavigationMeshSourceGeometryData3D
		)
	else:
		var piece := list[index] as NavigationPolygon
		NavigationServer2D.bake_from_source_geometry_data(
			piece, source as NavigationMeshSourceGeometryData2D
		)
		_weld_2d(piece, map_cell)
	_piece_baked.call_deferred()


## Welds the vertices of a baked 2D piece that fall in one cell of the navigation map
## (`map_cell`), and drops the polygons that collapse. Godot's 2D bake can leave vertices closer
## than a cell: the map, which joins edges by the cells of their ends, then finds more than two
## edges on one (an edge error) and leaves the extra ones unjoined. A vertex on the zone's edge
## wins its cell, then the lowest (x, then y), so both sides of a seam keep the same one.
static func _weld_2d(piece: NavigationPolygon, map_cell: float) -> void:
	var zone := piece.baking_rect.grow(-piece.border_size)
	var vertices := piece.vertices
	var winner: Dictionary[Vector2i, int] = {}
	var keys: Array[Vector2i] = []
	for i in vertices.size():
		var key := Vector2i((vertices[i] / map_cell).floor())
		keys.append(key)
		var at: int = winner.get(key, -1)
		if at < 0 or _wins(vertices[i], vertices[at], zone):
			winner[key] = i
	if winner.size() == vertices.size():
		return
	var kept := PackedVector2Array()
	var slot: Dictionary[Vector2i, int] = {}
	for key in keys:
		if not slot.has(key):
			slot[key] = kept.size()
			kept.append(vertices[winner[key]])
	var polygons: Array[PackedInt32Array] = []
	for p in piece.get_polygon_count():
		var ids := PackedInt32Array()
		for i in piece.get_polygon(p):
			var at: int = slot[keys[i]]
			if ids.is_empty() or ids[-1] != at:
				ids.append(at)
		while ids.size() > 1 and ids[-1] == ids[0]:
			ids.remove_at(ids.size() - 1)
		ids = _without_spikes(ids)
		if ids.size() >= 3:
			polygons.append(ids)
	piece.clear_polygons()
	piece.vertices = kept
	for ids in polygons:
		piece.add_polygon(ids)


## True when vertex `a` should stand for its cell rather than `b`.
static func _wins(a: Vector2, b: Vector2, zone: Rect2) -> bool:
	var a_edge := _on_edge(a, zone)
	if a_edge != _on_edge(b, zone):
		return a_edge
	return a.x < b.x or (a.x == b.x and a.y < b.y)


static func _on_edge(point: Vector2, zone: Rect2) -> bool:
	return (
		is_equal_approx(point.x, zone.position.x) or is_equal_approx(point.x, zone.end.x)
		or is_equal_approx(point.y, zone.position.y) or is_equal_approx(point.y, zone.end.y)
	)


## `ids` without the back-and-forth a weld can leave (a, b, a): the edge out and back has no area.
static func _without_spikes(ids: PackedInt32Array) -> PackedInt32Array:
	var out := ids.duplicate()
	var changed := true
	while changed and out.size() >= 3:
		changed = false
		for k in out.size():
			if out[(k + out.size() - 1) % out.size()] == out[(k + 1) % out.size()]:
				var next := (k + 1) % out.size()
				out.remove_at(maxi(k, next))
				out.remove_at(mini(k, next))
				changed = true
				break
	return out


func _piece_baked() -> void:
	_waiting -= 1
	if _waiting > 0:
		return
	# -2: `wait()` already collected the group.
	if _bake_group >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_bake_group)
	_bake_group = -1
	for i in _job.size():
		_job_pieces[_job[i]] = _job_list[i]
	stats.bake_ms = (Time.get_ticks_usec() - _bake_started_us) / 1000.0
	if not with_index:
		_finish()
		return
	var next := pieces.duplicate()
	for job_zone in _job_pieces:
		next[job_zone] = _job_pieces[job_zone]
	_start_index(next)


func _start_index(all: Array[Resource]) -> void:
	_index_task = WorkerThreadPool.add_task(
		_build_index.bind(all, is_3d, _cell_size() * 0.5), false, "PropKit navmesh index"
	)


## On a worker thread: pure data in, pure data out.
func _build_index(all: Array[Resource], three_d: bool, weld: float) -> void:
	var started := Time.get_ticks_usec()
	var built := PropNavIndex.build(all, three_d, weld)
	_index_built.call_deferred(built, (Time.get_ticks_usec() - started) / 1000.0)


func _index_built(built: PropNavIndex, ms: float) -> void:
	# -2: `wait()` already collected the task.
	if _index_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_index_task)
	_index_task = -1
	stats.index_ms = ms
	stats.polygons = built.polygons.size()
	stats.components = built.component_count
	_next_index = built
	_finish()


func _finish() -> void:
	_has_result = true
	if not manual_apply or not _job_by_game:
		apply()
		return
	var zones := _job.duplicate()
	zones.sort()
	bake_ready.emit(zones)


func _queue(rects: Array[Rect2], everything: bool, reparse: bool, by_game: bool) -> void:
	_queued = true
	_queued_all = _queued_all or everything
	_queued_reparse = _queued_reparse or reparse
	_queued_by_game = _queued_by_game or by_game
	_queued_rects.append_array(rects)


func _flush_later() -> void:
	if not _flush_queued:
		_flush_queued = true
		_flush.call_deferred()


## At the end of the frame: one request for every prop that entered or left during it.
func _flush() -> void:
	_flush_queued = false
	var rects := _left.duplicate()
	_left.clear()
	for node in _arrived:
		if not is_instance_valid(node) or not node.is_inside_tree() or not node.is_in_group(group):
			continue
		_watch(node)
		var rect := PropObstructions.area_of(node, is_3d, sides)
		if rect.has_area():
			_rect_of[node.get_instance_id()] = rect
			rects.append(rect)
	_arrived.clear()
	if rects.is_empty() or not is_instance_valid(root) or not root.is_inside_tree():
		return
	request(rects, false)


func _watch(node: Node) -> void:
	var id := node.get_instance_id()
	if not _watched.has(id):
		_watched[id] = true
		node.tree_exiting.connect(_on_prop_leaving.bind(node), CONNECT_ONE_SHOT)


## A watched prop leaves the tree: freed, or moved elsewhere (it is watched again if it comes back
## under `root`).
func _on_prop_leaving(node: Node) -> void:
	var id := node.get_instance_id()
	_watched.erase(id)
	var rect: Rect2 = _rect_of.get(id, Rect2())
	_rect_of.erase(id)
	if not follow or not _following:
		return
	if not rect.has_area():
		rect = PropObstructions.area_of(node, is_3d, sides)
	if rect.has_area():
		_left.append(rect)
		_flush_later()


func _run_queue() -> void:
	if not _queued or is_busy():
		return
	var rects := _queued_rects.duplicate()
	var everything := _queued_all
	var reparse := _queued_reparse
	var by_game := _queued_by_game
	_queued = false
	_queued_all = false
	_queued_reparse = false
	_queued_by_game = false
	_queued_rects.clear()
	_start(rects, everything, reparse, by_game)


func _zones_for(rects: Array[Rect2]) -> PackedInt32Array:
	var seen: Dictionary[int, bool] = {}
	for rect in rects:
		for zone in grid.zones_touching(rect.grow(border + merge_gap)):
			seen[zone] = true
	var out := PackedInt32Array(seen.keys())
	out.sort()
	return out


func _set_grid(new_grid: PropZoneGrid) -> void:
	grid = new_grid
	pieces.resize(grid.zone_count())
	_indexed = -1


func _parse() -> void:
	if is_3d:
		var source := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(template as NavigationMesh, source, root)
		_parsed = source
		_parsed_obstructions = source.get_projected_obstructions()
	else:
		var source := NavigationMeshSourceGeometryData2D.new()
		NavigationServer2D.parse_source_geometry_data(template as NavigationPolygon, source, root)
		_parsed = source
		_parsed_obstructions = source.get_projected_obstructions()


## The parse's own projected obstructions (NavigationObstacle nodes that affect the navmesh),
## without the props added by the last bake.
func _restore_parsed_obstructions() -> void:
	if is_3d:
		(_parsed as NavigationMeshSourceGeometryData3D).set_projected_obstructions(
			_parsed_obstructions
		)
	else:
		(_parsed as NavigationMeshSourceGeometryData2D).set_projected_obstructions(
			_parsed_obstructions
		)


func _parsed_bounds() -> Rect2:
	if is_3d:
		var box := (_parsed as NavigationMeshSourceGeometryData3D).get_bounds()
		return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	var out := (_parsed as NavigationMeshSourceGeometryData2D).get_bounds()
	var polygon := template as NavigationPolygon
	for i in polygon.get_outline_count():
		for point in polygon.get_outline(i):
			out = out.expand(point) if out.has_area() else Rect2(point, Vector2.ZERO).merge(out)
	return out


## A copy of the template that bakes only `zone` (and its border).
func _piece_for(zone: int) -> Resource:
	var rect := grid.zone_rect(zone).grow(border)
	if is_3d:
		var mesh := (template as NavigationMesh).duplicate() as NavigationMesh
		var heights := _heights()
		mesh.filter_baking_aabb = AABB(
			Vector3(rect.position.x, heights.x, rect.position.y),
			Vector3(rect.size.x, heights.y - heights.x, rect.size.y)
		)
		mesh.filter_baking_aabb_offset = Vector3.ZERO
		mesh.border_size = border
		mesh.edge_max_error = minf(mesh.edge_max_error, 1.0)
		return mesh
	var polygon := (template as NavigationPolygon).duplicate() as NavigationPolygon
	polygon.clear_polygons()
	if polygon.get_outline_count() == 0:
		# No outline drawn: all of the zone is walkable but what blocks it.
		polygon.add_outline(
			PackedVector2Array(
				[rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
				Vector2(rect.position.x, rect.end.y)]
			)
		)
	polygon.baking_rect = rect
	polygon.baking_rect_offset = Vector2.ZERO
	polygon.border_size = border
	return polygon


## Floor and ceiling of a 3D zone's bake, on whole cells of height from 0. The bake measures
## heights in cells from the floor, so every zone on the same grid gives the same height on a
## seam, whatever the parse's bounds were when it baked (the ground went lower in play).
func _heights() -> Vector2:
	var low := height_range.x
	var high := height_range.y
	if high <= low:
		var box := (_parsed as NavigationMeshSourceGeometryData3D).get_bounds()
		low = box.position.y - 1.0
		high = box.end.y + 1.0
	var cell := (template as NavigationMesh).cell_height
	return Vector2(floorf(low / cell) * cell, ceilf(high / cell) * cell)


## Walks every obstruction node under `root`: rebuilds the index of nodes by zone and gives the
## obstructions that touch `within` (empty = all).
func _walk(within: Array[Rect2]) -> Array[PropObstruction]:
	var out: Array[PropObstruction] = []
	_nodes_by_zone.clear()
	_rect_of.clear()
	_indexed = 0
	_outside = 0
	if root == null or not root.is_inside_tree():
		return out
	for node in root.get_tree().get_nodes_in_group(group):
		if node != root and not root.is_ancestor_of(node):
			_outside += 1
			continue
		_indexed += 1
		if not node.tree_exiting.is_connected(_on_obstruction_exiting):
			node.tree_exiting.connect(_on_obstruction_exiting, CONNECT_ONE_SHOT)
		if node.is_queued_for_deletion():
			continue
		_check_layers(node)
		var list := (
			PropObstructions.of_3d(node, sides) if is_3d else PropObstructions.of_2d(node, sides)
		)
		if list.is_empty():
			continue
		var rect := list[0].rect()
		for obstruction in list:
			rect = rect.merge(obstruction.rect())
			if within.is_empty() or PropObstructions.touches(obstruction.rect(), within):
				out.append(obstruction)
		_rect_of[node.get_instance_id()] = rect
		_watch(node)
		for zone in grid.zones_touching(rect.grow(border + merge_gap)):
			if not _nodes_by_zone.has(zone):
				_nodes_by_zone[zone] = []
			_nodes_by_zone[zone].append(node)
	return out


## The obstructions near `zones` from the index of nodes by zone, without walking the whole group.
## The index is rebuilt when the group has a node it never saw (a prop added or moved in).
func _indexed_obstructions(
	zones: PackedInt32Array, within: Array[Rect2]
) -> Array[PropObstruction]:
	var total := root.get_tree().get_node_count_in_group(group)
	if _indexed < 0 or total != _indexed + _outside:
		return _walk(within)
	var nodes: Array[Node] = []
	var seen: Dictionary[int, bool] = {}
	for zone in zones:
		for item: Variant in _nodes_by_zone.get(zone, []):
			# Freed props stay in the index until the next walk.
			if not is_instance_valid(item):
				continue
			var node := item as Node
			if seen.has(node.get_instance_id()):
				continue
			seen[node.get_instance_id()] = true
			nodes.append(node)
	return PropObstructions.gather(nodes, is_3d, sides, within)


func _on_obstruction_exiting() -> void:
	_indexed -= 1


## Warns once when a prop's collider is also parsed as geometry: the bake pays for it twice.
func _check_layers(node: Node) -> void:
	if _warned_layers or not _parsed_as_geometry(node):
		return
	_warned_layers = true
	push_warning(_layers_problem(node))


func _layers_problem(node: Node) -> String:
	return (
		"PropKit: %s is parsed as geometry and is an obstruction too (its collision layer is in "
		% node.name
		+ "the navmesh's collision mask): take that layer out of the mask"
	)


## True when `node`'s collider is on a layer the template parses.
func _parsed_as_geometry(node: Node) -> bool:
	if is_3d and node is CollisionObject3D:
		var mesh := template as NavigationMesh
		var parses := (
			mesh.geometry_parsed_geometry_type != NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES
		)
		var layer := (node as CollisionObject3D).collision_layer
		return parses and (layer & mesh.geometry_collision_mask) != 0
	if not is_3d and node is CollisionObject2D:
		var polygon := template as NavigationPolygon
		var parses := (
			polygon.parsed_geometry_type != NavigationPolygon.PARSED_GEOMETRY_MESH_INSTANCES
		)
		var layer := (node as CollisionObject2D).collision_layer
		return parses and (layer & polygon.parsed_collision_mask) != 0
	return false


## What is wrong with this setup, for the editor's warnings: the saved bake does not match, no
## props, props parsed as geometry, a zone size off the cell size.
func problems(saved: PropNavBake) -> PackedStringArray:
	var out := PackedStringArray()
	if template == null or root == null:
		return out
	var nodes := PropObstructions.nodes_under(root, group)
	if nodes.is_empty():
		out.append("No node of the group «%s» under %s: no prop cuts the navmesh." % [
			group, root.name
		])
	for node in nodes:
		if _parsed_as_geometry(node):
			out.append(_layers_problem(node).trim_prefix("PropKit: ") + ".")
			break
	var cell := _cell_size()
	var off := fmod(_zone_size, cell)
	if off > 0.001 and cell - off > 0.001:
		out.append("zone_size (%s) is not a multiple of the cell size (%s)." % [_zone_size, cell])
	if saved != null and saved.fingerprint != fingerprint():
		out.append("The saved bake does not match the props or the settings: press «Bake».")
	return out


## 2D: the size of a cell of the navigation map's edge rasterizer (the cell size times
## `navigation/2d/merge_rasterizer_cell_scale`).
func _map_cell() -> float:
	if is_3d:
		return 0.0
	var scale: float = ProjectSettings.get_setting("navigation/2d/merge_rasterizer_cell_scale", 1.0)
	return _cell_size() * scale


func _cell_size() -> float:
	if template is NavigationMesh:
		return (template as NavigationMesh).cell_size
	if template is NavigationPolygon:
		return (template as NavigationPolygon).cell_size
	return 1.0


func _agent_radius() -> float:
	if template is NavigationMesh:
		return (template as NavigationMesh).agent_radius
	if template is NavigationPolygon:
		return (template as NavigationPolygon).agent_radius
	return 0.0
