class_name PinRules
extends RefCounted

## How much a spell's stamp may move each lattice vertex so the bases of the map stay level: 0 under a base (the vertices of
## FootprintRules.vertices_under), half on the ring of vertices around it (a soft step, not a wall), 1 everywhere else. Terrain
## works the weights out once from the map's footprints and multiplies every stamp by them (the live ones in TerrainLive, the kept
## ones in keep_stamp). Static and pure; it does not know what a spell or a base is, nor flatten the land (FootprintRules).

## The share a stamp keeps on the ring of vertices around a base.
const RING_SHARE := 0.5


## One weight per lattice vertex (row by row, TerrainGrid.SIDE²) for the ground areas (x, z in metres) of the bases. Empty when
## there is no base: then nothing is multiplied.
static func weights(areas: Array[Rect2]) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if areas.is_empty():
		return out
	out.resize(TerrainGrid.SIDE * TerrainGrid.SIDE)
	out.fill(1.0)
	var lattice := Rect2i(0, 0, TerrainGrid.SIDE, TerrainGrid.SIDE)
	for area in areas:
		var base := FootprintRules.vertices_under(area).intersection(lattice)
		_cap(out, base.grow(1).intersection(lattice), RING_SHARE)
		_cap(out, base, 0.0)
	return out


## The weights of every GroundFootprint under `tree` that pins its ground.
static func of_tree(tree: SceneTree) -> PackedFloat32Array:
	var areas: Array[Rect2] = []
	for node in tree.get_nodes_in_group(GroundFootprint.GROUP):
		var footprint := node as GroundFootprint
		if footprint != null and footprint.pins_ground:
			areas.append(footprint.area())
	return weights(areas)


## `values` (row by row over the lattice vertices of `rect`) times the weight of each vertex. Nothing without weights.
static func apply(values: PackedFloat32Array, rect: Rect2i, weights: PackedFloat32Array) -> void:
	if weights.is_empty() or values.size() != rect.get_area():
		return
	for row in rect.size.y:
		for column in rect.size.x:
			var vertex := rect.position + Vector2i(column, row)
			if (
				vertex.x >= 0
				and vertex.y >= 0
				and vertex.x < TerrainGrid.SIDE
				and vertex.y < TerrainGrid.SIDE
			):
				values[row * rect.size.x + column] *= weights[TerrainGrid.id_of(vertex)]


## Every weight of `rect` is at most `share`.
static func _cap(weights: PackedFloat32Array, rect: Rect2i, share: float) -> void:
	for row in range(rect.position.y, rect.end.y):
		for column in range(rect.position.x, rect.end.x):
			var id := TerrainGrid.id_of(Vector2i(column, row))
			weights[id] = minf(weights[id], share)
