@tool
class_name PropMask
extends Resource

## A painted map of where props go, over `area` of the ground plane: one channel thins them (its
## value multiplies the chance) and one forbids them (above `forbid_above`). Paint it in any image
## editor. Import the texture lossless or uncompressed for exact values; a compressed one is read
## after decompressing.

enum Channel { NONE, RED, GREEN, BLUE, ALPHA }

@export var texture: Texture2D
## What the texture covers, in global coordinates of the ground plane. Empty = the ground's bounds.
@export var area := Rect2()
## The channel that thins props: 1 keeps the chance, 0 takes it away. NONE = no thinning.
@export var density_channel := Channel.RED
## How much the density channel thins: 1 = all the way (0 in the channel = no prop), 0.6 = at most
## 60 % fewer props, 0 = no thinning.
@export_range(0.0, 1.0, 0.01) var density_strength := 1.0
## Read the density channel the other way round: white = fewer props (rock painted white).
@export var density_invert := false
## The channel that forbids props where it is above `forbid_above`. NONE = forbids nothing.
@export var forbid_channel := Channel.NONE
@export_range(0.0, 1.0, 0.01) var forbid_above := 0.5

var _image: Image
var _area := Rect2()


## Reads the texture for one scatter over `ground_bounds`. False when it cannot be read.
func begin(ground_bounds: Rect2) -> bool:
	_image = null
	_area = area if area.has_area() else ground_bounds
	if texture == null:
		return true
	var image := texture.get_image()
	if image == null or image.is_empty() or not _area.has_area():
		return false
	if image.is_compressed():
		image.decompress()
	_image = image
	return true


## The multiplier of a prop's chance at `at` (0..1). 1 without a texture or outside the area.
func weight_at(at: Vector2) -> float:
	if _image == null or not _area.has_point(at):
		return 1.0
	var uv := (at - _area.position) / _area.size
	var px := Vector2i(
		clampi(int(uv.x * _image.get_width()), 0, _image.get_width() - 1),
		clampi(int(uv.y * _image.get_height()), 0, _image.get_height() - 1)
	)
	var color := _image.get_pixelv(px)
	if forbid_channel != Channel.NONE and _channel(color, forbid_channel) > forbid_above:
		return 0.0
	if density_channel == Channel.NONE:
		return 1.0
	var value := _channel(color, density_channel)
	if density_invert:
		value = 1.0 - value
	return 1.0 - density_strength * (1.0 - value)


func _channel(color: Color, channel: Channel) -> float:
	match channel:
		Channel.RED:
			return color.r
		Channel.GREEN:
			return color.g
		Channel.BLUE:
			return color.b
		Channel.ALPHA:
			return color.a
	return 1.0
