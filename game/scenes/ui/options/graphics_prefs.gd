@tool
class_name GraphicsPrefs
extends Resource

## RFC-031 031c (F142): the player's graphics choice, a local preference (not a match rule).
## - The quality is one of `presets` (the existing LookQuality .tres); this resource never copies their fields.
## - VSync, fullscreen and the FPS cap are the window's.
## - «Vegetación» (RFC-054 054f): off, the mesh vegetation layers (FloraField) draw nothing whatever the preset says.
## - «Relieve» (RFC-067): off, no model draws its normal maps whatever the preset says (SurfaceReliefLayer reads it).
## - It lives in `user://settings.cfg` `[graphics]` through UserSettings. `--quality=low|medium|high` on the command
##   line wins for one run and is not saved.
## - «Cantidad de marcas»: how many 10 m tiles of the ground can hold a mark (burns, cracks) at once; GroundScars reads it when the map loads.
## - First run: `default_quality` (medium), VSync on, windowed, no cap. The Mac safety rule: nothing here raises the
##   GPU use unless the player asks for it.
## Like UiScalePrefs, every node must share the instance at `SHARED_PATH` (a copy would not follow the player's choice);
## the values are runtime state of that instance and the exported fields are never written. Changes emit `changed`.

const SHARED_PATH := "res://data/ui/graphics_prefs.tres"
const SECTION := "graphics"
const ARG := "--quality="

## The selectable presets, low to high.
@export var presets: Array[LookQuality] = []
## The `id` of the preset used when the player chose nothing.
@export var default_quality: StringName = &"medium"
@export var default_vsync := true
@export var default_fullscreen := false
@export var default_vegetation := true
@export var default_relief := true
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
var _relief := true
var _scar_tiles := 256


## The preset in use (command line, then the settings file, then `default_quality`).
func quality() -> LookQuality:
	_ensure_loaded()
	return preset_for(_quality)


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


## The preset `--quality=` asked for in this run, or null (the sandboxed runs use it over their default).
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
		return "Asigná `prefs` (%s)." % SHARED_PATH
	if prefs.resource_path != SHARED_PATH:
		return "`prefs` no es %s: este nodo no seguirá la elección del jugador." % SHARED_PATH
	return ""


func _commit() -> void:
	if not Engine.is_editor_hint():
		UserSettings.write_values(SECTION, {
			"quality": String(_stored_quality),
			"vsync": _vsync,
			"fullscreen": _fullscreen,
			"max_fps": _max_fps,
			"vegetation": _vegetation,
			"relief": _relief,
			"scar_tiles": _scar_tiles,
		})
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
	_relief = default_relief
	_scar_tiles = default_scar_tiles
	if Engine.is_editor_hint():
		return
	var stored_quality := StringName(str(UserSettings.read_value(SECTION, "quality", String(default_quality))))
	if preset_for(stored_quality):
		_quality = stored_quality
	else:
		push_warning("GraphicsPrefs: [%s] quality = %s no es un preset; se usa %s." % [SECTION, stored_quality, default_quality])
	_vsync = _read_bool("vsync", default_vsync)
	_fullscreen = _read_bool("fullscreen", default_fullscreen)
	_vegetation = _read_bool("vegetation", default_vegetation)
	_relief = _read_bool("relief", default_relief)
	var tiles: Variant = UserSettings.read_value(SECTION, "scar_tiles", default_scar_tiles)
	_scar_tiles = clampi(int(tiles), 32, 256) if typeof(tiles) in [TYPE_INT, TYPE_FLOAT] else default_scar_tiles
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
			push_warning("GraphicsPrefs: %s no es un preset; se ignora." % arg)
	return &""
