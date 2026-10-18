class_name NavService
extends Node

## The world's pathfinder (RFC-024 §3.1, 024b): %Nav in high_noon. It builds the NavGrid once, after the
## world is ready (terrain, manafounts and altars exist), and answers find_path / component_at for the
## player, the AI and the perception. Only where the world is simulated: a client never asks.
## Blockers come from the scene: the collision shapes of the nodes in `blocker_groups` (manafounts, the
## altars in play and the buildings of the map, RFC-024 addendum 1; `nav_blocker` is for whatever else a scene puts in the way, a
## pillar of the test of the Sac Doctors). Nothing here moves a body; PathFollower hands waypoints to begin_walk.
## RFC-035 035g: `backend` picks who answers. GRID is the NavGrid above (the default, what the baselines were recorded with).
## NAVMESH answers the same API from the baked navmesh (NavMeshBackend + NavRegions + NavBoxBlockers). The command line wins over the
## export: `--nav-backend=navmesh` (or `grid`). With NAVMESH the engine answers from the NavigationRegion3D `region`. What the bake
## does not hold (altars, structures, nav_blocker) and a building that fell change the map: NavRebake bakes the whole navmesh again on a
## worker thread and the result is swapped into the region `rebake_swap_frames` physics ticks after the change (a count, so it is the
## same tick on every machine). A missing navmesh falls back to the grid with a warning.

signal built(ms: float)

const GROUP := &"nav_service"
const DEFAULT_NAVMESH := "res://data/nav/high_noon_nav.res"
const BAKE_SETTINGS := "res://data/nav/nav_bake.tres"
const CLI_BACKEND := "--nav-backend="
const SEARCH_LOG_MAX := 200000

enum Backend { GRID, NAVMESH }

@export var terrain: MeshInstance3D
## Who answers (see above). The default stays GRID until the navmesh is the product's pathfinder.
@export var backend := Backend.NAVMESH
## The map's NavigationRegion3D (%NavRegion). Empty: the service puts one under itself with DEFAULT_NAVMESH.
@export var region: NavigationRegion3D
## Physics ticks between a change and the swap of the re-baked navmesh (the bake takes a couple of seconds on a worker thread; if it
## is not done by then the swap waits for it). A count, never a clock.
@export var rebake_swap_frames := 180
## The groups whose colliders are in the stored bake and move on their own (the buildings, the manafounts). The nodes of the other
## blocker groups and the built structures join the group NavFingerprint.GROUP before a re-bake so the bake sees them.
@export var baked_groups: PackedStringArray = PackedStringArray(["manafount", "map_building"])
## Margin added to every blocker (sacengine blockingTolerance, state.d:790).
@export var margin_m := 1.5
## A node needs whole land around it too (sacengine isFree asks the cells around the node).
@export var erode_edges := true
## A straight line must stay this far (m) from a box blocker (a building) to be clear (NavGrid.crosses_box, F88 round 2).
@export var box_clearance_m := 0.5
@export var blocker_groups: PackedStringArray = PackedStringArray(["manafount", "altar", "map_building", "nav_blocker"])
## What the players build (Manaliths, RFC-021): their collision blocks too, and the grid is built again when one
## appears or falls (024c; the debt of F72/F73). `structures` is the node they are put under (%Structures).
@export var built_group: StringName = &"structure"
@export var structures: Node
## Frames to wait after a structure enters or leaves before building again (it needs its own _ready first).
@export var rebuild_delay_frames := 2
## At most this many A* searches per physics tick; the rest of the callers wait for the next tick
## (a count, never a clock, so the match stays reproducible).
@export var max_searches_per_tick := 3
@export var build_on_ready := true

var grid := NavGrid.new()
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
## A building fell: the stored bake still holds its walls, a bake without it is due.
var _baked_changed := false
var rebakes := 0
## What the stored bake holds of the dynamic groups, as the hash of their blocker entries (the empty list at first).
var _baked_signature := [].hash()
var _pending_signature := 0
## Tick at which the running re-bake is swapped in; -1 with none running.
var _swap_at := -1
## A change came while a bake was running: bake again after the swap.
var _dirty := false
## True once the navmesh backend answers (set by build, not by the export: a missing navmesh leaves the grid).
var _navmesh_on := false
## Microseconds of every search, to tell the p95 (for the report; never read by the simulation). Capped.
var _search_log := PackedInt32Array()


func _ready() -> void:
	add_to_group(GROUP)
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)
		return
	_read_command_line()
	if structures != null:
		structures.child_entered_tree.connect(_on_structure_changed.unbind(1))
		structures.child_exiting_tree.connect(_on_structure_changed.unbind(1))
	if build_on_ready:
		build.call_deferred()


func _physics_process(_delta: float) -> void:
	_tick += 1
	searches_this_tick = 0
	if _swap_at >= 0 and _tick >= _swap_at:
		_swap_rebaked()
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
	return mesh.built and mesh.is_synced() if _navmesh_on else grid.built


## True while a re-bake is running or waits to be swapped in (the navmesh answers with the old map meanwhile).
func is_rebaking() -> bool:
	return _swap_at >= 0 or _dirty


func backend_name() -> String:
	return "navmesh" if _navmesh_on else "grid"


## `--nav-backend=grid|navmesh` of the command line (user args or engine args) wins over the export.
func _read_command_line() -> void:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with(CLI_BACKEND):
			backend = Backend.NAVMESH if arg.substr(CLI_BACKEND.length()) == "navmesh" else Backend.GRID


