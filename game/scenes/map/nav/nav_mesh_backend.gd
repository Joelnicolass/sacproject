class_name NavMeshBackend
extends RefCounted

## The navmesh side of NavService: the map's NavigationRegion3D (its baked NavigationMesh, data/nav/high_noon_nav.res)
## queried through the engine: NavigationServer3D.map_get_path on the region's own navigation map. Standard Godot: the region is a node,
## the engine syncs the map each physics frame, and what changes at runtime (altars, structures, a fallen building) is a re-bake that
## swaps the region's navigation_mesh (NavRebake, driven by NavService). Nothing hand-made blocks a path here.
## The map is empty until the engine has synced the region (one physics frame after it is in the tree): `is_synced` tells.
## Ref: RFC-035 035g.

## Reach (6 nodes of 5 m, as the old grid) for «the nearest walkable thing».
const SNAP_M := 30.0
## A path that ends this close (flat) to the goal ends on the goal itself.
const END_SNAP_M := 1.0
## The start of a line may stand this far (flat) off the navmesh (a body beside a wall is inside the erosion of the bake).
const START_SLACK_M := 2.5
## line_clear samples: one every meter (a hole is at least two agent radii wide), each within this (flat) of the mesh.
const LINE_STEP_M := 1.0
const LINE_TOL_M := 0.5
## A point is walkable when the navmesh is this close (flat).
const WALKABLE_M := 0.75
## A component of the navmesh with fewer polygons is an island (the flat top of a blocker 8 m tall, a pocket the walls closed): bodies
## do not stand there. The stored bake has 22 of them, 96 polygons in all.
const ISLAND_POLYGONS := 100

var built := false
var build_ms := 0.0
## Main-thread milliseconds of the last swap (reports only).
var swap_ms := 0.0
var polygon_count := 0
var regions := NavRegions.new()
var box_blockers := NavBoxBlockers.new()
var region: NavigationRegion3D
var map := RID()

var _probe := Vector3.ZERO
var _synced := false
var _checks := 0
## Checks of is_synced without an answer before the diagnostic is printed again (about 2 s of physics ticks).
const DIAGNOSE_AFTER := 120
const DIAGNOSE_POINT := Vector3(1504.9, 17.0, 1540.5)


## Takes the region (in the tree, with its navigation_mesh) and its map. `box_entries` are the building boxes
## ([Vector2 center, Vector2 half, yaw], NavService._blockers) for crosses_box.
func build(nav_region: NavigationRegion3D, box_entries: Array, box_clearance_m: float) -> void:
	var started := Time.get_ticks_usec()
	region = nav_region
	_resolve_map()
	regions = NavRegions.new()
	regions.build(region.navigation_mesh)
	_index(region.navigation_mesh)
	_synced = false
	_checks = 0
	set_boxes(box_entries, box_clearance_m)
	built = true
	build_ms = float(Time.get_ticks_usec() - started) / 1000.0


## Puts a re-baked navmesh and its components (built with it off the main thread, NavRebake.regions) in the region; the engine
## syncs it on its next physics frame (the old one answers until then). Only references change hands here: the index it replaced
## is returned, so the caller frees it off the main thread (freeing ~11k polygons costs a millisecond or more, NavRebake.retire).
## The engine's own sync of the new region stays on the next physics step (synchronous on purpose, so the swap tick is the same on
## every machine: project.godot navigation/world/*_async_iterations=false); on High Noon it is about 8-11 ms.
func swap(navmesh: NavigationMesh, components: NavRegions) -> NavRegions:
	var started := Time.get_ticks_usec()
	var replaced := regions
	region.navigation_mesh = navmesh
	regions = components
	_index(navmesh)
	swap_ms = float(Time.get_ticks_usec() - started) / 1000.0
	return replaced


func set_boxes(box_entries: Array, box_clearance_m: float) -> void:
	box_blockers.reset(box_clearance_m)
	box_blockers.add_entries(box_entries)


func release() -> void:
	built = false
	_synced = false
	region = null
	map = RID()


## True once the server's map holds the navmesh (a probe on its first vertex answers). Cached.
func is_synced() -> bool:
	if _synced:
		return true
	if not built:
		return false
	_resolve_map()
	if not map.is_valid():
		return false
	var closest := NavigationServer3D.map_get_closest_point(map, _probe)
	_synced = closest.distance_to(_probe) < 3.0
	_checks += 1
	if not _synced and _checks == DIAGNOSE_AFTER:
		if DebugLog.on(&"nav"): print(diagnose("NOT synced after %d checks" % _checks))
	return _synced


## The map the region is really on (what the server says; NavigationRegion3D.get_navigation_map is only an override). Falls back to the
## world's map when the region has none yet, and gives that map the navmesh's cell size (a world map starts at 0.25 unless the project says 1.0).
func _resolve_map() -> void:
	if region == null or not region.is_inside_tree():
		return
	var found := NavigationServer3D.region_get_map(region.get_rid())
	if not found.is_valid() and region.get_world_3d() != null:
		found = region.get_world_3d().navigation_map
	if not found.is_valid():
		return
	map = found
	var navmesh := region.navigation_mesh
	if navmesh != null and not is_equal_approx(NavigationServer3D.map_get_cell_size(map), navmesh.cell_size):
		NavigationServer3D.map_set_cell_size(map, navmesh.cell_size)
		NavigationServer3D.map_set_cell_height(map, navmesh.cell_height)


