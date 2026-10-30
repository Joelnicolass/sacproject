# gdlint:disable=max-public-methods
@tool
class_name GraphicsPrefs
extends Resource

## The player's graphics choice, a local preference (not a match rule).
## - The quality is one of `presets` (the existing LookQuality .tres); this resource never copies
##   their fields.
## - VSync, fullscreen and the FPS cap are the window's.
## - «Vegetación»: off, the mesh vegetation layers (FloraField) draw nothing whatever the preset
##   says.
## - «Pasto»: off, the grass (GrassLayer) draws nothing whatever the preset says; it takes effect at
##   once, in a match too.
## - «Estética PS1»: on, the PS1 look (PostFx, psx_screen.tscn) covers the 3D view; off by
##   default. It takes effect at once (GraphicsApplier).
## - «Relieve»: off, no model draws its normal maps whatever the preset says (SurfaceReliefLayer
##   reads it).
## - It lives in `user://settings.cfg` `[graphics]` through UserSettings.
##   `--quality=low|medium|high` on the command line wins for one run and is not saved.
## - «Avanzado»: any field of the preset (LookQuality) set on its own (`set_override`); `quality()`
##   is then a runtime copy of the preset with those values, the preset file never changes. Saved
##   as `overrides` (field name → value) and kept when the preset changes.
## - «Cantidad de marcas»: how many 10 m tiles of the ground can hold a mark (burns, cracks) at
##   once; GroundScars reads it when the map loads.
## - First run: `default_quality` (medium), VSync on, windowed, no cap. The Mac safety rule: nothing
##   here raises the GPU use unless the player asks for it.
## Like UiScalePrefs, every node must share the instance at `SHARED_PATH` (a copy would not follow
## the player's choice); the values are runtime state of that instance and the exported fields are
## never written. Changes emit `changed`.

const SHARED_PATH := "res://scenes/ui/graphics_prefs.tres"
const SECTION := "graphics"
const ARG := "--quality="

## The selectable presets, low to high.
@export var presets: Array[LookQuality] = []
## The `id` of the preset used when the player chose nothing.
@export var default_quality: StringName = &"medium"
@export var default_vsync := true
@export var default_fullscreen := false
@export var default_vegetation := true
@export var default_grass := true
@export var default_relief := true
## The PS1 look over the 3D view (PostFx, psx_screen.tscn). Off by default.
@export var default_psx := false
## 32 to 256 painted ground tiles.
@export_range(32, 256) var default_scar_tiles := 256
## 0 = no cap.
@export_range(0, 360) var default_max_fps := 0
## FPS caps the menu offers (0 = «Sin tope»).
@export var max_fps_choices: PackedInt32Array = PackedInt32Array([0, 30, 60, 120])

var _loaded := false
var _quality: StringName
## What the file holds (or will): `--quality=` changes `_quality` for this run only.
var _stored_quality: StringName
var _vsync := true
var _fullscreen := false
var _max_fps := 0
var _vegetation := true
var _grass := true
var _psx := false
## Fields of the preset the player set by hand (LookQuality property → value).
var _overrides := {}
## `quality()` with the overrides, made again when the preset or an override changes.
var _custom: LookQuality
var _relief := true
var _scar_tiles := 256


## The preset in use (command line, then the settings file, then `default_quality`).
func quality() -> LookQuality:
	_ensure_loaded()
	var preset := preset_for(_quality)
	if preset == null or _overrides.is_empty():
		return preset
	if _custom == null:
		_custom = preset.duplicate() as LookQuality
		for property: String in _overrides:
			_custom.set(property, _overrides[property])
	return _custom


## The preset as its file holds it, without the player's overrides.
func base_quality() -> LookQuality:
	_ensure_loaded()
	return preset_for(_quality)


## The value the player set for `property` of the preset; null when it follows the preset.
func override_of(property: StringName) -> Variant:
	_ensure_loaded()
	return _overrides.get(String(property))


func set_override(property: StringName, value: Variant) -> void:
	_ensure_loaded()
	if _overrides.get(String(property)) == value:
		return
	_overrides[String(property)] = value
	_custom = null
	_commit()


## `property` follows the preset again.
func clear_override(property: StringName) -> void:
	_ensure_loaded()
	if not _overrides.has(String(property)):
		return
	_overrides.erase(String(property))
	_custom = null
	_commit()


func clear_overrides() -> void:
	_ensure_loaded()
	if _overrides.is_empty():
		return
	_overrides.clear()
	_custom = null
	_commit()


func has_overrides() -> bool:
	_ensure_loaded()
	return not _overrides.is_empty()


func quality_id() -> StringName:
	_ensure_loaded()
	return _quality


func vsync() -> bool:
	_ensure_loaded()
	return _vsync


func fullscreen() -> bool:
	_ensure_loaded()
	return _fullscreen


func max_fps() -> int:
	_ensure_loaded()
	return _max_fps


func vegetation_enabled() -> bool:
	_ensure_loaded()
	return _vegetation


func grass_enabled() -> bool:
	_ensure_loaded()
	return _grass


