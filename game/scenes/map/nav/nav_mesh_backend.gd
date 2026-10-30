class_name NavMeshBackend
extends RefCounted

## The navmesh side of NavService: the map's MapNav (PropKit zones, one NavigationRegion3D per
## zone) queried through the engine: NavigationServer3D.query_path on the world's navigation map,
## and the zones' PropNavIndex for what the server does not answer (components, the closest land).
## What changes at runtime (altars, structures, a fallen building, the ground) is a re-bake of the
## zones it touches, driven by NavService. Nothing hand-made blocks a path here. Ready once the
## zones have an index and the map uses every piece (`is_synced`).

## Reach (6 nodes of 5 m, as the old grid) for «the nearest walkable thing».
const SNAP_M := 30.0
## A path that ends this close (flat) to the goal ends on the goal itself.
const END_SNAP_M := 1.0
## The start of a line may stand this far (flat) off the navmesh (a body beside a wall is inside the
## erosion of the bake).
const START_SLACK_M := 2.5
## line_clear samples: one every meter (a hole is at least two agent radii wide), each within this
## (flat) of the mesh.
const LINE_STEP_M := 1.0
const LINE_TOL_M := 0.5
## A point is walkable when the navmesh is this close (flat).
const WALKABLE_M := 0.75
## A component of the navmesh smaller than this (m², flat) is an island (the flat top of a
## blocker 8 m tall, the floor inside a hollow box, a pocket the walls closed): bodies do not stand
## there.
const ISLAND_M2 := 400.0

var built := false
var polygon_count := 0
var box_blockers := NavBoxBlockers.new()
var zones: PropNavZones3D
var map := RID()

var _params: NavigationPathQueryParameters3D
var _result: NavigationPathQueryResult3D


## Takes the zones (in the tree, with their saved bake loaded) and the world's navigation map.
## `box_entries` are the building boxes ([Vector2 center, Vector2 half, yaw], NavService._blockers)
## for crosses_box.
func build(nav: PropNavZones3D, box_entries: Array, box_clearance_m: float) -> void:
	zones = nav
	_resolve_map()
	set_boxes(box_entries, box_clearance_m)
	built = true
	refresh()


## After a swap: the polygon count of the pieces in force (reports only).
func refresh() -> void:
	var index := _index()
	polygon_count = index.polygons.size() if index != null else 0


func set_boxes(box_entries: Array, box_clearance_m: float) -> void:
	box_blockers.reset(box_clearance_m)
	box_blockers.add_entries(box_entries)


func release() -> void:
	built = false
	zones = null
	map = RID()


## True once the zones' first pieces are in the navigation map, with their index; it stays true
## (a change in play answers with the old pieces until the new ones are in).
func is_synced() -> bool:
	return built and zones != null and zones.is_ready() and map.is_valid()


## The world's navigation map, with the navmesh's cell size (a world map starts at 0.25 unless the
## project says 1.0).
func _resolve_map() -> void:
	if zones == null or not zones.is_inside_tree() or zones.get_world_3d() == null:
		return
	map = zones.get_world_3d().navigation_map
	var navmesh := zones.navigation_mesh
	if (
		navmesh != null
		and not is_equal_approx(NavigationServer3D.map_get_cell_size(map), navmesh.cell_size)
	):
		NavigationServer3D.map_set_cell_size(map, navmesh.cell_size)
		NavigationServer3D.map_set_cell_height(map, navmesh.cell_height)


## Waypoints from `from` (not included) to `to`: [to] when nothing is in the way, the closest
## approach when `to` is off the mesh or in another region. Empty only when not built.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not built:
		return PackedVector3Array()
	# The start is put on the land closest to it: a body on a roof, or in the box a building leaves
	# hollow, stands over an island of the mesh, and a path asked from there goes nowhere (the
	# closest approach of an island is inside it).
	var start := nearest_free(from)
	# The goal too: a target on a fount's top or a roof is reached from the land around it.
	var goal := nearest_free(to)
	var raw := _query(from if is_nan(start.x) else start, to if is_nan(goal.x) else goal)
	if raw.size() < 2:
		return PackedVector3Array([to])
	var out := PackedVector3Array()
	for k in range(1, raw.size()):
		out.append(raw[k])
	if _flat(out[out.size() - 1], to) <= END_SNAP_M:
		out[out.size() - 1] = to
	return out


