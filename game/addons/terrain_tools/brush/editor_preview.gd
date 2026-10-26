@tool
extends RefCounted

## Shows on the ground how the heights being edited differ from those the mesh was built from, while a stroke is drawn and
## until the mesh is built again: it hands the ground shaders that shift in the global `terrain_deform_map` (one texel per
## lattice vertex: R = metres up, G = 1 on a painted void, which the shader cuts out), the texture TerrainDeformTexture
## fills in a match, and turns `terrain_deform_on` on. A void filled back shows only once the mesh is built again (the mesh
## has no triangles there). Editor only. Not: the heights (TerrainHistory), the cursor, the mesh.

const MAP := &"terrain_deform_map"
const LIVE_RECT := &"terrain_live_rect"
const ON := &"terrain_deform_on"

var _shown_heights := PackedFloat32Array()  ## what the mesh on screen was built from
var _shown_mask := PackedByteArray()
var _image := Image.create_empty(TerrainGrid.SIDE, TerrainGrid.SIDE, false, Image.FORMAT_RGF)
var _texture := ImageTexture.create_from_image(_image)
## The vertices shifted since the shift was last all zero.
var _dirty := Rect2i()
var _on := false


## The mesh was built from `shown`: the shift is worked out again against it, for the vertices that had one, from the
## heights and voids the editor has now (TerrainGrid.COUNT values each). Where they match, the shift goes.
func adopt(shown: TerrainHeights, heights: PackedFloat32Array, mask: PackedByteArray) -> void:
	_shown_heights = shown.heights_m.duplicate()
	_shown_mask = shown.void_mask.duplicate()
	var rect := _dirty
	_dirty = Rect2i()
	if _paint(rect, heights, mask):
		_on_screen()
	else:
		_off()


## Shifts the vertices of `rect` to `heights` and `mask`.
func show(rect: Rect2i, heights: PackedFloat32Array, mask: PackedByteArray) -> void:
	if _shown_heights.size() != TerrainGrid.COUNT or not rect.has_area():
		return
	if _paint(rect, heights, mask):
		_on_screen()


## No shift on screen.
func clear() -> void:
	_dirty = Rect2i()
	_off()


## Writes the shift of `rect` into the texture and sends it; true when some vertex of it is shifted.
func _paint(rect: Rect2i, heights: PackedFloat32Array, mask: PackedByteArray) -> bool:
	if not rect.has_area():
		return false
	var shifted := false
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var id := TerrainGrid.id_of(Vector2i(x, z))
			var up := heights[id] - _shown_heights[id]
			var cut := 1.0 if mask[id] != 0 and _shown_mask[id] == 0 else 0.0
			_image.set_pixel(x, z, Color(up, cut, 0.0))
			shifted = shifted or up != 0.0 or cut != 0.0
	RenderingServer.texture_2d_update(_texture.get_rid(), _image, 0)
	if shifted:
		_dirty = _dirty.merge(rect) if _dirty.has_area() else rect
	return shifted


func _on_screen() -> void:
	if not _on:
		_on = true
		RenderingServer.global_shader_parameter_set(MAP, _texture)
		RenderingServer.global_shader_parameter_set(LIVE_RECT, Vector4.ZERO)
		RenderingServer.global_shader_parameter_set(ON, 1.0)


func _off() -> void:
	if _on:
		_on = false
		_image.fill(Color(0.0, 0.0, 0.0))
		RenderingServer.texture_2d_update(_texture.get_rid(), _image, 0)
		RenderingServer.global_shader_parameter_set(ON, 0.0)
