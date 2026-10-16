@tool
class_name WizardStats
extends Control

## The original's stats block, pinned to the top-right corner (sacengine renderStats,
## renderer.d:4770-4830): the 64×96-unit soul frame, then mana and health, 32×96 each, on the `fram`
## sheet (region u 0.5–0.75, v 0–0.25: top half stretched, bottom half mirrored; ShapeSacStatsFrame,
## dagonBackend.d:3076). Sized by the shared `hud_scale` (pixels = units · HudScale.factor) and rebuilt
## when the scale or the viewport changes. Never takes the mouse.
## The panels split the block by anchors in the scene; this script only sizes it and feeds the values.

## Shared HUD size (spell book, roster and cursor read the same one).
@export var hud_scale: HudScale = preload("res://data/ui/hud_scale.tres")
## Size of the whole block in HUD units (64 + 32 + 32 × 96).
@export var block_units := Vector2(128.0, 96.0)
## Pixel region of the frame on the `fram` sheet (top half; the bottom half mirrors it).
@export var frame_region := Rect2(64.0, 0.0, 31.0, 31.0)
@export var frame_mirror_region := Rect2(64.0, 1.0, 31.0, 30.5)
## Panels whose `Top` and `Bottom` TextureRect children draw the frame.
@export var frames: Array[Control] = []

## Values last shown (read by the flows).
var health_fraction := 0.0
var mana_fraction := 0.0
var souls_shown := 0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var scale_warning := HudScale.socket_warning(hud_scale)
	if not scale_warning.is_empty():
		warnings.append(scale_warning)
	return warnings


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if Engine.is_editor_hint():
		return
	var top := HudIcons.region("fram", frame_region)
	var bottom := HudIcons.region("fram", frame_mirror_region)
	for panel in frames:
		(panel.get_node("Top") as TextureRect).texture = top
		(panel.get_node("Bottom") as TextureRect).texture = bottom
	get_viewport().size_changed.connect(_fit)
	if hud_scale:
		hud_scale.changed.connect(_fit)
	_fit()


## Health and mana as 0…1 of their maximum, and the soul count.
func show_values(health: float, mana: float, souls: int) -> void:
	health_fraction = clampf(health, 0.0, 1.0)
	mana_fraction = clampf(mana, 0.0, 1.0)
	souls_shown = souls
	(%HealthBar as StatBar).fraction = health_fraction
	(%ManaBar as StatBar).fraction = mana_fraction
	(%SoulCounter as SoulCounter).souls = souls


func _fit() -> void:
	var height := get_viewport().get_visible_rect().size.y
	var factor := hud_scale.factor(height) if hud_scale else height / HudScale.SACENGINE_HEIGHT
	custom_minimum_size = block_units * factor
	size = custom_minimum_size
