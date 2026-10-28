extends RefCounted

## What a map puts on its ground: every PlayerStart, Altar, Manafount and MapBuilding stands on land (not over a void), and
## every GroundFootprint (the base of an altar or a fount) lies level, within MAX_SPREAD_M and with no void under it. Returns
## the problems, each naming the node by its path from the map root. Not: the seats (MapSeatChecks), the paths
## (MapPathChecks), flattening a base (the editor's «Flatten bases»).

## The most the heights under a base may differ. Tune it here.
const MAX_SPREAD_M := 8.0  ## the shipped maps lie up to 7 m off level under their bases (peaks); 1 m of margin


static func check(root: MapRoot, terrain: Terrain) -> Array[String]:
	var problems: Array[String] = []
	problems.append_array(_on_land(root, terrain))
	problems.append_array(_level_bases(root, terrain))
	return problems


static func _on_land(root: MapRoot, terrain: Terrain) -> Array[String]:
	var problems: Array[String] = []
	var standing: Array[Node3D] = []
	for node in root.starts.get_children():
		if node is PlayerStart:
			standing.append(node as PlayerStart)
	for group: StringName in [Altar.ANY_GROUP, ManafountBody.GROUP, MapBuilding.GROUP]:
		standing.append_array(nodes_in_map(root, group))
	for placed in standing:
		var at := placed.global_position
		if is_nan(terrain.height_at(at.x, at.z)):
			problems.append("%s stands over a void at (%.0f, %.0f)" % [root.get_path_to(placed), at.x, at.z])
	return problems


static func _level_bases(root: MapRoot, terrain: Terrain) -> Array[String]:
	var problems: Array[String] = []
	var source := terrain.heights
	if source == null or not source.is_valid():
		return ["the Terrain has no valid heights"]
	for node in nodes_in_map(root, GroundFootprint.GROUP):
		var footprint := node as GroundFootprint
		var path := root.get_path_to(footprint)
		var rect := FootprintRules.vertices_under(footprint.area())
		var spread := FootprintRules.spread_m(source.heights_m, rect)
		var voids := _voids_in(source, rect)
		print("footprint %s: spread %.2f m over %dx%d vertices, %d void" % [path, spread, rect.size.x, rect.size.y, voids])
		if spread > MAX_SPREAD_M:
			problems.append("%s is not level: spread %.2f m (max %.2f m)" % [path, spread, MAX_SPREAD_M])
		if voids > 0:
			problems.append("%s has %d void vertices under it" % [path, voids])
	return problems


## The nodes of `group` inside this map (the checker holds one map at a time, but it does not count on it).
static func nodes_in_map(root: Node, group: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in root.get_tree().get_nodes_in_group(group):
		if root.is_ancestor_of(node) and node is Node3D:
			out.append(node as Node3D)
	return out


static func _voids_in(source: TerrainHeights, rect: Rect2i) -> int:
	var count := 0
	for row in range(rect.position.y, rect.end.y):
		for column in range(rect.position.x, rect.end.x):
			if source.is_void(TerrainGrid.id_of(Vector2i(column, row))):
				count += 1
	return count
