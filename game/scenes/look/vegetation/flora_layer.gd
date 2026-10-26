@tool
class_name FloraLayer
extends Node3D

## Where one kind of plant grows on a map (child of the map's `Vegetation` node). Paint `density` with the map brush
## (select this node, «Flora» in the 3D bar; it makes the PNG when there is none) or in any image editor (L8 PNG, white =
## `max_per_cell` plants in the cell); 1 px = `cell_m` meters and the image starts at the map origin
## (keep this node at 0, 0, 0). While the brush paints, the field draws the picture being painted (`show_painting`, editor
## only, never saved) until the PNG is saved and imported again. The FloraField of the map's look draws it around the camera: FloraPlacement scatters the
## cell's plants (same tag, cell and seed: same spots), heights from the terrain, none inside a VegetationClear.
## For a few plants in one place use a VegetationPatch instead. Nothing here is simulation: a headless or dedicated
## process never draws it. In the editor `show_overlay` tints the cells where it grows.

const GROUP := &"flora_layer"

@export var species: VegetationSpecies:
	set(value):
		_watch(species, value)
		species = value
		_changed()
@export var density: Texture2D:
	set(value):
		_watch(density, value)
		density = value
		_painting = null  # a painting belongs to the picture it was made from
		_changed()
## Side of one image pixel in the map, in meters. It must divide 32 (the planter's cell).
@export_range(1.0, 32.0, 1.0, "suffix:m") var cell_m := 8.0:
	set(value):
		cell_m = value
		_changed()
## Plants in a cell painted white.
@export_range(1, 255) var max_per_cell := 6:
	set(value):
		max_per_cell = value
		_changed()
## Editor only: a green tint on the ground where this layer grows.
@export var show_overlay := false:
	set(value):
		show_overlay = value
		_changed()

var _painting: Image  ## editor only: the picture the brush is painting, not saved yet


func _enter_tree() -> void:
	add_to_group(GROUP)
	_changed()


func _exit_tree() -> void:
	# Still in the group now: the field gathers again after the frame.
	get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, FloraField.GROUP, &"layers_changed")


## The brush painted `area_m` (map x, z) of `image` (L8, the size of `density`): the field replants that area from it.
func show_painting(image: Image, area_m: Rect2) -> void:
	_painting = image
	if is_inside_tree():
		get_tree().call_group(FloraField.GROUP, &"layer_painted", self, area_m)
	if show_overlay:
		_update_overlay()


## Back to the imported `density` (the brush's picture was saved and imported again).
func stop_painting() -> void:
	_painting = null
	_update_overlay()


## A copy of where it grows as an L8 picture: the brush's painting if one is on, else `density`. Null without one.
func density_image() -> Image:
	if _painting != null:
		return _painting.duplicate() as Image
	if density == null:
		return null
	var image := density.get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_L8)
	return image


func _changed() -> void:
	if not is_inside_tree():
		return
	get_tree().call_group(FloraField.GROUP, &"layers_changed")
	_update_overlay()
	update_configuration_warnings()


func _watch(old: Resource, new: Resource) -> void:
	if old and old.changed.is_connected(_changed):
		old.changed.disconnect(_changed)
	if new and not new.changed.is_connected(_changed):
		new.changed.connect(_changed)


func _update_overlay() -> void:
	for child in get_children(true):
		if child.name == &"Overlay":
			child.free()
	if not (Engine.is_editor_hint() and show_overlay):
		return
	var image := density_image()
	if image == null:
		return
	var bytes := image.get_data()
	var rgba := PackedByteArray()
	rgba.resize(bytes.size() * 4)
	for i in bytes.size():
		rgba[i * 4 + 1] = 255
		rgba[i * 4 + 3] = bytes[i] * 3 / 5
	var decal := Decal.new()
	decal.name = &"Overlay"
	decal.texture_albedo = ImageTexture.create_from_image(Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, rgba))
	var size := Vector2(image.get_size()) * cell_m
	decal.size = Vector3(size.x, 400.0, size.y)
	decal.position = Vector3(size.x, 0.0, size.y) * 0.5
	add_child(decal, false, Node.INTERNAL_MODE_BACK)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if species == null:
		warnings.append("Falta la especie (VegetationSpecies).")
	if density == null:
		warnings.append("Falta la imagen de densidad (PNG L8, 1 px = cell_m).")
	if position != Vector3.ZERO:
		warnings.append("La imagen empieza en el origen del mapa: dejá este nodo en 0, 0, 0.")
	return warnings
