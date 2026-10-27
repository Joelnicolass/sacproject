class_name NavService
extends Node

## The world's pathfinder (RFC-024 §3.1, 024b): %Nav in the match. It takes the map's navmesh once, after the
## world is ready (terrain, manafounts and altars exist), and answers find_path / component_at for the
## player, the AI and the perception. Only where the world is simulated: a client never asks.
## Blockers come from the scene: the collision shapes of the nodes in `blocker_groups` (manafounts, the
## altars in play and the buildings of the map, RFC-024 addendum 1; `nav_blocker` is for whatever else a scene puts in the way, a
## pillar of the test of the Sac Doctors). Nothing here moves a body; PathFollower hands waypoints to begin_walk.
## RFC-035 035i: the navmesh is the one owner (NavMeshBackend + NavRegions + NavBoxBlockers; the 5 m grid is gone). The engine
## answers from the NavigationRegion3D `region`. What the bake
## does not hold (altars, structures, nav_blocker) and a building that fell change the map: NavRebake bakes the whole navmesh again on a
## worker thread and the result is swapped into the region `rebake_swap_s` after the change (a count, so it is the
## same tick on every machine while the bake is done by then; if not, the swap waits for the first tick it is done, never blocking). A missing navmesh leaves the service not ready (callers get the straight line) with a warning.

signal built(ms: float)

const GROUP := &"nav_service"
const BAKE_SETTINGS := "res://data/nav/nav_bake.tres"
const SEARCH_LOG_MAX := 200000

## The map's ground (MapRoot.terrain): the path points take the land height from it.
@export var terrain: Terrain
## The map's NavigationRegion3D (MapRoot.nav_region; MatchWorld binds it when the map is attached). Required: without it the
## service stays not ready, with a warning.
@export var region: NavigationRegion3D
## Time between a change and the swap of the re-baked navmesh (the bake takes a couple of seconds on a worker thread; if it
## is not done by then the match goes on with the old navmesh and the swap happens at the first tick it is). Counted in physics ticks, never a clock.
@export_range(0.0, 30.0, 0.0001, "suffix:s") var rebake_swap_s := 3.0
## Time the lasting changes of the ground (the holes of Bore, a mound that stays) are gathered for before the navmesh is baked
## again, so a spiral of holes costs a few bakes and not one per vertex.
@export_range(0.0, 30.0, 0.0001, "suffix:s") var holes_rebake_s := 2.0
## The groups whose colliders are in the stored bake and move on their own (the buildings, the manafounts). The nodes of the other
## blocker groups and the built structures join the group NavFingerprint.GROUP before a re-bake so the bake sees them.
@export var baked_groups: PackedStringArray = PackedStringArray(["manafount", "map_building"])
## A straight line must stay this far (m) from a box blocker (a building) to be clear (NavBoxBlockers.crosses_box, F88 round 2).
@export var box_clearance_m := 0.5
## `cast_tower`: Manaliths and Shrines are MapBuildings raised during the match, so the stored bake never holds them; listing their
## own group here (and not in `baked_groups`) puts them in the re-bake signature, or a doctor walks into a tower's legs.
@export var blocker_groups: PackedStringArray = PackedStringArray(["manafount", "altar", "map_building", "nav_blocker", "cast_tower"])
## What the players build (Manaliths, RFC-021): their collision blocks too, and the navmesh is baked again when one
## appears or falls (024c; the debt of F72/F73). `structures` is the node they are put under (%Structures).
@export var built_group: StringName = &"structure"
@export var structures: Node
## Frames to wait after a structure enters or leaves before building again (it needs its own _ready first).
@export var rebuild_delay_frames := 2
## At most this many A* searches per physics tick; the rest of the callers wait for the next tick
## (a count, never a clock, so the match stays reproducible).
@export var max_searches_per_tick := 3
@export var build_on_ready := true

var mesh := NavMeshBackend.new()
var rebake: NavRebake
## Microseconds of the last A* search, for the report.
var last_find_us := 0
## Microseconds of every A* search so far (for the report; never read by the simulation).
var search_us_total := 0
var searches := 0
var searches_this_tick := 0
var rebuilds := 0

