class_name FxWire
extends RefCounted

## The one place where text and effects meet, for the wire only: the network id of an effect is the path of its resource, and this
## turns it back into the resource on the receiving peer (loaded once, then cached). Gameplay never names an effect with text: it holds
## the ParticleType, BeamType or PackedScene in an `@export`.
## What it does not do: play anything (FxBus), pool anything (BurstPool, BeamPool), or decide who may see an effect.

## Where the pools and the gallery find every type to warm up (folders, not names).
const PARTICLES_DIR := "res://data/fx/"
const BEAMS_DIR := "res://data/fx/beams/"

## id (resource path) -> loaded effect, or null when the path is not an effect. Never cleared: the effects are few and small.
static var _by_id: Dictionary[String, Resource] = {}
static var _warned: Dictionary[String, bool] = {}
## How many ids did not turn into an effect since the process started (the net probe reads it; 0 is healthy).
static var unresolved := 0


## The id an effect travels as: its resource path. "" (and an error) for an effect saved inside another resource.
static func id_of(fx: Resource) -> String:
	if fx == null:
		return ""
	var path: String = fx.resource_path
	if path.is_empty() or path.contains("::"):
		push_error("FxWire: %s is embedded and has no id; save it as its own file." % fx)
		return ""
	return path


## The effect with this id: a ParticleType, a BeamType or a PackedScene under res://. Null for anything else.
static func resource(id: String) -> Resource:
	if not id.begins_with("res://"):
		return null
	if not _by_id.has(id):
		var found: Resource = load(id) if ResourceLoader.exists(id) else null
		var is_fx: bool = found is ParticleType or found is BeamType or found is PackedScene
		_by_id[id] = found if is_fx else null
		if not is_fx:
			_warn_once("FxWire: no effect with id %s" % id)
	if _by_id[id] == null:
		unresolved += 1
	return _by_id[id]


## A short name for logs and test checks: the file name without folder or extension.
static func label_of(fx: Resource) -> String:
	if fx == null:
		return ""
	return (
		fx.resource_path.get_file().get_basename()
		if not fx.resource_path.is_empty()
		else "embedded"
	)


## Every resource file under `dir` and its folders (the pools warm up from this).
static func all_in(dir: String) -> Array[Resource]:
	var found: Array[Resource] = []
	for file: String in DirAccess.get_files_at(dir):
		var file_name: String = file.trim_suffix(".remap")
		if file_name.ends_with(".tres"):
			var loaded: Resource = load(dir + file_name) as Resource
			if loaded != null:
				found.append(loaded)
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(all_in(dir + sub + "/"))
	return found


static func _warn_once(text: String) -> void:
	if not _warned.has(text):
		_warned[text] = true
		push_warning(text)
