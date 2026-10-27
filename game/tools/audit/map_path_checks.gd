extends RefCounted

## Whether every altar of a map can walk to every manafount on its saved navmesh, asked the way a unit asks it
## (NavMeshBackend.find_path): both ends on the ground, the start on the nearest land that is not an island, the same query
## with no search cap (NavMeshBackend.query_path). It passes when both are in the same walkable region (NavRegions) and the
## path ends within the agent radius plus END_SLACK_M of the walkable point nearest to the fount. The navmesh is the map's
## baked nav.res, handed as it is to a navigation map of its own on NavigationServer3D (nothing is baked here; the world's map
## is not touched). Returns the problems, each naming the two nodes. Not: the seats (MapSeatChecks), what stands on land (MapGroundChecks).

const MapGroundChecks := preload("res://tools/audit/map_ground_checks.gd")

## A point this far from a walkable polygon counts as outside the navmesh (a fount stands in a hole of its own size).
const SNAP_M := 6.0
## Added to the bake's agent radius (1 m, data/nav/nav_bake.tres): a path that ends farther (flat) than both from the walkable
## point nearest to the fount stopped short, the fount is out of reach. 2 m in all: a unit stops at its target's edge, and the
## nearest point of a fount hole may be a corner the path turns before.
const END_SLACK_M := 1.0

## Physics frames to wait for the navigation map's first sync.
const SYNC_FRAMES := 30


static func check(root: MapRoot, navmesh: NavigationMesh, regions: NavRegions) -> Array[String]:
	var problems: Array[String] = []
	var altars := MapGroundChecks.nodes_in_map(root, Altar.ANY_GROUP)
	var founts := MapGroundChecks.nodes_in_map(root, ManafountBody.GROUP)
	if altars.is_empty() or founts.is_empty():
		print("paths: %d altars, %d founts: nothing to walk" % [altars.size(), founts.size()])
		return problems
	var map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(map, navmesh.cell_size)
	NavigationServer3D.map_set_cell_height(map, navmesh.cell_height)
	var region := NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(region, map)
	NavigationServer3D.region_set_transform(region, root.nav_region.global_transform)
	NavigationServer3D.region_set_navigation_mesh(region, navmesh)
	NavigationServer3D.map_set_active(map, true)
	for _frame in SYNC_FRAMES:
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			break
		await root.get_tree().physics_frame
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		problems.append("the navigation map did not sync in %d physics frames" % SYNC_FRAMES)
	else:
		for altar in altars:
			for fount in founts:
				var problem := _walk(root, map, navmesh, regions, altar, fount)
				if not problem.is_empty():
					problems.append(problem)
	NavigationServer3D.free_rid(region)
	NavigationServer3D.free_rid(map)
	return problems


## The problem of the walk from `altar` to `fount`, empty when it can be walked.
static func _walk(root: MapRoot, map: RID, navmesh: NavigationMesh, regions: NavRegions, altar: Node3D,
		fount: Node3D) -> String:
	var names := "%s -> %s" % [root.get_path_to(altar), root.get_path_to(fount)]
	var from := _grounded(root.terrain, altar.global_position)
	var to := _grounded(root.terrain, fount.global_position)
	var from_region := regions.component_at(from, SNAP_M)
	var to_region := regions.component_at(to, SNAP_M)
	if from_region < 0 or to_region < 0 or from_region != to_region:
		return "%s: not in the same walkable region (%d %s, %d %s)" % [names, from_region,
			_size_of(regions, from_region), to_region, _size_of(regions, to_region)]
	var start := regions.closest_land(from, NavMeshBackend.SNAP_M, NavMeshBackend.ISLAND_POLYGONS)
	var path := NavMeshBackend.query_path(map, from if is_nan(start.x) else start, to,
		NavigationPathQueryParameters3D.new(), NavigationPathQueryResult3D.new())
	if path.is_empty():
		return "%s: no walking path (the query is empty)" % names
	var length := 0.0
	for k in range(1, path.size()):
		length += path[k - 1].distance_to(path[k])
	var goal := NavigationServer3D.map_get_closest_point(map, to)
	var short := _flat(path[path.size() - 1], goal)
	var reach := navmesh.agent_radius + END_SLACK_M
	if not is_finite(length) or short > reach:
		return "%s: no walking path (%d points, %.0f m, ends %.1f m from the walkable point nearest to the fount, max %.1f m)" % [
			names, path.size(), length, short, reach]
	print("path %s: %.0f m, ends %.1f m from the fount's nearest walkable point" % [names, length, short])
	return ""


## `point` at the height of the ground under it (NavService._grounded); the point itself over a void.
static func _grounded(terrain: Terrain, point: Vector3) -> Vector3:
	var height := terrain.height_at(point.x, point.z)
	return point if is_nan(height) else Vector3(point.x, height, point.z)


static func _size_of(regions: NavRegions, component: int) -> String:
	return "(%d polygons)" % regions.sizes[component] if component >= 0 else "(none)"


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