var _rebuild_in := -1
var _tick := 0
## A building fell, or the ground changed for good (a hole, a mound): the stored bake is out of date and a new one is due.
var _baked_changed := false
## Tick at which the bake for the holes that came since is asked; -1 with none waiting.
var _holes_at := -1
var rebakes := 0
## What the stored bake holds of the dynamic groups, as the hash of their blocker entries (the empty list at first).
var _baked_signature := [].hash()
var _pending_signature := 0
## Tick at which the running re-bake is swapped in; -1 with none running.
var _swap_at := -1
## A change came while a bake was running: bake again after the swap.
var _dirty := false
## Microseconds of every search, to tell the p95 (for the report; never read by the simulation). Capped.
var _search_log := PackedInt32Array()


func _ready() -> void:
	add_to_group(GROUP)
	if not is_multiplayer_authority():
		set_physics_process(false)
		return
	if terrain != null:
		terrain.holes_changed.connect(_on_ground_settled.unbind(1))
		# What stays (a dent, a crater), not `settled`: a live stamp that ends (Erupt, a Quake) changes nothing for good.
		terrain.kept.connect(_on_ground_settled.unbind(4))
	if structures != null:
		structures.child_entered_tree.connect(_on_structure_changed.unbind(1))
		structures.child_exiting_tree.connect(_on_structure_changed.unbind(1))
	if build_on_ready:
		build.call_deferred()


func _physics_process(_delta: float) -> void:
	_tick += 1
	searches_this_tick = 0
	if _swap_at >= 0 and _tick >= _swap_at and rebake.is_done():
		_swap_rebaked()
	if _holes_at >= 0 and _tick >= _holes_at:
		_holes_at = -1
		_request_rebake()
	if _rebuild_in >= 0:
		_rebuild_in -= 1
		if _rebuild_in < 0:
			rebuilds += 1
			build()


func _on_structure_changed() -> void:
	if is_ready():
		_rebuild_in = rebuild_delay_frames


func _exit_tree() -> void:
	if rebake != null and rebake.is_running():
		rebake.finish()
	mesh.release()


func is_ready() -> bool:
	return mesh.built and mesh.is_synced()


## True while a re-bake is running or waits to be swapped in (the navmesh answers with the old map meanwhile).
func is_rebaking() -> bool:
	return _swap_at >= 0 or _dirty


## Length of a path from `from` through `points`, flat.
static func path_length(from: Vector3, points: PackedVector3Array) -> float:
	var total := 0.0
	var last := Vector2(from.x, from.z)
	for point in points:
		var here := Vector2(point.x, point.z)
		total += last.distance_to(here)
		last = here
	return total


## Builds the pathfinder (again). Returns the milliseconds it took.
func build() -> float:
	if terrain == null:
		return 0.0
	if not _build_navmesh():
		return 0.0
	_watch_buildings()
	return mesh.build_ms


## A building that falls leaves no wall: the navmesh is baked again without it (its collision is off by then).
func _watch_buildings() -> void:
	for node in get_tree().get_nodes_in_group(MapBuilding.GROUP):
		var building := node as MapBuilding
		if building != null and not building.destroyed.is_connected(_on_building_destroyed):
			building.destroyed.connect(_on_building_destroyed)


## The ground changed for good: a vertex was taken away or given back (a path may not cross the hole any more), or a mound or a
## crater stays. Idempotent: the re-bake waits a little for the next ones, both signals of one hole ask for one bake.
func _on_ground_settled() -> void:
	_baked_changed = true
	if _holes_at < 0:
		_holes_at = _tick + MatchClock.ticks_for(holes_rebake_s)


func _on_building_destroyed(_building: MapBuilding) -> void:
	_baked_changed = true
	build.call_deferred()


