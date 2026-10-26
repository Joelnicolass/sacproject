class_name HoleRules
extends RefCounted

## When the ground may lose a vertex (a hole): never one at the rim of the map, one that is already gone, or one close to a
## building. Pure and static: the caller hands the places of the building parts, so the rule needs no tree. It does not make the
## hole (TerrainDeformer does) nor choose where to dig (HoleCutter).
## Ref: sacengine canRemoveLandVertex (state.d:28999-29026).

## A vertex this close (m, on the ground plane) to a building part is never taken away.
const BUILDING_CLEARANCE_M := 11.0
## A building part this far above or below the vertex is out of the way (sacengine mapDepth).
const DEPTH_BAND_M := 50.0


## True when the vertex at (column, row) may be taken away. `parts` are the world places of the parts of every building.
static func can_remove(shape: GroundSurface, vertex: Vector2i, parts: PackedVector3Array) -> bool:
	if vertex.x < 0 or vertex.y < 0 or vertex.x >= TerrainGrid.SIDE - 1 or vertex.y >= TerrainGrid.SIDE - 1:
		return false
	var id := TerrainGrid.id_of(vertex)
	if shape.index.land[id] == 0 or shape.field().is_removed(id):
		return false
	var spot := TerrainGrid.point_of(vertex)
	var height := shape.height_at(spot.x, spot.y)
	return not is_near_part(spot, height, parts)


## True when a part stands within `BUILDING_CLEARANCE_M` of `spot` (and not far above or below `height`).
static func is_near_part(spot: Vector2, height: float, parts: PackedVector3Array) -> bool:
	for part in parts:
		if not is_nan(height) and absf(part.y - height) > DEPTH_BAND_M:
			continue
		if Vector2(part.x, part.z).distance_squared_to(spot) < BUILDING_CLEARANCE_M * BUILDING_CLEARANCE_M:
			return true
	return false
