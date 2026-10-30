extends RefCounted

## Whether every altar of a map can walk to every manafount on its saved navmesh, asked the way a
## unit asks it (NavMeshBackend.find_path): both ends on the ground, the start on the nearest land
## that is not an island, the same query with no search cap (NavMeshBackend.query_path). It passes
## when both are in the same walkable region (the zones' PropNavIndex) and the path ends within the
## agent radius plus END_SLACK_M of the walkable point nearest to the fount. The navmesh is the
## map's saved bake, loaded by its Nav (nothing is baked here). Returns the problems, each naming
## the two nodes. Not: the seats (MapSeatChecks), what stands on land (MapGroundChecks).

const MapGroundChecks := preload("res://tools/audit/map_ground_checks.gd")

## Added to the bake's agent radius (1 m, scenes/map/nav/map_nav.tscn): a path that ends farther
## (flat) than both from the walkable point nearest to the fount stopped short, the fount is out of
## reach. 2 m in all: a unit stops at its target's edge, and the nearest point of a fount hole may
## be a corner the path turns before.
const END_SLACK_M := 1.0


static func check(root: MapRoot, nav: NavMeshBackend) -> Array[String]:
	var problems: Array[String] = []
	var altars := MapGroundChecks.nodes_in_map(root, Altar.ANY_GROUP)
	var founts := MapGroundChecks.nodes_in_map(root, ManafountBody.GROUP)
	if altars.is_empty() or founts.is_empty():
		print("paths: %d altars, %d founts: nothing to walk" % [altars.size(), founts.size()])
		return problems
	for altar in altars:
		for fount in founts:
			var problem := _walk(root, nav, altar, fount)
			if not problem.is_empty():
				problems.append(problem)
	return problems


## The problem of the walk from `altar` to `fount`, empty when it can be walked.
static func _walk(root: MapRoot, nav: NavMeshBackend, altar: Node3D, fount: Node3D) -> String:
	var names := "%s -> %s" % [root.get_path_to(altar), root.get_path_to(fount)]
	var from := _grounded(root.terrain, altar.global_position)
	var to := _grounded(root.terrain, fount.global_position)
	var from_region := nav.component_at(from)
	var to_region := nav.component_at(to)
	if from_region < 0 or to_region < 0 or from_region != to_region:
		return (
			"%s: not in the same walkable region (%d %s, %d %s)"
			% [names, from_region, _size_of(nav, from_region), to_region, _size_of(nav, to_region)]
		)
	# The land nearest to the fount (an island, the fount's own top, is no goal): the path goes
	# there, as the server would otherwise aim at the island.
	var goal := nav.nearest_free(to)
	if is_nan(goal.x):
		goal = NavigationServer3D.map_get_closest_point(nav.map, to)
	var start := nav.nearest_free(from)
	var path := NavMeshBackend.query_path(
		nav.map,
		from if is_nan(start.x) else start,
		goal,
		NavigationPathQueryParameters3D.new(),
		NavigationPathQueryResult3D.new()
	)
	if path.is_empty():
		return "%s: no walking path (the query is empty)" % names
	var length := 0.0
	for k in range(1, path.size()):
		length += path[k - 1].distance_to(path[k])
	var short := _flat(path[path.size() - 1], goal)
	var reach := nav.zones.navigation_mesh.agent_radius + END_SLACK_M
	if not is_finite(length) or short > reach:
		return (
			# gdlint: ignore=max-line-length
			"%s: no walking path (%d points, %.0f m, ends %.1f m from the walkable point nearest to the fount, max %.1f m)"
			% [names, path.size(), length, short, reach]
		)
	print(
		(
			"path %s: %.0f m, ends %.1f m from the fount's nearest walkable point"
			% [names, length, short]
		)
	)
	return ""


## `point` at the height of the ground under it (NavService._grounded); the point itself over a
## void.
static func _grounded(terrain: Terrain, point: Vector3) -> Vector3:
	var height := terrain.height_at(point.x, point.z)
	return point if is_nan(height) else Vector3(point.x, height, point.z)


static func _size_of(nav: NavMeshBackend, component: int) -> String:
	return "(%.0f m²)" % nav.zones.index.component_area[component] if component >= 0 else "(none)"


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
