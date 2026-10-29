@tool
class_name GrassMap
extends ImageTexture

## A map painted by GrassKit's brushes, kept inside its GrassGround: where grass grows, how tall,
## the ground's colour, where a kind grows. A texture like any other for the shader; its `source`
## image is what is painted and what is saved, so it never depends on reading the GPU back (a
## headless editor or a test saves it as painted). Export it as a PNG from the 3D view's «Grass»
## menu to edit it elsewhere.

## The painted image (red for density, size and kinds; RGBA for the colour).
@export_storage var source: Image:
	set(value):
		source = value
		if value != null and not value.is_empty():
			set_image(value)


## A map holding `image` (kept, not copied).
static func from(image: Image) -> GrassMap:
	var map := GrassMap.new()
	map.source = image
	return map


## The texture shows `source` as it is now (after painting it).
func refresh() -> void:
	if source != null and not source.is_empty():
		set_image(source)


func _validate_property(property: Dictionary) -> void:
	# `source` is what is saved: the texture's own copy would only double the file.
	if property["name"] == "image":
		property["usage"] = PROPERTY_USAGE_NONE
