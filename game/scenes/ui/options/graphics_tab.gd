class_name GraphicsTab
extends VBoxContainer

## Options → Gráficos. Quality (one of the GraphicsPrefs presets), fullscreen, VSync, the FPS cap,
## the vegetation switch, the relief switch, the number of ground marks and the interface size
## (UiScalePrefs). Every control writes the shared preference at once; the GraphicsApplier and the
## UiScaleApplier of the running scene listen to `changed`, so the change shows live. The controls
## also follow changes made elsewhere. OptionButton, CheckButton and HSlider only: AgentKit drives
## them with select / click / range (no popups needed).

## Tab title in the OptionsMenu.
@export var tab_title := "UI_OPTIONS_TAB_GRAPHICS"
## Shared instances (scenes/ui/graphics_prefs.tres, scenes/ui/ui_scale.tres).
@export var prefs: GraphicsPrefs
@export var ui_scale: UiScalePrefs
## Text of the FPS cap 0.
@export var no_cap_text := "UI_GRAPHICS_NO_CAP"
@export var hud_value_format := "%d %%"


func _ready() -> void:
	if prefs == null or ui_scale == null:
		push_warning("GraphicsTab: faltan prefs o ui_scale.")
		return
	_fill()
	_sync()
	%QualityPick.item_selected.connect(_on_quality)
	%MaxFpsPick.item_selected.connect(_on_max_fps)
	%Fullscreen.toggled.connect(prefs.set_fullscreen)
	%VSync.toggled.connect(prefs.set_vsync)
	%Vegetation.toggled.connect(prefs.set_vegetation_enabled)
	%Grass.toggled.connect(prefs.set_grass_enabled)
	%Relief.toggled.connect(prefs.set_relief_enabled)
	%ScarTiles.value_changed.connect(_on_scar_tiles)
	%HudSize.value_changed.connect(_on_hud_size)
	prefs.changed.connect(_sync)
	ui_scale.changed.connect(_sync)


func _fill() -> void:
	var quality: OptionButton = %QualityPick
	quality.clear()
	for preset in prefs.presets:
		quality.add_item(preset.label)
		quality.set_item_metadata(quality.item_count - 1, preset.id)
	var fps: OptionButton = %MaxFpsPick
	fps.clear()
	for cap in prefs.max_fps_choices:
		fps.add_item(tr(no_cap_text) if cap <= 0 else str(cap))
		fps.set_item_metadata(fps.item_count - 1, cap)
	var slider: HSlider = %HudSize
	slider.min_value = ui_scale.min_scale
	slider.max_value = ui_scale.max_scale
	slider.step = 0.05


## Shows the preference as it is now, without echoing it back.
func _sync() -> void:
	_select_meta(%QualityPick, prefs.quality_id())
	_select_meta(%MaxFpsPick, prefs.max_fps())
	%Fullscreen.set_pressed_no_signal(prefs.fullscreen())
	%VSync.set_pressed_no_signal(prefs.vsync())
	%Vegetation.set_pressed_no_signal(prefs.vegetation_enabled())
	%Grass.set_pressed_no_signal(prefs.grass_enabled())
	%Relief.set_pressed_no_signal(prefs.relief_enabled())
	%ScarTiles.set_value_no_signal(prefs.scar_tiles())
	%ScarTilesValue.text = str(prefs.scar_tiles())
	%HudSize.set_value_no_signal(ui_scale.get_scale())
	%HudValue.text = hud_value_format % roundi(ui_scale.get_scale() * 100.0)


func _on_quality(index: int) -> void:
	prefs.set_quality(StringName(str(%QualityPick.get_item_metadata(index))))


func _on_max_fps(index: int) -> void:
	prefs.set_max_fps(int(%MaxFpsPick.get_item_metadata(index)))


func _on_scar_tiles(value: float) -> void:
	prefs.set_scar_tiles(roundi(value))
	%ScarTilesValue.text = str(prefs.scar_tiles())


func _on_hud_size(value: float) -> void:
	ui_scale.set_scale(value)
	%HudValue.text = hud_value_format % roundi(ui_scale.get_scale() * 100.0)


## Selects the item whose metadata is `value` (a cap not in the list selects nothing).
static func _select_meta(picker: OptionButton, value: Variant) -> void:
	for i in picker.item_count:
		if picker.get_item_metadata(i) == value:
			picker.select(i)
			return
	picker.select(-1)