## Builds the pathfinder (again). Returns the milliseconds it took.
func build() -> float:
	if terrain == null or not terrain.has_method("ground_cell_counts"):
		return 0.0
	if backend == Backend.NAVMESH and _build_navmesh():
		_watch_buildings()
		return mesh.build_ms
	grid.build(terrain, _blockers(), margin_m, erode_edges, box_clearance_m)
	_watch_buildings()
	print("nav: grilla %d nodos libres, %d regiones, %.0f ms" % [grid.free_count, grid.component_count, grid.build_ms])
	built.emit(grid.build_ms)
	return grid.build_ms


## A building that falls leaves no wall: the grid is built again without it (its collision is off by then).
func _watch_buildings() -> void:
	for node in get_tree().get_nodes_in_group(MapBuilding.GROUP):
		var building := node as MapBuilding
		if building != null and not building.destroyed.is_connected(_on_building_destroyed):
			building.destroyed.connect(_on_building_destroyed)


func _on_building_destroyed(_building: MapBuilding) -> void:
	_baked_changed = true
	build.call_deferred()


## First time: takes the region (or makes one with the stored navmesh) and bakes at once if something the stored bake lacks stands on the
## map. After: a change of blockers asks for a new bake. False, with the grid left to build, when there is no navmesh to load.
func _build_navmesh() -> bool:
	var entries := _blockers()
	if mesh.built:
		mesh.set_boxes(entries, box_clearance_m)
		_request_rebake()
		return true
	var nav_region := region
	if nav_region == null:
		var stored := ResourceLoader.load(DEFAULT_NAVMESH) as NavigationMesh
		if stored == null or stored.get_polygon_count() == 0:
			push_warning("nav: no navmesh in %s, the grid answers" % DEFAULT_NAVMESH)
			return false
		nav_region = NavigationRegion3D.new()
		nav_region.name = "NavRegion"
		nav_region.navigation_mesh = stored
		add_child(nav_region)
	elif nav_region.navigation_mesh == null or nav_region.navigation_mesh.get_polygon_count() == 0:
		push_warning("nav: the region has no navmesh (run tools/bake_nav.tscn), the grid answers")
		return false
	var settings: NavBakeSettings = nav_region.get("bake_settings") if nav_region.get("bake_settings") != null else load(BAKE_SETTINGS) as NavBakeSettings
	rebake = NavRebake.new(settings)
	mesh.build(nav_region, entries, box_clearance_m)
	_navmesh_on = true
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
		_swap_at = _tick + rebake_swap_frames
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
	_swap_at = -1
	var baked := rebake.finish()
	if baked != null:
		mesh.swap(baked)
		_baked_signature = _pending_signature
		rebakes += 1
		print("nav: re-bake %d polígonos, %d regiones (parse %.0f ms, bake %.0f ms)" % [mesh.polygon_count, mesh.regions.component_count, rebake.parse_ms, rebake.bake_ms])
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


## Waypoints from `from` (not included) to `to`; [to] when nothing is in the way or there is no grid.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not is_ready():
		return PackedVector3Array([to])
	var started := Time.get_ticks_usec()
	var path := mesh.find_path(_grounded(from), _grounded(to)) if _navmesh_on else grid.find_path(from, to)
	last_find_us = Time.get_ticks_usec() - started
	search_us_total += last_find_us
	searches += 1
	if _search_log.size() < SEARCH_LOG_MAX:
		_search_log.append(last_find_us)
	if path.is_empty():
		return PackedVector3Array([to])
	for k in path.size():
		var ground: float = terrain.call("ground_height", path[k].x, path[k].z) if terrain else NAN
		path[k].y = from.y if is_nan(ground) else ground
	return path


func line_clear(from: Vector3, to: Vector3) -> bool:
	if not is_ready():
		return true
	return mesh.line_clear(_grounded(from), _grounded(to)) if _navmesh_on else grid.line_clear(from, to)


## Whether the straight line from `from` to `to` goes through a box blocker (a building), whatever the grid says.
func crosses_box(from: Vector3, to: Vector3) -> bool:
	if not is_ready():
		return false
	return mesh.crosses_box(from, to) if _navmesh_on else grid.crosses_box(from, to)


func component_at(point: Vector3) -> int:
	if not is_ready():
		return -1
	return mesh.component_at(point) if _navmesh_on else grid.component_at(point)


func same_region(a: Vector3, b: Vector3) -> bool:
	if not is_ready():
		return true
	if _navmesh_on:
		var ca := mesh.component_at(a)
		return ca >= 0 and ca == mesh.component_at(b)
	return grid.same_region(a, b)


## The free land closest to `point` within about 30 m (the grid's 6 nodes), (NAN, NAN, NAN) when there is none or no pathfinder.
func nearest_free(point: Vector3) -> Vector3:
	var none := Vector3(NAN, NAN, NAN)
	if not is_ready():
		return none
	if _navmesh_on:
		return mesh.nearest_free(_grounded(point))
	var node := grid.nearest_free(NavGrid.node_of(point))
	if node.x < 0:
		return none
	var at := NavGrid.node_point(node)
	at.y = point.y
	return at


## Whether `point` stands on free land (a free node of the grid; the navmesh within 0.75 m and on it).
func is_free_at(point: Vector3) -> bool:
	if not is_ready():
		return true
	return mesh.is_walkable(_grounded(point)) if _navmesh_on else grid.is_free_at(point)


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
	var ground: float = terrain.call("ground_height", point.x, point.z) if terrain else NAN
	if is_nan(ground):
		return point
	return Vector3(point.x, ground, point.z)


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
