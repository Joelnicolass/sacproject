extends RefCounted

## No necesita el juego original. RFC-052 052b / 052i (F361, F368): writes SoundSet .tres files, one owner for both bakes.
## - tools/bake/bake_sound_sets.gd uses it for the original's sets (index.json) and for your own sounds.
## - tools/bake/new_creature.gd uses it for the sounds of the creature it makes (assets/custom/sounds/creatures/<tag>/).
## Your own sounds: assets/custom/sounds/<kind>/<tag>/<event>[_n].{ogg,wav} -> data/audio/custom/<kind>/<tag>.tres. Every
## file of one event is a variant of its cue (`death_1.wav`, `death_2.wav`). The event names are SoundEvent's (EVENT_HELP).
## Never over an existing .tres unless `force` (it throws away what you edited by hand).
## The streams are referenced by path and never loaded here: it works before the editor imports the audio.
## Preloaded by path (no class_name): the bakes run as `--script` before the class cache knows anything new.

const CUSTOM_SRC := "res://assets/custom/sounds/"
const CUSTOM_OUT := "res://data/audio/custom/"
const CATALOG_DIR := "res://data/catalog/"
const SET_SCRIPT := "res://scenes/audio/sound_set.gd"
const CUE_SCRIPT := "res://scenes/audio/sound_cue.gd"
const STREAM_EXTENSIONS := ["ogg", "wav", "mp3"]
const _EVENTS := preload("res://scenes/audio/sound_event.gd")
## Events a voice says; the rest of your sounds go to SFX.
const VOICE_EVENTS := [&"selected", &"ack", &"attack_ack", &"annoyed", &"incantation", &"advice"]
## Kinds whose set the game finds by the catalog file name (SoundLibrary.creature / wizard), not by the tag.
const CATALOG_KINDS := ["creatures", "wizards"]

var force := false
var written := PackedStringArray()
var kept := PackedStringArray()
var failures := PackedStringArray()
## File names whose event is not one the game emits (still baked: a set may hold keys of its own).
var unknown := PackedStringArray()
var _set_script: Script = load(SET_SCRIPT)
var _cue_script: Script = load(CUE_SCRIPT)
var _streams := {}
var _catalog := {}


func is_ready() -> bool:
	return _set_script != null and _cue_script != null


func new_set() -> Resource:
	return _set_script.new()


func make_cue(paths: Array) -> Resource:
	var cue: Resource = _cue_script.new()
	var streams: Array[AudioStream] = []
	for path: String in paths:
		streams.append(stream_ref(path))
	cue.streams = streams
	return cue


## A stream that only carries its path: saved as an ext_resource, never loaded here (the audio may not be imported yet).
## One object per path (a path holds one resource; several cues share a file).
func stream_ref(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var stream: AudioStream
	match path.get_extension().to_lower():
		"ogg":
			stream = AudioStreamOggVorbis.new()
		"mp3":
			stream = AudioStreamMP3.new()
		_:
			stream = AudioStreamWAV.new()
	stream.resource_path = path
	_streams[path] = stream
	return stream


## Saves `sound_set` at `path` unless it exists (then the existing one is returned, so a fallback keeps pointing at it).
func save_set(sound_set: Resource, path: String) -> Resource:
	if FileAccess.file_exists(path) and not force:
		kept.append(path)
		return load(path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var status := ResourceSaver.save(sound_set, path)
	if status != OK:
		failures.append("%s (error %d)" % [path, status])
		return null
	sound_set.take_over_path(path)
	written.append(path)
	return sound_set


## Every <kind>/<tag>/ folder under `source` -> `out`/<kind>/<file>.tres. Nothing when `source` does not exist.
func bake_custom(source: String = CUSTOM_SRC, out: String = CUSTOM_OUT) -> void:
	if not DirAccess.dir_exists_absolute(source):
		return
	for kind in DirAccess.get_directories_at(source):
		for tag in DirAccess.get_directories_at(source.path_join(kind)):
			bake_folder(kind, tag, source, out)


## One folder of your sounds, `source`/<kind>/<tag>/, -> `out`/<kind>/<file>.tres. Returns the path it wrote or kept ("" when
## the folder is missing or holds no sound file).
func bake_folder(kind: String, tag: String, source: String = CUSTOM_SRC, out: String = CUSTOM_OUT) -> String:
	var folder := source.path_join(kind).path_join(tag)
	if not DirAccess.dir_exists_absolute(folder):
		return ""
	var events := {}
	var files := Array(DirAccess.get_files_at(folder))
	files.sort()
	for file: String in files:
		if file.get_extension().to_lower() not in STREAM_EXTENSIONS:
			continue
		var event := event_of(file.get_basename())
		if event not in _EVENTS.ALL:
			unknown.append(folder.path_join(file))
		events[event] = events.get(event, []) + [folder.path_join(file)]
	if events.is_empty():
		return ""
	var sound_set := new_set()
	for event: StringName in events:
		var cue := make_cue(events[event])
		cue.bus = &"Voice" if event in VOICE_EVENTS else &"SFX"
		sound_set.cues[event] = cue
	var path := out.path_join(kind).path_join(file_for(kind, tag) + ".tres")
	return path if save_set(sound_set, path) != null else ""


## The file name of `tag`'s set: for a creature or a wizard, the name of its .tres in data/catalog/ (EHTH -> EHTH_2), as
## SoundLibrary looks it up; else (or when the catalog has no such tag) the tag.
func file_for(kind: String, tag: String) -> String:
	if kind not in CATALOG_KINDS:
		return tag
	if not _catalog.has(kind):
		_catalog[kind] = catalog_files(kind)
	return _catalog[kind].get(tag, tag)


## "death_2" -> &"death", "swing" -> &"swing".
static func event_of(stem: String) -> StringName:
	var cut := stem.rfind("_")
	if cut > 0 and stem.substr(cut + 1).is_valid_int():
		return StringName(stem.substr(0, cut))
	return StringName(stem)


## {tag: file stem} of data/catalog/<kind>/*.tres (read as text: only the `tag = "..."` line).
static func catalog_files(kind: String) -> Dictionary:
	var out := {}
	var dir := CATALOG_DIR + kind + "/"
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() != "tres":
			continue
		for line in FileAccess.get_file_as_string(dir + file).split("\n"):
			if line.begins_with("tag = \""):
				out[line.trim_prefix("tag = \"").trim_suffix("\"")] = file.get_basename()
				break
	return out


## The event names a file of yours may start with (for the notes of the bakes).
static func event_help() -> String:
	return ", ".join(_EVENTS.ALL)
