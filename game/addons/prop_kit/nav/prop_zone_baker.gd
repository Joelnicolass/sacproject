@tool
class_name PropZoneBaker
extends RefCounted

## The engine behind PropNavZones3D and PropNavZones2D: bakes a navmesh in square zones (a
## PropZoneGrid), so a change re-bakes only the zones it touches. On the main thread it parses the
## source geometry (or reuses the last parse) and reads the props' shapes into projected
## obstructions, only those near the zones that bake. The zones bake on worker threads, and the
## PropNavIndex of the whole navmesh is built on one too, so the main thread only swaps
## references. Each zone bakes with its own filter and border, so its piece meets the next one
## exactly on the zone line. The pieces wait in a result until `apply()` (on its own, unless
## `manual_apply`), always in zone order: the outcome depends only on the inputs, never on which
## zone finished first. A request while a bake runs waits and is joined with the next ones. The
## node owns the regions: `piece_changed` says which zone gets which piece.

## The pieces of `zones` are baked (and the index built): `apply()` swaps them in.
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
var group: StringName = PropObstructions.GROUP
var sides := 6
var merge_gap := 0.0
var carve := false
## True: a result waits for `apply()`. False: it is applied when ready.
var manual_apply := false
## Build a PropNavIndex with every bake.
var with_index := true
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
var _index_only := false
var _next_index: PropNavIndex
var _bake_started_us := 0
var _has_result := false
var _queued := false
var _queued_all := false
var _queued_reparse := false
var _queued_rects: Array[Rect2] = []


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
## `reparse` = parse the geometry again (it changed); false = only the props changed.
func request(rects: Array[Rect2], reparse := true) -> void:
	if is_busy():
		_queue(rects, false, reparse)
		return
	_start(rects, false, reparse)


## Re-bakes every zone.
func request_all(reparse := true) -> void:
	if is_busy():
		_queue([], true, reparse)
		return
	_start([], true, reparse)


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


## Puts `saved` in force (its pieces now, its index on a worker). False when it was cut on another
## grid (zone size, border or area) or holds no pieces. Then checks it against the props: when
## they differ it emits `stale` and, with `rebake`, bakes every zone again.
func load_saved(saved: PropNavBake, rebake := true) -> bool:
	if saved == null or saved.pieces.is_empty():
		return false
	if not is_equal_approx(saved.zone_size, _zone_size):
		return false
	if not is_equal_approx(saved.border, border):
		return false
	var saved_grid := PropZoneGrid.new(saved.area, saved.zone_size)
	if saved_grid.zone_count() != saved.pieces.size():
		return false
	if _area.has_area() and not saved_grid.area().is_equal_approx(grid.area()):
		return false
	_set_grid(saved_grid)
	for zone in saved.pieces.size():
		pieces[zone] = saved.pieces[zone]
		piece_changed.emit(zone, pieces[zone])
	if with_index:
		_index_only = true
		_start_index(pieces.duplicate())
	if saved.fingerprint != fingerprint():
		stale.emit()
		if rebake:
			request_all(true)
	return true


## The pieces in force as a PropNavBake, with the props' fingerprint.
func to_saved() -> PropNavBake:
	var out := PropNavBake.new()
	out.zone_size = grid.size
	out.area = grid.area()
	out.border = border
	out.pieces = pieces.duplicate()
	out.fingerprint = fingerprint()
	return out


## The fingerprint of every obstruction under `root` with these settings, and the game's own
## (`extra_fingerprint`).
func fingerprint() -> int:
	var list := _walk([])
	var extra: int = extra_fingerprint.call() if extra_fingerprint.is_valid() else 0
	var props := PropObstructions.fingerprint(list)
	return hash([props, sides, snappedf(merge_gap, 0.001), carve, extra])


func _start(rects: Array[Rect2], everything: bool, reparse: bool) -> void:
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
	list = PropObstructions.merged(list, merge_gap)
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
	_job_pieces.clear()
	_job_list.clear()
	for zone in zones:
		_job_list.append(_piece_for(zone))
	_waiting = zones.size()
	_bake_started_us = Time.get_ticks_usec()
	# Own worker tasks (not the server's async bake), so `wait()` can collect them without the
	# main thread. High priority: low-priority tasks get only part of the pool's threads.
	_bake_group = WorkerThreadPool.add_group_task(
		_bake_piece.bind(_job_list.duplicate(), _parsed, is_3d),
		zones.size(),
		-1,
		true,
		"PropKit navmesh zones"
	)


## On a worker thread: bakes piece `index` of `list` from `source`.
func _bake_piece(index: int, list: Array[Resource], source: Resource, three_d: bool) -> void:
	if three_d:
		NavigationServer3D.bake_from_source_geometry_data(
			list[index] as NavigationMesh, source as NavigationMeshSourceGeometryData3D
		)
	else:
		NavigationServer2D.bake_from_source_geometry_data(
			list[index] as NavigationPolygon, source as NavigationMeshSourceGeometryData2D
		)
	_piece_baked.call_deferred()


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
	if _index_only:
		_index_only = false
		index = built
		_run_queue()
		return
	_next_index = built
	_finish()


func _finish() -> void:
	_has_result = true
	var zones := _job.duplicate()
	zones.sort()
	bake_ready.emit(zones)
	if not manual_apply:
		apply()


func _queue(rects: Array[Rect2], everything: bool, reparse: bool) -> void:
	_queued = true
	_queued_all = _queued_all or everything
	_queued_reparse = _queued_reparse or reparse
	_queued_rects.append_array(rects)


func _run_queue() -> void:
	if not _queued or is_busy():
		return
	var rects := _queued_rects.duplicate()
	var everything := _queued_all
	var reparse := _queued_reparse
	_queued = false
	_queued_all = false
	_queued_reparse = false
	_queued_rects.clear()
	_start(rects, everything, reparse)


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
		var box := (_parsed as NavigationMeshSourceGeometryData3D).get_bounds()
		mesh.filter_baking_aabb = AABB(
			Vector3(rect.position.x, box.position.y - 1.0, rect.position.y),
			Vector3(rect.size.x, box.size.y + 2.0, rect.size.y)
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


## Walks every obstruction node under `root`: rebuilds the index of nodes by zone and gives the
## obstructions that touch `within` (empty = all).
func _walk(within: Array[Rect2]) -> Array[PropObstruction]:
	var out: Array[PropObstruction] = []
	_nodes_by_zone.clear()
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
	if _warned_layers:
		return
	var layer := 0
	var mask := 0
	var parses := false
	if is_3d and node is CollisionObject3D:
		var mesh := template as NavigationMesh
		layer = (node as CollisionObject3D).collision_layer
		mask = mesh.geometry_collision_mask
		parses = (
			mesh.geometry_parsed_geometry_type != NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES
		)
	elif not is_3d and node is CollisionObject2D:
		var polygon := template as NavigationPolygon
		layer = (node as CollisionObject2D).collision_layer
		mask = polygon.parsed_collision_mask
		parses = (
			polygon.parsed_geometry_type != NavigationPolygon.PARSED_GEOMETRY_MESH_INSTANCES
		)
	if parses and (layer & mask) != 0:
		_warned_layers = true
		push_warning(
			(
				"PropKit: %s is parsed as geometry and is an obstruction too (its collision layer "
				+ "is in the navmesh's collision mask): take that layer out of the mask"
			)
			% node.name
		)


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
