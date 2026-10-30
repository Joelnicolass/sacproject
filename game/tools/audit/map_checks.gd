extends RefCounted

## Whether one map, already in the tree, can be played as it stands: its seats (MapSeatChecks, when
## the map has a MapDefinition), what stands on land and the level bases (MapGroundChecks), and that
## every altar walks to every manafount (MapPathChecks, when the map has a Nav; a Nav without a
## baked navmesh is a problem). Returns the problems, each naming the node. check_map
## (headless, every map), terrain_cli --validate and the Terrain's «Validate map» button run it.
## Not: loading the map (the callers), fixing anything (the editor flattens the bases,
## the Nav node's «Bake» bakes the navmesh).

const MapSeatChecks := preload("res://tools/audit/map_seat_checks.gd")
const MapGroundChecks := preload("res://tools/audit/map_ground_checks.gd")
const MapPathChecks := preload("res://tools/audit/map_path_checks.gd")
## Physics frames to wait for the saved navmesh to load and the navigation map to use it.
const LOAD_FRAMES := 600


## The problems of `root` (empty = it passes). `definition` may be null (a map scene outside the
## catalog, such as a debug bed): then the seats are not checked. Waits for the navigation map's
## first sync.
static func check(root: MapRoot, definition: MapDefinition) -> Array[String]:
	var problems: Array[String] = []
	var terrain := root.terrain
	if root.starts == null:
		problems.append("the scene is a MapRoot without `starts`")
	if terrain == null or not terrain.is_loaded():
		problems.append("the map has no loaded Terrain")
	var nav := NavMeshBackend.new()
	if root.nav != null:
		if root.nav.saved == null or root.nav.saved.pieces.is_empty():
			problems.append("the map has no navmesh (press «Bake» on its Nav node)")
		else:
			nav.build(root.nav, [], 0.0)
			for _frame in LOAD_FRAMES:
				if nav.is_synced():
					break
				await root.get_tree().physics_frame
			if not nav.is_synced():
				problems.append("the navmesh did not load in %d physics frames" % LOAD_FRAMES)
	if not problems.is_empty():
		return problems
	# The checks compare positions in the scene with the Terrain's own frame (x, z >= 0). The editor
	# shows the map shifted to its centre (MapRoot.editor_recenter); while they run the root stands
	# at the origin, as it does in a match.
	var shift := root.position
	root.position = Vector3.ZERO
	if definition != null:
		problems.append_array(MapSeatChecks.check(root, terrain, definition, nav))
	problems.append_array(MapGroundChecks.check(root, terrain))
	if nav.built:
		problems.append_array(MapPathChecks.check(root, nav))
	if is_instance_valid(root):
		root.position = shift
	return problems
