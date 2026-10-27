class_name HoleRules
extends RefCounted

## When the ground may lose a vertex (a hole): never one at the rim of the map, one that is already gone, one close to a
## building, or one under the base of an altar or a manafount; and which vertices a hole at a point means. Static: the caller
## hands the places of the building parts and the bases (`parts_of`, `bases_of` gather them), so the rule itself needs no tree.
## It does not make the hole (Terrain does) nor choose where to dig (HoleCutter).
## Ref: sacengine canRemoveLandVertex (state.d:28999-29026); the base is its checkGround (state.d:29013-29023).

## A vertex this close (m, on the ground plane) to a building part is never taken away.
const BUILDING_CLEARANCE_M := 11.0
## A building part this far above or below the vertex is out of the way.
## Ref: sacengine mapDepth.
const DEPTH_BAND_M := 50.0


## True when the vertex at (column, row) may be taken away. `parts` are the world places of the parts of every building, `bases`
## the lattice vertices under every base (`bases_of`).
static func can_remove(shape: Terrain, vertex: Vector2i, parts: PackedVector3Array, bases: Array[Rect2i] = []) -> bool:
	if not is_open(shape, vertex) or is_under_base(vertex, bases):
		return false
	var spot := TerrainGrid.point_of(vertex)
	var height := shape.height_at(spot.x, spot.y)
	return not is_near_part(spot, height, parts)


## True for a land vertex inside the rim that is still there (the building parts aside).
static func is_open(shape: Terrain, vertex: Vector2i) -> bool:
	if vertex.x < 0 or vertex.y < 0 or vertex.x >= TerrainGrid.SIDE - 1 or vertex.y >= TerrainGrid.SIDE - 1:
		return false
	var id := TerrainGrid.id_of(vertex)
	return shape.index.land[id] != 0 and not shape.field().is_removed(id)


## True when the vertex is one of a base's: one of the four cells around it lies under the base.
static func is_under_base(vertex: Vector2i, bases: Array[Rect2i]) -> bool:
	for base in bases:
		if base.has_point(vertex):
			return true
	return false


## True when a part stands within `BUILDING_CLEARANCE_M` of `spot` (and not far above or below `height`).
static func is_near_part(spot: Vector2, height: float, parts: PackedVector3Array) -> bool:
	for part in parts:
		if not is_nan(height) and absf(part.y - height) > DEPTH_BAND_M:
			continue
		if Vector2(part.x, part.z).distance_squared_to(spot) < BUILDING_CLEARANCE_M * BUILDING_CLEARANCE_M:
			return true
	return false


## The lattice vertices a hole at `center` (x, z in metres) means: the nearest one when `radius_m` is 0, else every one within it.
static func around(center: Vector2, radius_m: float) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var lattice := Rect2i(0, 0, TerrainGrid.SIDE, TerrainGrid.SIDE)
	if radius_m <= 0.0:
		var nearest := TerrainGrid.vertex_near(center)
		if lattice.has_point(nearest):
			found.append(nearest)
		return found
	var rect := TerrainGrid.vertex_rect(center, radius_m)
	for row in rect.size.y:
		for column in rect.size.x:
			var vertex := rect.position + Vector2i(column, row)
			if TerrainGrid.point_of(vertex).distance_to(center) <= radius_m:
				found.append(vertex)
	return found


## The vertices of `around` that may be taken away now. The building parts and bases are gathered only once a vertex passes the rest.
static func removable(shape: Terrain, center: Vector2, radius_m: float) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var parts := PackedVector3Array()
	var bases: Array[Rect2i] = []
	var gathered := false
	for vertex in around(center, radius_m):
		if not is_open(shape, vertex):
			continue
		if not gathered and shape.is_inside_tree():
			parts = parts_of(shape.get_tree())
			bases = bases_of(shape.get_tree())
		gathered = true
		if can_remove(shape, vertex, parts, bases):
			found.append(vertex)
	return found


## The vertex on the ground, never NAN: once its neighbours are gone no land triangle touches it, so it tries a little inside each
## of the four cells around it, then the vertex's own height as the file and the stamps left it, then the lowest land.
static func point_on(shape: Terrain, vertex: Vector2i) -> Vector3:
	var spot := TerrainGrid.point_of(vertex)
	var height := shape.height_at(spot.x, spot.y)
	for side: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		if not is_nan(height):
			break
		var inside := spot + side * TerrainGrid.CELL_M * 0.25
		height = shape.height_at(inside.x, inside.y)
	if is_nan(height):
		height = TerrainRules.height_in(spot.x, spot.y, shape.index.ground, shape.index.cells) + shape.field().at(TerrainGrid.id_of(vertex))
	return Vector3(spot.x, shape.lowest() if is_nan(height) else height, spot.y)


## The places of the parts of every building, manafount and altar under `tree`.
static func parts_of(tree: SceneTree) -> PackedVector3Array:
	var parts := PackedVector3Array()
	for group in [MapBuilding.GROUP, ManafountBody.GROUP, Altar.ANY_GROUP]:
		for node in tree.get_nodes_in_group(group):
			var body := node as Node3D
			if body == null:
				continue
			parts.append(body.global_position)
			var building := body as MapBuilding
			if building != null and building.visuals != null:
				for part in building.visuals.get_children():
					if part is Node3D:
						parts.append((part as Node3D).global_position)
	return parts


## The lattice vertices under every base of `tree` (each GroundFootprint, FootprintRules.vertices_under): a hole there cuts a base.
static func bases_of(tree: SceneTree) -> Array[Rect2i]:
	var bases: Array[Rect2i] = []
	for node in tree.get_nodes_in_group(GroundFootprint.GROUP):
		var footprint := node as GroundFootprint
		if footprint != null:
			bases.append(FootprintRules.vertices_under(footprint.area()))
	return bases
