class_name ArtPrefs
extends Resource

## «Arte»: the player's own values over the look, a local preference. `environment` holds
## Environment properties (fog, volumetric fog, SSAO, SSIL, glow, tonemap, color adjustment,
## ambient light) that EnvironmentLayer writes last, over the biome and the atmosphere; `flare`
## holds lens_flare.gdshader uniforms that LensFlareLayer writes over its own. Empty = the look as
## made.
## - The current values live in user://art/current.json; `save_as(name)` / `load_named(name)` keep
##   named sets in user://art/<name>.json. JSON on purpose: a .tres can carry a script, and a set
##   passed around between players must never run code. `export_environment` writes a whole
##   Environment .tres (the live one with these values) for the project.
## - Like GraphicsPrefs, every node shares the instance at SHARED_PATH; changes emit `changed`.
##   Sandboxed runs (UserSettings.sandboxed) read and write nothing.

const SHARED_PATH := "res://scenes/ui/art_prefs.tres"
const DIR := "user://art/"
const CURRENT := "current"

var environment := {}
var flare := {}
var _loaded := false


static func shared() -> ArtPrefs:
	return load(SHARED_PATH) as ArtPrefs


## The value the player set for `property` of `part` ("environment" or "flare"); null = as made.
func value_of(part: StringName, property: StringName) -> Variant:
	_ensure_loaded()
	return _part(part).get(String(property))


func set_value(part: StringName, property: StringName, value: Variant) -> void:
	_ensure_loaded()
	var values := _part(part)
	if values.get(String(property)) == value:
		return
	values[String(property)] = value
	_commit()


func clear_value(part: StringName, property: StringName) -> void:
	_ensure_loaded()
	if _part(part).erase(String(property)):
		_commit()


func clear_all() -> void:
	_ensure_loaded()
	if environment.is_empty() and flare.is_empty():
		return
	environment.clear()
	flare.clear()
	_commit()


func is_empty() -> bool:
	_ensure_loaded()
	return environment.is_empty() and flare.is_empty()


## Writes the player's environment values over `env`.
func apply_environment(env: Environment) -> void:
	_ensure_loaded()
	for property: String in environment:
		env.set(property, _typed(env.get(property), environment[property]))


## Writes the player's flare values over `material`.
func apply_flare(material: ShaderMaterial) -> void:
	_ensure_loaded()
	for property: String in flare:
		var current: Variant = material.get_shader_parameter(property)
		material.set_shader_parameter(property, _typed(current, flare[property]))


## The saved sets (names without extension), `current` left out.
func names() -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(DIR):
		return out
	for file in DirAccess.get_files_at(DIR):
		if file.ends_with(".json") and file.get_basename() != CURRENT:
			out.append(file.get_basename())
	out.sort()
	return out


func save_as(name: String) -> Error:
	var clean := _clean(name)
	if clean.is_empty() or clean == CURRENT:
		return ERR_INVALID_PARAMETER
	return _write(clean)


func load_named(name: String) -> Error:
	var data := _read(_clean(name))
	if data.is_empty():
		return ERR_FILE_CANT_READ
	environment = data["environment"]
	flare = data["flare"]
	_commit()
	return OK


## Saves `env` with the player's values as user://art/<name>_environment.tres; returns the path,
## or "" when it could not.
func export_environment(env: Environment, name: String) -> String:
	var clean := _clean(name)
	if env == null or clean.is_empty():
		return ""
	var copy := env.duplicate() as Environment
	apply_environment(copy)
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := DIR + clean + "_environment.tres"
	return path if ResourceSaver.save(copy, path) == OK else ""


func _part(part: StringName) -> Dictionary:
	return flare if part == &"flare" else environment


func _commit() -> void:
	if not UserSettings.sandboxed():
		_write(CURRENT)
	emit_changed()


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if Engine.is_editor_hint() or UserSettings.sandboxed():
		return
	var data := _read(CURRENT)
	if not data.is_empty():
		environment = data["environment"]
		flare = data["flare"]


func _write(name: String) -> Error:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(DIR + name + ".json", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(
		JSON.stringify({"environment": _encode(environment), "flare": _encode(flare)}, "\t")
	)
	return OK


## {environment, flare} of user://art/<name>.json, or {} when it is missing or not such a set.
## Only plain values come back: booleans, numbers and colors.
func _read(name: String) -> Dictionary:
	if name.is_empty() or not FileAccess.file_exists(DIR + name + ".json"):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + name + ".json"))
	if not parsed is Dictionary:
		return {}
	return {
		"environment": _decode(parsed.get("environment", {})),
		"flare": _decode(parsed.get("flare", {}))
	}


static func _encode(values: Dictionary) -> Dictionary:
	var out := {}
	for key: String in values:
		var value: Variant = values[key]
		out[key] = {"color": (value as Color).to_html()} if value is Color else value
	return out


static func _decode(values: Variant) -> Dictionary:
	var out := {}
	if not values is Dictionary:
		return out
	for key: Variant in values:
		var value: Variant = values[key]
		if value is Dictionary and value.has("color"):
			out[str(key)] = Color.html(str(value["color"]))
		elif value is bool or value is float or value is int:
			out[str(key)] = value
	return out


# JSON reads every number as a float: an int property gets an int back.
static func _typed(current: Variant, value: Variant) -> Variant:
	if current is int and (value is float or value is int):
		return roundi(value)
	if current is bool and not value is bool:
		return bool(value)
	return value


static func _clean(name: String) -> String:
	return name.strip_edges().validate_filename().replace(" ", "_")
