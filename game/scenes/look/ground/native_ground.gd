@tool
class_name NativeGround
extends Resource

## The ground a map has in its own land (the tutorial and Alpine Meadow in Persephone's): the tiles the map paints, each at the
## id the map stores, and the map's tile index. A look of that god wears it instead of its generic atlas, so the grass and
## the earth are the ones the map was made with. It does not decide when it is worn (TerrainLayer does) and holds no
## material: the god's classic ground gets these textures on a copy.

## The god (`LookProfile.god`) whose land the map is made of.
@export var god: StringName = &""
## 1024x1024, a 16x16 grid of 64x64 tiles; the tiles the map paints, each at its own id.
@export var atlas: Texture2D
## 256x256, one pixel per 10 m cell, the tile id in R.
@export var tiles: Texture2D
## The baked light of the map's ground.
@export var light: Texture2D


## Puts the three textures on a classic ground material (`sacrifice_ground.gdshader`).
func dress(material: ShaderMaterial) -> void:
	material.set_shader_parameter("atlas", atlas)
	material.set_shader_parameter("tile_index", tiles)
	material.set_shader_parameter("use_tile_index", tiles != null)
	if light != null:
		material.set_shader_parameter("lightmap", light)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if god == &"" or atlas == null or tiles == null:
		warnings.append("Asigná `god`, `atlas` y `tiles`.")
	return warnings
