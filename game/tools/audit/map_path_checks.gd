extends RefCounted

## Whether every altar of a map can walk to every manafount on its saved navmesh: both in the same walkable region
## (NavRegions) and with a path of finite length that reaches the fount. The navmesh is the map's baked nav.res, handed as it
## is to a navigation map of its own on NavigationServer3D (nothing is baked here; the world's map is not touched). Returns the
## problems, each naming the two nodes. Not: the seats (MapSeatChecks), what stands on land (MapGroundChecks).

const MapGroundChecks := preload("res://tools/audit/map_ground_checks.gd")

## A point this far from a walkable polygon counts as outside the navmesh (a fount stands in a hole of its own size).
const SNAP_M := 6.0
## A path that ends farther than this from the walkable point nearest to the fount stopped short: the fount is out of reach.
const REACH_M := 1.0

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
				var problem := _walk(root, map, regions, altar, fount)
				if not problem.is_empty():
					problems.append(problem)
	NavigationServer3D.free_rid(region)
	NavigationServer3D.free_rid(map)
	return problems


## The problem of the walk from `altar` to `fount`, empty when it can be walked.
static func _walk(root: MapRoot, map: RID, regions: NavRegions, altar: Node3D, fount: Node3D) -> String:
	var names := "%s -> %s" % [root.get_path_to(altar), root.get_path_to(fount)]
	var from := altar.global_position
	var to := fount.global_position
	var from_region := regions.component_at(from, SNAP_M)
	var to_region := regions.component_at(to, SNAP_M)
	if from_region < 0 or to_region < 0 or from_region != to_region:
		return "%s: not in the same walkable region (%d, %d)" % [names, from_region, to_region]
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	var length := 0.0
	for k in range(1, path.size()):
		length += path[k - 1].distance_to(path[k])
	var goal := NavigationServer3D.map_get_closest_point(map, to)
	if path.is_empty() or not is_finite(length) or path[path.size() - 1].distance_to(goal) > REACH_M:
		return "%s: no walking path (%d points, ends %.1f m from the fount)" % [
			names, path.size(), path[path.size() - 1].distance_to(goal) if not path.is_empty() else INF]
	print("path %s: %.0f m" % [names, length])
	return ""

