class_name UserSettings
extends RefCounted

## RFC-031 031c (F142): the one reader and writer of the player's local preferences, `user://settings.cfg`.
## Each owner keeps its own section (`[hud]` HudScale, `[graphics]` GraphicsPrefs); a write loads the file first,
## so the other sections stay as they are.
## A file that exists but cannot be read (corrupt, no permission) is never overwritten: the reads fall back to the
## caller's defaults and the writes are refused, with one warning each. After a failed load the file is not read again in this run:
## the choices made then apply live but are not saved.

const PATH := "user://settings.cfg"

## Set when the file failed to load: it is not parsed again in this run (the engine logs each parse error).
static var _unreadable := false
static var _warned_write := false


## The value of `[section] key`, or `default` when the file, the key or a readable file is missing.
static func read_value(section: String, key: String, default: Variant) -> Variant:
	var config := _load()
	if config == null or not config.has_section_key(section, key):
		return default
	return config.get_value(section, key, default)


## Writes the pairs of `values` under `[section]` and keeps the rest of the file. False when nothing was written.
static func write_values(section: String, values: Dictionary) -> bool:
	var config := _load()
	if config == null:
		if not _warned_write:
			_warned_write = true
			push_warning("UserSettings: %s no se pudo leer; los cambios valen en esta sesión y no se guardan, para no pisarlo." % PATH)
		return false
	for key in values:
		config.set_value(section, str(key), values[key])
	# Atomic: write a sibling file, then rename it over the real one (a crash never leaves half a file).
	var temp := PATH + ".tmp"
	var saved := config.save(temp)
	if saved == OK:
		saved = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(PATH))
	if saved != OK:
		push_error("UserSettings: no se pudo guardar %s (%s)." % [PATH, error_string(saved)])
		return false
	return true


## The file as it is (empty when it does not exist yet); null when it exists but cannot be read.
static func _load() -> ConfigFile:
	if _unreadable:
		return null
	var config := ConfigFile.new()
	var loaded := config.load(PATH)
	if loaded == OK or loaded == ERR_FILE_NOT_FOUND:
		return config
	_unreadable = true
	push_warning("UserSettings: %s no se pudo leer (%s); se usan los valores por defecto y el archivo queda como está." % [PATH, error_string(loaded)])
	return null
