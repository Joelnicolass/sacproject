class_name UserSettings
extends RefCounted

## RFC-031 031c (F142): the one reader and writer of the player's local preferences, `user://settings.cfg`.
## Each owner keeps its own section (`[hud]` HudScale, `[graphics]` GraphicsPrefs); a write loads the file first,
## so the other sections stay as they are.
## A file that exists but cannot be read (corrupt, no permission) is never overwritten: the reads fall back to the
## caller's defaults and the writes are refused, with one warning each. After a failed load the file is not read again in this run:
## the choices made then apply live but are not saved.
## Sandbox (RFC-031 §3.5): under AgentKit (`--agent=…` in the user args) the player's file is never read nor written.
## Reads give the caller's defaults and writes go to an in-memory ConfigFile, so the UI and the match setup see the
## changes of this run and the next run starts clean. `--user-settings=user://<file>.cfg` (a persistence test, or a
## playtest that must apply the preferences) uses that file instead and turns the sandbox off.

const PATH := "user://settings.cfg"
const PATH_ARG := "--user-settings="

## Set when the file failed to load: it is not parsed again in this run (the engine logs each parse error).
static var _unreadable := false
static var _warned_write := false
## The sandbox's file (in memory).
static var _memory: ConfigFile


## True under AgentKit with no --user-settings: nothing touches the player's file.
static func sandboxed() -> bool:
	var under_agent := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(PATH_ARG):
			return false
		if arg.begins_with("--agent="):
			under_agent = true
	return under_agent


## The file of this run: --user-settings=… or PATH.
static func path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(PATH_ARG):
			return arg.substr(PATH_ARG.length())
	return PATH


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
			push_warning("UserSettings: %s no se pudo leer; los cambios valen en esta sesión y no se guardan, para no pisarlo." % path())
		return false
	for key in values:
		config.set_value(section, str(key), values[key])
	if sandboxed():
		return true
	var file := path()
	# Atomic: write a sibling file, then rename it over the real one (a crash never leaves half a file).
	var temp := file + ".tmp"
	var saved := config.save(temp)
	if saved == OK:
		saved = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(file))
	if saved != OK:
		push_error("UserSettings: no se pudo guardar %s (%s)." % [file, error_string(saved)])
		return false
	return true


## The file as it is (empty when it does not exist yet); null when it exists but cannot be read.
static func _load() -> ConfigFile:
	if sandboxed():
		if _memory == null:
			_memory = ConfigFile.new()
		return _memory
	if _unreadable:
		return null
	var config := ConfigFile.new()
	var loaded := config.load(path())
	if loaded == OK or loaded == ERR_FILE_NOT_FOUND:
		return config
	_unreadable = true
	push_warning("UserSettings: %s no se pudo leer (%s); se usan los valores por defecto y el archivo queda como está." % [path(), error_string(loaded)])
	return null
