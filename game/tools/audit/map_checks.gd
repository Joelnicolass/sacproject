extends RefCounted

## Whether one map, already in the tree, can be played as it stands: its seats (MapSeatChecks, when the map has a
## MapDefinition), what stands on land and the level bases (MapGroundChecks), and that every altar walks to every manafount
## (MapPathChecks, when the map has a NavRegion; a NavRegion without a baked navmesh is a problem). Returns the problems, each
## naming the node. check_map (headless, every map), terrain_cli --validate and the Terrain's «Validate map» button run it.
## Not: loading the map (the callers), fixing anything (the editor flattens the bases, MapNavRegion bakes the navmesh).

const MapSeatChecks := preload("res://tools/audit/map_seat_checks.gd")
const MapGroundChecks := preload("res://tools/audit/map_ground_checks.gd")
const MapPathChecks := preload("res://tools/audit/map_path_checks.gd")


## The problems of `root` (empty = it passes). `definition` may be null (a map scene outside the catalog, such as a debug
## bed): then the seats are not checked. Waits for the navigation map's first sync.
static func check(root: MapRoot, definition: MapDefinition) -> Array[String]:
	var problems: Array[String] = []
	var terrain := root.terrain
	if root.starts == null:
		problems.append("the scene is a MapRoot without `starts`")
	if terrain == null or not terrain.is_loaded():
		problems.append("the map has no loaded Terrain")
	var navmesh := root.nav_region.navigation_mesh if root.nav_region != null else null
	var regions := NavRegions.new()
	if root.nav_region != null and (navmesh == null or navmesh.get_polygon_count() == 0):
		problems.append("the map has no navmesh (NavRegion «Bake navmesh»)")
		navmesh = null
	elif navmesh != null:
		regions.build(navmesh)
	if not problems.is_empty():
		return problems
	# The checks compare positions in the scene with the Terrain's own frame (x, z >= 0). The editor shows the map shifted
	# to its centre (MapRoot.editor_recenter); while they run the root stands at the origin, as it does in a match.
	var shift := root.position
	root.position = Vector3.ZERO
	if definition != null:
		problems.append_array(MapSeatChecks.check(root, terrain, definition, regions))
	problems.append_array(MapGroundChecks.check(root, terrain))
	if navmesh != null:
		problems.append_array(await MapPathChecks.check(root, navmesh, regions))
	if is_instance_valid(root):
		root.position = shift
	return problems
