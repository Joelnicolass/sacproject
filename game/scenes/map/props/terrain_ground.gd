@tool
class_name TerrainGround
extends PropGround

## The map's Terrain as the ground of a PropKit scatter (the forest): props stand on land, never
## over a hole or off the map, and fewer of them on rock (Terrain.ground_roles, B). The scatter calls
## it in the editor too, on the Terrain of the scatter's own map.

## Fewer props on rock: 1 = none on bare rock, 0 = rock is like any land.
@export_range(0.0, 1.0, 0.05) var rock_thinning := 0.6

var _terrain: Terrain
var _roles: Image


func begin(scatter: Node) -> bool:
	_terrain = Terrain.of(scatter)
	if _terrain == null:
		return false
	_roles = _terrain.ground_roles.get_image() if _terrain.ground_roles != null else null
	if _roles != null and _roles.is_compressed():
		_roles.decompress()
	return true


func bounds() -> Rect2:
	return _terrain.bounds()


func height_at(at: Vector2) -> float:
	return _terrain.height_at(at.x, at.y)


func weight_at(at: Vector2) -> float:
	if not _terrain.is_on_ground(at.x, at.y):
		return 0.0
	if _roles == null:
		return 1.0
	var area := _terrain.bounds()
	var uv := (at - area.position) / area.size
	var pixel := Vector2i(
		clampi(int(uv.x * _roles.get_width()), 0, _roles.get_width() - 1),
		clampi(int(uv.y * _roles.get_height()), 0, _roles.get_height() - 1)
	)
	return 1.0 - rock_thinning * _roles.get_pixelv(pixel).b