func set_grass_enabled(on: bool) -> void:
	if on == grass_enabled():
		return
	_grass = on
	_commit()


func psx_enabled() -> bool:
	_ensure_loaded()
	return _psx


func set_psx_enabled(on: bool) -> void:
	if on == psx_enabled():
		return
	_psx = on
	_commit()


func relief_enabled() -> bool:
	_ensure_loaded()
	return _relief


func set_relief_enabled(on: bool) -> void:
	if on == relief_enabled():
		return
	_relief = on
	_commit()


func scar_tiles() -> int:
	_ensure_loaded()
	return _scar_tiles


func set_scar_tiles(count: int) -> void:
	var next := clampi(count, 32, 256)
	if next == scar_tiles():
		return
	_scar_tiles = next
	_commit()


func set_vegetation_enabled(on: bool) -> void:
	if on == vegetation_enabled():
		return
	_vegetation = on
	_commit()


func set_quality(id: StringName) -> void:
	if preset_for(id) == null or id == quality_id():
		return
	_quality = id
	_stored_quality = id
	_custom = null
	_commit()


func set_vsync(on: bool) -> void:
	if on == vsync():
		return
	_vsync = on
	_commit()


func set_fullscreen(on: bool) -> void:
	if on == fullscreen():
		return
	_fullscreen = on
	_commit()


func set_max_fps(value: int) -> void:
	var next := maxi(value, 0)
	if next == max_fps():
		return
	_max_fps = next
	_commit()


## The preset `--quality=` asked for in this run, or null (the sandboxed runs use it over their
## default).
func forced_quality() -> LookQuality:
	return preset_for(_cli_quality())


## The preset whose `id` is `id`, or null.
func preset_for(id: StringName) -> LookQuality:
	for preset in presets:
		if preset and preset.id == id:
			return preset
	return null


## Warning text for a node whose `graphics_prefs` is not the shared instance ("" when it is).
static func socket_warning(prefs: GraphicsPrefs) -> String:
	if prefs == null:
		return "Assign `prefs` (%s)." % SHARED_PATH
	if prefs.resource_path != SHARED_PATH:
		return "`prefs` is not %s: this node will not follow the player's choice." % SHARED_PATH
	return ""


func _commit() -> void:
	if not Engine.is_editor_hint():
		(
			UserSettings
			. write_values(
				SECTION,
				{
					"quality": String(_stored_quality),
					"vsync": _vsync,
					"fullscreen": _fullscreen,
					"max_fps": _max_fps,
					"vegetation": _vegetation,
					"grass": _grass,
					"psx": _psx,
					"overrides": _overrides,
					"relief": _relief,
					"scar_tiles": _scar_tiles,
				}
			)
		)
	emit_changed()


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_quality = default_quality
	_vsync = default_vsync
	_fullscreen = default_fullscreen
	_max_fps = default_max_fps
	_vegetation = default_vegetation
	_grass = default_grass
	_psx = default_psx
	_relief = default_relief
	_scar_tiles = default_scar_tiles
	if Engine.is_editor_hint():
		return
	var stored_quality := StringName(
		str(UserSettings.read_value(SECTION, "quality", String(default_quality)))
	)
	if preset_for(stored_quality):
		_quality = stored_quality
	else:
		push_warning(
			(
				"GraphicsPrefs: [%s] quality = %s is not a preset; using %s."
				% [SECTION, stored_quality, default_quality]
			)
		)
	_vsync = _read_bool("vsync", default_vsync)
	_fullscreen = _read_bool("fullscreen", default_fullscreen)
	_vegetation = _read_bool("vegetation", default_vegetation)
	_grass = _read_bool("grass", default_grass)
	_psx = _read_bool("psx", default_psx)
	var stored: Variant = UserSettings.read_value(SECTION, "overrides", {})
	_overrides = (stored as Dictionary).duplicate() if stored is Dictionary else {}
	_relief = _read_bool("relief", default_relief)
	var tiles: Variant = UserSettings.read_value(SECTION, "scar_tiles", default_scar_tiles)
	_scar_tiles = (
		clampi(int(tiles), 32, 256)
		if typeof(tiles) in [TYPE_INT, TYPE_FLOAT]
		else default_scar_tiles
	)
	var fps: Variant = UserSettings.read_value(SECTION, "max_fps", default_max_fps)
	_max_fps = maxi(int(fps), 0) if typeof(fps) in [TYPE_INT, TYPE_FLOAT] else default_max_fps
	_stored_quality = _quality
	var cli := _cli_quality()
	if not cli.is_empty():
		_quality = cli


func _read_bool(key: String, fallback: bool) -> bool:
	var value: Variant = UserSettings.read_value(SECTION, key, fallback)
	return value if typeof(value) == TYPE_BOOL else fallback


## `--quality=` of this run, or &"" (an unknown id warns and is ignored).
func _cli_quality() -> StringName:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with(ARG):
			var id := StringName(arg.substr(ARG.length()))
			if preset_for(id):
				return id
			push_warning("GraphicsPrefs: %s is not a preset; ignored." % arg)
	return &""
