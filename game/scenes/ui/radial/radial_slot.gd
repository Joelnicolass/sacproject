@tool
class_name RadialSlot
extends Control

## One icon of a radial ring: the picture and a glow. It knows nothing about the menu. The hover state is tweened:
## the hovered icon grows and glows, the others dim while something is hovered.
## Ref: RFC-038 038c.

@export var icon_rect: TextureRect
@export var highlight: Control
@export_group("Hover")
@export var hover_s := 0.12
@export var highlight_scale := 1.3
@export var idle_tint := Color(0.88, 0.88, 0.92, 1.0)
@export var dim_tint := Color(0.5, 0.5, 0.56, 0.75)

var entry: RadialEntry

var _tween: Tween


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if icon_rect != null and highlight != null else PackedStringArray(["Asigná icon_rect y highlight."])


func setup(value: RadialEntry, size_px: float) -> void:
	entry = value
	custom_minimum_size = Vector2.ONE * size_px
	size = Vector2.ONE * size_px
	pivot_offset = size * 0.5
	icon_rect.texture = value.display_icon()
	set_state(false, false, false)


## `hovered`: the pointer is on this entry. `dimmed`: it is on another one. `animate` false snaps (opening, editor).
func set_state(hovered: bool, dimmed: bool, animate := true) -> void:
	var tint := Color.WHITE if hovered else (dim_tint if dimmed else idle_tint)
	var grown := Vector2.ONE * (highlight_scale if hovered else 1.0)
	var glow := 1.0 if hovered else 0.0
	if _tween:
		_tween.kill()
	if not animate or not is_inside_tree() or Engine.is_editor_hint():
		scale = grown
		icon_rect.modulate = tint
		highlight.modulate.a = glow
		highlight.visible = hovered
		return
	highlight.visible = true
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", grown, hover_s)
	_tween.tween_property(icon_rect, "modulate", tint, hover_s)
	_tween.tween_property(highlight, "modulate:a", glow, hover_s)
