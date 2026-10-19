@tool
class_name AudioPrefs
extends Resource

## RFC-052 052a (F360): the player's volumes, a local preference (not a match rule).
## - One linear value 0..1 per bus of default_bus_layout.tres (Master, Music, SFX, Voice, Ambience) and «Silenciar»
##   (mutes Master, keeps the values). 0 is silence (the bus is muted); the rest goes through linear_to_db.
## - It lives in `user://settings.cfg` `[audio]` through UserSettings (sandboxed under AgentKit).
## - Under AgentKit (`--agent=…`) Master starts at 0 for this run unless `--audio-on`: a playtest is silent by default.
## - SoundBus applies it to the AudioServer at start and on every `changed`; this resource never touches the server.
## Like GraphicsPrefs, every node must share the instance at `SHARED_PATH`; the values are runtime state of that
## instance and the exported fields are never written. Changes emit `changed`.

const SHARED_PATH := "res://data/ui/audio_prefs.tres"
const SECTION := "audio"
const MUTED_KEY := "muted"
const AUDIO_ON_FLAG := "--audio-on"
## The buses the menu shows, in order. Their file keys are the names in lower case.
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"Voice", &"Ambience"]

@export_range(0.0, 1.0, 0.01) var default_master := 1.0
@export_range(0.0, 1.0, 0.01) var default_music := 0.7
@export_range(0.0, 1.0, 0.01) var default_sfx := 1.0
@export_range(0.0, 1.0, 0.01) var default_voice := 1.0
@export_range(0.0, 1.0, 0.01) var default_ambience := 0.8
## The volume given to a bus at 0 (muted anyway; this keeps its fader off -inf).
@export_range(-80.0, -40.0, 1.0, "suffix:dB") var silent_db := -80.0

var _loaded := false
## bus name -> linear 0..1.
var _volumes: Dictionary = {}
var _muted := false


## Linear 0..1 of `bus` (one of BUSES; an unknown name is 0).
func volume(bus: StringName) -> float:
	_ensure_loaded()
	return float(_volumes.get(bus, 0.0))


func muted() -> bool:
	_ensure_loaded()
	return _muted


func set_volume(bus: StringName, value: float) -> void:
	if not bus in BUSES:
		return
	var next := clampf(value, 0.0, 1.0)
	if is_equal_approx(next, volume(bus)):
		return
	_volumes[bus] = next
	_commit()


func set_muted(on: bool) -> void:
	if on == muted():
		return
	_muted = on
	_commit()


## The dB of a linear value (0 = `silent_db`; the bus is muted too).
func db_for(linear: float) -> float:
	return silent_db if linear <= 0.0 else maxf(linear_to_db(linear), silent_db)


## Whether `bus` is silent: its value is 0, or it is Master and «Silenciar» is on.
func is_bus_silent(bus: StringName) -> bool:
	return volume(bus) <= 0.0 or (bus == &"Master" and muted())


static func key_for(bus: StringName) -> String:
	return String(bus).to_lower()


## Under AgentKit a run starts with Master at 0 unless `--audio-on` (pure: the cases pass the args).
static func agent_starts_silent(args: PackedStringArray) -> bool:
	var under_agent := false
	for arg in args:
		if arg == AUDIO_ON_FLAG:
			return false
		if arg.begins_with("--agent="):
			under_agent = true
	return under_agent


## Warning text for a node whose `prefs` is not the shared instance ("" when it is).
static func socket_warning(prefs: AudioPrefs) -> String:
	if prefs == null:
		return "Asigná `prefs` (%s)." % SHARED_PATH
	if prefs.resource_path != SHARED_PATH:
		return "`prefs` no es %s: este nodo no seguirá la elección del jugador." % SHARED_PATH
	return ""


func _defaults() -> Dictionary:
	return {
		&"Master": default_master, &"Music": default_music, &"SFX": default_sfx,
		&"Voice": default_voice, &"Ambience": default_ambience,
	}


func _commit() -> void:
	if not Engine.is_editor_hint():
		var values := {MUTED_KEY: _muted}
		for bus in BUSES:
			values[key_for(bus)] = float(_volumes[bus])
		UserSettings.write_values(SECTION, values)
	emit_changed()


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_volumes = _defaults()
	_muted = false
	if Engine.is_editor_hint():
		return
	for bus in BUSES:
		var stored: Variant = UserSettings.read_value(SECTION, key_for(bus), null)
		if typeof(stored) in [TYPE_INT, TYPE_FLOAT]:
			_volumes[bus] = clampf(float(stored), 0.0, 1.0)
		elif stored != null:
			push_warning("AudioPrefs: [%s] %s = %s no es un número; se usa %s." % [SECTION, key_for(bus), stored, _volumes[bus]])
	var stored_muted: Variant = UserSettings.read_value(SECTION, MUTED_KEY, false)
	_muted = stored_muted if typeof(stored_muted) == TYPE_BOOL else false
	if agent_starts_silent(OS.get_cmdline_user_args()):
		_volumes[&"Master"] = 0.0
