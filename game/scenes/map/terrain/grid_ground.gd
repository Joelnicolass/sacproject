class_name GridGround
extends GroundBackend

## The ground of a grid map: the 10 m lattice of a MapTerrainData, answered through TerrainRules and moved by the field. It
## goes away with the grid maps (063 stage 4). What it does NOT do: build the index (TerrainRules.index) or own the field
## (GroundSurface does).

## The land of the file, filed per 10 m cell.
var index: TerrainRules.Index
var _field: GroundField


func _init(land: TerrainRules.Index, field: GroundField) -> void:
	index = land
	_field = field


func is_loaded() -> bool:
	return not index.ground.is_empty()


func height_at(x: float, z: float) -> float:
	return TerrainRules.height_in(x, z, index.ground, index.cells, _field.texels, index.corners)


func is_on_ground(x: float, z: float) -> bool:
	return TerrainRules.triangle_in(x, z, index.ground, index.cells, _field.texels, index.corners) >= 0


func normal_at(x: float, z: float) -> Vector3:
	return TerrainRules.normal_in(x, z, index.ground, index.cells, _field.texels, index.corners)


func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(_field.size) * _field.cell_m)


func lowest() -> float:
	return index.lowest


## Taken from the index and the field as they are now (a later change does not touch it).
func sampler() -> Callable:
	return TerrainRules.height_in.bind(index.ground, index.cells, _field.snapshot(), index.corners)
