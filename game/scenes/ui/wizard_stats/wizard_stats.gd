@tool
class_name WizardStats
extends Control

## The stats block at the top-right corner: the 77×115 soul frame, then mana and health, 38×115 each, on the `fram` sheet
## (top half stretched, bottom half mirrored). The block is 154×115 canvas pixels in the scene; Godot's stretch scales it.
## Never takes the mouse. The panels split the block by anchors in the scene; this script only feeds the values.
## Ref: renderer.d:4770-4830 renderStats (sizes ×1.2), dagonBackend.d:3076 ShapeSacStatsFrame.

## Pixel region of the frame on the `fram` sheet (top half; the bottom half mirrors it).
@export var frame_region := Rect2(64.0, 0.0, 31.0, 31.0)
@export var frame_mirror_region := Rect2(64.0, 1.0, 31.0, 30.5)
## Panels whose `Top` and `Bottom` TextureRect children draw the frame.
@export var frames: Array[Control] = []

## Values last shown (read by the flows).
var health_fraction := 0.0
var mana_fraction := 0.0
var souls_shown := 0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if Engine.is_editor_hint():
		return
	var top := HudIcons.region("fram", frame_region)
	var bottom := HudIcons.region("fram", frame_mirror_region)
	for panel in frames:
		(panel.get_node("Top") as TextureRect).texture = top
		(panel.get_node("Bottom") as TextureRect).texture = bottom


## Health and mana as 0…1 of their maximum, and the soul count.
func show_values(health: float, mana: float, souls: int) -> void:
	health_fraction = clampf(health, 0.0, 1.0)
	mana_fraction = clampf(mana, 0.0, 1.0)
	souls_shown = souls
	(%HealthBar as StatBar).fraction = health_fraction
	(%ManaBar as StatBar).fraction = mana_fraction
	(%SoulCounter as SoulCounter).souls = souls