## True when the straight line from `a` to `b` is on the navmesh from end to end: samples every
## LINE_STEP_M are all within LINE_TOL_M (flat) of the mesh. The ends may stand off it, a body
## beside a wall is inside the erosion of the bake: the allowance (START_SLACK_M at `a`, END_SNAP_M
## at `b`) shrinks to nothing as the line leaves them. A hole is at least two agent radii wide, so a
## sample lands at least LINE_TOL_M inside it. (A path query would not do: its A* corridor is not
## the shortest, a leg of a funnel path asked again can come back with a detour.)
func line_clear(a: Vector3, b: Vector3) -> bool:
	if not built:
		return true
	var length := _flat(a, b)
	var steps := maxi(1, ceili(length / LINE_STEP_M))
	for k in steps + 1:
		var t := float(k) / float(steps)
		var at := a.lerp(b, t)
		var along := length * t
		var allowed := (
			LINE_TOL_M + maxf(0.0, maxf(START_SLACK_M - along, END_SNAP_M - (length - along)))
		)
		if not _near_land(at, allowed):
			return false
	return true


func crosses_box(a: Vector3, b: Vector3) -> bool:
	return box_blockers.crosses_box(a, b)


## The component of the land (no island: a fount's top, a roof) under or nearest to `point`, within
## SNAP_M; -1 when there is none.
func component_at(point: Vector3) -> int:
	var index := _index()
	var land := _land_near(point, SNAP_M)
	if index == null or is_nan(land.x):
		return -1
	return index.component_at(land, WALKABLE_M)


## The closest point of the land (no island) within SNAP_M (flat) of `point`, or (NAN, NAN, NAN).
## Answered from the zones' index, not from the server (whose closest-point queries walk the whole
## map).
func nearest_free(point: Vector3) -> Vector3:
	return _land_near(point, SNAP_M)


## On the navmesh (within WALKABLE_M, flat) and not on an island.
func is_walkable(point: Vector3) -> bool:
	return built and _near_land(point, WALKABLE_M)


func _near_land(point: Vector3, within: float) -> bool:
	return not is_nan(_land_near(point, within).x)


## The closest land point within `within` (flat) of `point`; (NAN, NAN, NAN) when there is none.
func _land_near(point: Vector3, within: float) -> Vector3:
	var index := _index()
	var none := Vector3(NAN, NAN, NAN)
	if index == null:
		return none
	var land := index.closest_point(point, within, ISLAND_M2)
	return none if land == Vector3.INF else land


func _index() -> PropNavIndex:
	return zones.index if zones != null else null


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _query(from: Vector3, to: Vector3) -> PackedVector3Array:
	if _params == null:
		_params = NavigationPathQueryParameters3D.new()
		_result = NavigationPathQueryResult3D.new()
	return query_path(map, from, to, _params, _result)


## The path the units walk from `from` to `to` on `map`, through `params` and `result` (reused by
## the caller). The only place that sets the search limits: map_get_path caps the search at 4096
## polygons (NavigationPathQueryParameters3D default) and returns a partial path past that; a map
## has ~10k, so long paths stopped short. Here there is no cap on polygons or distance.
## tools/audit/map_path_checks.gd asks the same.
static func query_path(
	on_map: RID,
	from: Vector3,
	to: Vector3,
	params: NavigationPathQueryParameters3D,
	result: NavigationPathQueryResult3D
) -> PackedVector3Array:
	params.path_search_max_polygons = 0
	params.path_search_max_distance = 0.0
	params.map = on_map
	params.start_position = from
	params.target_position = to
	NavigationServer3D.query_path(params, result)
	return result.path