## One line with what the server says about the map and the region (for a run where the backend never becomes ready).
func diagnose(label: String) -> String:
	if region == null or not map.is_valid():
		return "nav: diag %s: no region or no valid map (region %s, map valid %s)" % [label, region != null, map.is_valid()]
	var region_rid := region.get_rid()
	var navmesh := region.navigation_mesh
	return "nav: diag %s: map_valid=%s map_regions=%d region_map_is_map=%s iteration=%d active=%s map_cell=%s mesh_cell=%s region_enabled=%s in_tree=%s polygons=%d probe=%s closest_probe=%s closest_start1=%s" % [
		label, map.is_valid(), NavigationServer3D.map_get_regions(map).size(), NavigationServer3D.region_get_map(region_rid) == map,
		NavigationServer3D.map_get_iteration_id(map), NavigationServer3D.map_is_active(map), NavigationServer3D.map_get_cell_size(map),
		navmesh.cell_size if navmesh != null else -1.0, region.is_enabled(), region.is_inside_tree(), polygon_count, _probe,
		NavigationServer3D.map_get_closest_point(map, _probe), NavigationServer3D.map_get_closest_point(map, DIAGNOSE_POINT)]


## Waypoints from `from` (not included) to `to`: [to] when nothing is in the way, the closest approach when `to` is off the mesh or
## in another region. Empty only when not built.
var _params: NavigationPathQueryParameters3D
var _result: NavigationPathQueryResult3D


func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not built:
		return PackedVector3Array()
	## The start is put on the land closest to it: a body on a roof, or in the box a building leaves hollow, stands over an island of the
	## mesh, and a path asked from there goes nowhere (the closest approach of an island is inside it).
	var start := nearest_free(from)
	var raw := _query(from if is_nan(start.x) else start, to)
	if raw.size() < 2:
		return PackedVector3Array([to])
	var out := PackedVector3Array()
	for k in range(1, raw.size()):
		out.append(raw[k])
	if _flat(out[out.size() - 1], to) <= END_SNAP_M:
		out[out.size() - 1] = to
	return out


## True when the straight line from `a` to `b` is on the navmesh from end to end: samples every LINE_STEP_M
## are all within LINE_TOL_M (flat) of the mesh. The ends may stand off it, a body beside a wall is inside the erosion of the bake:
## the allowance (START_SLACK_M at `a`, END_SNAP_M at `b`) shrinks to nothing as the line leaves them. A hole is at least two agent
## radii wide, so a sample lands at least LINE_TOL_M inside it. (A path query would not do: its A* corridor is not the shortest, a
## leg of a funnel path asked again can come back with a detour.)
func line_clear(a: Vector3, b: Vector3) -> bool:
	if not built:
		return true
	var length := _flat(a, b)
	var steps := maxi(1, ceili(length / LINE_STEP_M))
	for k in steps + 1:
		var t := float(k) / float(steps)
		var at := a.lerp(b, t)
		var along := length * t
		var allowed := LINE_TOL_M + maxf(0.0, maxf(START_SLACK_M - along, END_SNAP_M - (length - along)))
		if not _near_land(at, allowed):
			return false
	return true


func crosses_box(a: Vector3, b: Vector3) -> bool:
	return box_blockers.crosses_box(a, b)


func component_at(point: Vector3) -> int:
	return regions.component_at(point, SNAP_M)


## The closest point of the navmesh within SNAP_M of `point`, or (NAN, NAN, NAN). An island (the walkable top of a blocker, the floor
## inside a hollow box) is not land. Answered from the polygons NavRegions holds, not from the server (whose closest-point queries walk
## the whole map).
func nearest_free(point: Vector3) -> Vector3:
	return regions.closest_land(point, SNAP_M, ISLAND_POLYGONS)


## On the navmesh (within WALKABLE_M, flat) and not on an island.
func is_walkable(point: Vector3) -> bool:
	return built and _near_land(point, WALKABLE_M)


func _near_land(point: Vector3, within: float) -> bool:
	var land := regions.closest_land(point, within, ISLAND_POLYGONS)
	return not is_nan(land.x)


## The polygon count and the probe of `navmesh` (the middle of its first polygon).
func _index(navmesh: NavigationMesh) -> void:
	polygon_count = navmesh.get_polygon_count()
	var vertices := navmesh.get_vertices()
	if navmesh.get_polygon_count() > 0:
		## The middle of the first polygon: a point that is surely on the mesh (a corner may be shaved by the server's merge).
		var polygon := navmesh.get_polygon(0)
		var sum := Vector3.ZERO
		for index in polygon:
			sum += vertices[index]
		_probe = region.global_transform * (sum / float(polygon.size()))


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _query(from: Vector3, to: Vector3) -> PackedVector3Array:
	if _params == null:
		_params = NavigationPathQueryParameters3D.new()
		_result = NavigationPathQueryResult3D.new()
	return query_path(map, from, to, _params, _result)


## The path the units walk from `from` to `to` on `map`, through `params` and `result` (reused by the caller). The only place
## that sets the search limits: map_get_path caps the search at 4096 polygons (NavigationPathQueryParameters3D default) and
## returns a partial path past that; a map has ~10k, so long paths stopped short. Here there is no cap on polygons or distance.
## tools/audit/map_path_checks.gd asks the same.
static func query_path(on_map: RID, from: Vector3, to: Vector3, params: NavigationPathQueryParameters3D,
		result: NavigationPathQueryResult3D) -> PackedVector3Array:
	params.path_search_max_polygons = 0
	params.path_search_max_distance = 0.0
	params.map = on_map
	params.start_position = from
	params.target_position = to
	NavigationServer3D.query_path(params, result)
	return result.path