## First time: takes the region and bakes at once if something the stored bake lacks stands on the map. After: a change of blockers
## asks for a new bake. False when there is no region or it has no navmesh.
func _build_navmesh() -> bool:
	var entries := _blockers()
	if mesh.built:
		mesh.set_boxes(entries, box_clearance_m)
		_request_rebake()
		return true
	var nav_region := region
	if nav_region == null:
		push_warning("nav: no `region` assigned (the map's NavRegion); the pathfinder is off")
		return false
	if nav_region.navigation_mesh == null or nav_region.navigation_mesh.get_polygon_count() == 0:
		push_warning("nav: the region has no navmesh (run tools/bake/bake_nav.tscn)")
		return false
	var settings: NavBakeSettings = nav_region.get("bake_settings") if nav_region.get("bake_settings") != null else load(BAKE_SETTINGS) as NavBakeSettings
	rebake = NavRebake.new(settings)
	mesh.build(nav_region, entries, box_clearance_m)
	print("nav: navmesh %d polígonos, %d regiones, %.0f ms" % [mesh.polygon_count, mesh.regions.component_count, mesh.build_ms])
	_request_rebake()
	built.emit(mesh.build_ms)
	return true


## Starts a bake if something that blocks and is not in the stored bake exists (or a building fell), or marks it dirty when one runs.
func _request_rebake() -> void:
	if rebake == null:
		return
	if _swap_at >= 0:
		_dirty = true
		return
	var signature := _collect_blockers(_dynamic_groups(), true).hash()
	if signature == _baked_signature and not _baked_changed:
		return
	_tag_dynamic_nodes()
	if rebake.start(get_parent()):
		_swap_at = _tick + MatchClock.ticks_for(rebake_swap_s)
		_pending_signature = signature
		_baked_changed = false


## The nodes the stored bake lacks join the bake's source group (their collision shapes are parsed with them).
func _tag_dynamic_nodes() -> void:
	for group in _dynamic_groups():
		for node in get_tree().get_nodes_in_group(group):
			if node is Node3D and not node.is_in_group(NavFingerprint.GROUP):
				node.add_to_group(NavFingerprint.GROUP)
	for node in get_tree().get_nodes_in_group(built_group):
		if node is Node3D and not node.is_in_group(MapBuilding.GROUP) and not node.is_in_group(NavFingerprint.GROUP):
			node.add_to_group(NavFingerprint.GROUP)


func _swap_rebaked() -> void:
	var late := _tick - _swap_at
	_swap_at = -1
	var baked := rebake.finish()
	if baked != null:
		rebake.retire(mesh.swap(baked, rebake.regions))
		_baked_signature = _pending_signature
		rebakes += 1
		print("nav: re-bake %d polígonos, %d regiones (parse %.1f ms, bake %.0f ms en el worker, swap %.2f ms%s)" % [mesh.polygon_count, mesh.regions.component_count, rebake.parse_ms, rebake.bake_ms, mesh.swap_ms, (", swap %d ticks tarde" % late) if late > 0 else ""])
	else:
		push_warning("nav: the re-bake came out empty, the old navmesh stays")
	if _dirty:
		_dirty = false
		_request_rebake()


## The blocker groups the stored bake does not hold.
func _dynamic_groups() -> PackedStringArray:
	var out := PackedStringArray()
	for group in blocker_groups:
		if not baked_groups.has(group):
			out.append(group)
	return out


## True while the tick still has room for another A* search; takes one slot.
func take_search_slot() -> bool:
	if searches_this_tick >= max_searches_per_tick:
		return false
	searches_this_tick += 1
	return true


## Waypoints from `from` (not included) to `to`; [to] when nothing is in the way or there is no navmesh.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not is_ready():
		return PackedVector3Array([to])
	var started := Time.get_ticks_usec()
	var path := mesh.find_path(_grounded(from), _grounded(to))
	last_find_us = Time.get_ticks_usec() - started
	search_us_total += last_find_us
	searches += 1
	if _search_log.size() < SEARCH_LOG_MAX:
		_search_log.append(last_find_us)
	if path.is_empty():
		return PackedVector3Array([to])
	for k in path.size():
		var height: float = terrain.height_at(path[k].x, path[k].z) if terrain else NAN
		path[k].y = from.y if is_nan(height) else height
	return path


