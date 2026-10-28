extends RefCounted

## Does not need the original game. Writes the SoundSet of a creature of your own (the one tools/bake/new_creature.gd makes).
## Your own sounds: assets/custom/sounds/creatures/<name>/<event>[_n].{ogg,wav} -> data/audio/creatures/<name>.tres. Every file of
## one event is a variant of its cue (`death_1.wav`, `death_2.wav`); the event names are SoundEvent.BODY (EVENT_HELP) and each one
## is a field of the SoundSet. A `swing` with no `shoot` of its own also sounds when the creature shoots (the same cue).
## The set has the melee set `data/audio/melee/fist.tres` as `fallback`, so a creature with only a death still swings.
## With no sound files it writes the set empty (the fallback only): drag the files onto its fields in the inspector.
## Never over an existing .tres unless `force` (it throws away what you edited by hand).
## The streams are referenced by path and never loaded here: it works before the editor imports the audio.
## Preloaded by path (no class_name): the tool runs as `--script` before the class cache knows anything new.

const CUSTOM_SRC := "res://assets/custom/sounds/"
const CUSTOM_OUT := "res://data/audio/"
const SET_SCRIPT := "res://scenes/audio/sound_set.gd"
const CUE_SCRIPT := "res://scenes/audio/sound_cue.gd"
const MELEE_FALLBACK := "res://data/audio/melee/fist.tres"
const STREAM_EXTENSIONS := ["ogg", "wav", "mp3"]
const _EVENTS := preload("res://scenes/audio/sound_event.gd")
## Events a voice says; the rest of your sounds go to SFX.
const VOICE_EVENTS := [&"selected", &"ack", &"attack_ack", &"annoyed", &"incantation"]

var force := false
var written := PackedStringArray()
var kept := PackedStringArray()
var failures := PackedStringArray()
## File names whose event is not a field of the set (skipped: drag it by hand if it has a place).
var unknown := PackedStringArray()
var _set_script: Script = load(SET_SCRIPT)
var _cue_script: Script = load(CUE_SCRIPT)
var _streams := {}


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


## The set of the creature `name`: the sound files of `source`/creatures/<name>/ as fields (none: an empty set over the melee
## fallback) -> `out`/creatures/<name>.tres. Returns the path it wrote or kept ("" when it could not be saved).
func write_creature_set(
	name: String, source: String = CUSTOM_SRC, out: String = CUSTOM_OUT
) -> String:
	var events := _events_in(source.path_join("creatures").path_join(name))
	var sound_set := new_set()
	for event: StringName in events:
		var cue := make_cue(events[event])
		cue.bus = &"Voice" if event in VOICE_EVENTS else &"SFX"
		sound_set.set(event, cue)
	if events.has(&"swing") and not events.has(&"shoot"):
		sound_set.set(&"shoot", sound_set.get(&"swing"))
	if ResourceLoader.exists(MELEE_FALLBACK):
		sound_set.set(&"fallback", load(MELEE_FALLBACK))
	var path := out.path_join("creatures").path_join(name + ".tres")
	return path if save_set(sound_set, path) != null else ""


## {event: [res paths]} of the sound files in `folder` (empty when it does not exist). An event that is not a field goes to `unknown`.
func _events_in(folder: String) -> Dictionary:
	var events := {}
	if not DirAccess.dir_exists_absolute(folder):
		return events
	var files := Array(DirAccess.get_files_at(folder))
	files.sort()
	for file: String in files:
		if file.get_extension().to_lower() not in STREAM_EXTENSIONS:
			continue
		var event := event_of(file.get_basename())
		if event not in _EVENTS.BODY:
			unknown.append(folder.path_join(file))
			continue
		events[event] = events.get(event, []) + [folder.path_join(file)]
	return events


## True when `source`/creatures/<name>/ holds a sound file.
static func has_sounds(name: String, source: String = CUSTOM_SRC) -> bool:
	var folder := source.path_join("creatures").path_join(name)
	if not DirAccess.dir_exists_absolute(folder):
		return false
	for file in DirAccess.get_files_at(folder):
		if file.get_extension().to_lower() in STREAM_EXTENSIONS:
			return true
	return false


## "death_2" -> &"death", "swing" -> &"swing".
static func event_of(stem: String) -> StringName:
	var cut := stem.rfind("_")
	if cut > 0 and stem.substr(cut + 1).is_valid_int():
		return StringName(stem.substr(0, cut))
	return StringName(stem)


## The event names a file of yours may start with (for the notes of the tool).
static func event_help() -> String:
	return ", ".join(_EVENTS.BODY)