func line_clear(from: Vector3, to: Vector3) -> bool:
	if not is_ready():
		return true
	return mesh.line_clear(_grounded(from), _grounded(to))


## Whether the straight line from `from` to `to` goes through a box blocker (a building), whatever the navmesh says.
func crosses_box(from: Vector3, to: Vector3) -> bool:
	if not is_ready():
		return false
	return mesh.crosses_box(from, to)


func component_at(point: Vector3) -> int:
	if not is_ready():
		return -1
	return mesh.component_at(point)


func same_region(a: Vector3, b: Vector3) -> bool:
	if not is_ready():
		return true
	var ca := mesh.component_at(a)
	return ca >= 0 and ca == mesh.component_at(b)


## The free land closest to `point` within about 30 m, (NAN, NAN, NAN) when there is none or no pathfinder.
func nearest_free(point: Vector3) -> Vector3:
	if not is_ready():
		return Vector3(NAN, NAN, NAN)
	return mesh.nearest_free(_grounded(point))


## Whether `point` stands on free land (on the navmesh within 0.75 m, not on an island).
func is_free_at(point: Vector3) -> bool:
	if not is_ready():
		return true
	return mesh.is_walkable(_grounded(point))


## One entry per collision shape of the blocker nodes right now (see _blockers): what a pathfinder has to go around.
func blockers() -> Array:
	return _blockers()


## Microseconds under which `fraction` (0..1) of the searches so far finished; 0 with none.
func search_percentile_us(fraction: float) -> int:
	if _search_log.is_empty():
		return 0
	var sorted := _search_log.duplicate()
	sorted.sort()
	return sorted[clampi(ceili(fraction * sorted.size()) - 1, 0, sorted.size() - 1)]


## `point` at the height of the ground under it (the navmesh is asked in 3D); the point itself off the land.
func _grounded(point: Vector3) -> Vector3:
	var height: float = terrain.height_at(point.x, point.z) if terrain else NAN
	if is_nan(height):
		return point
	return Vector3(point.x, height, point.z)


## One entry per collision shape of the blocker nodes: [Vector2 center, radius] for a cylinder or a sphere and
## [Vector2 center, Vector2 half extents, yaw] for a box (the buildings of the map).
func _blockers() -> Array:
	return _collect_blockers(blocker_groups, true)


## The entries of the nodes of `groups`, and with `with_built` those of the built structures (group `built_group`).
func _collect_blockers(groups: PackedStringArray, with_built: bool) -> Array:
	var discs := []
	for group in groups:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node3D:
				_collect(node as Node3D, discs, 0)
	if not with_built:
		return discs
	for node in get_tree().get_nodes_in_group(built_group):
		var built_node := node as Node3D
		if built_node != null and not built_node.is_in_group(MapBuilding.GROUP) and not built_node.is_queued_for_deletion() and not blocker_groups.has(String(built_group)):
			_collect(built_node, discs, 0)
	return discs


func _collect(node: Node3D, discs: Array, depth: int) -> void:
	for child in node.get_children():
		if child is CollisionShape3D:
			var shape_node := child as CollisionShape3D
			if shape_node.disabled:
				continue
			var at := shape_node.global_position
			var scale := shape_node.global_transform.basis.get_scale()
			if shape_node.shape is CylinderShape3D:
				var cylinder := shape_node.shape as CylinderShape3D
				discs.append([Vector2(at.x, at.z), cylinder.radius * maxf(scale.x, scale.z)])
			elif shape_node.shape is BoxShape3D:
				var half := (shape_node.shape as BoxShape3D).size * 0.5 * scale
				discs.append([Vector2(at.x, at.z), Vector2(half.x, half.z), shape_node.global_transform.basis.get_euler().y])
			elif shape_node.shape is SphereShape3D:
				discs.append([Vector2(at.x, at.z), (shape_node.shape as SphereShape3D).radius * maxf(scale.x, scale.z)])
		elif child is Node3D and depth < 2:
			_collect(child as Node3D, discs, depth + 1)
