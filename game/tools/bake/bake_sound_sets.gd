extends SceneTree

## No necesita el juego original: lee assets/original/audio/index.json (lo escribe tools/import/import_audio.py) y
## assets/custom/sounds/. RFC-052 052b / 052i (F361, F368): writes the SoundSets the game finds by convention (SoundLibrary).
##
##   From the original's import (index.json), into data/audio/:
##     creatures/<file>.tres   a creature's voice set (CRE8 creatureSSET); `fallback` = melee/<set>.tres (CRE8 meleeSSET)
##     wizards/<file>.tres     a wizard's set (WIZD wizardSSET); `fallback` = melee/<set>.tres (WIZD meleeSSET1)
##     melee/<set>.tres        the shared melee sets (fist, bsaw, stab...): swing, hit and death sounds
##     world.tres              the `spel` set (sacrifice, gibs, souls, summon, spell and ambience sounds)
##     advisor.tres            the `advi` set (the advisor's warnings: dese, lowm, watt...)
##     ui.tres                 the `ifac` set (menu clicks, back, X menu, level up)
##   <file> is the name of the creature's (wizard's) .tres in data/catalog/ (EHTH -> EHTH_2: macOS sees EHTH and ehtH as one
##   file), or the tag when the catalog has none.
##   From your own sounds, assets/custom/sounds/<kind>/<tag>/<event>[_n].{ogg,wav,mp3}, into data/audio/custom/<kind>/<tag>.tres
##   (searched first: yours win over the original's). Every file of one event is a variant of its cue.
##
## The SSET type codes become SoundEvent names (TYPE_EVENTS, WORLD_EVENTS, UI_EVENTS; data/audio/README.md has the table).
## A code without an event keeps its code as the key (`Xcat`, `TNT1`, `grp3`, `Awnd`...): later cuts map them.
## Human edits are safe: an existing .tres is left alone; `--force` rewrites (and throws away what you edited).
## The streams are referenced by path and not loaded: the bake works before the editor imports the audio.
##
##   "$GODOT" --headless --path . --script res://tools/bake/bake_sound_sets.gd [-- --force] [--only=original|custom]
##       [--custom=res://dir/] [--out-custom=res://dir/]   (another source / target for your sounds, e.g. a fixture)
## Then import the project (the editor does it by itself) so it knows the new files.

const INDEX := "res://assets/original/audio/index.json"
const AUDIO_ROOT := "res://assets/original/audio/"
const OUT_DIR := "res://data/audio/"
const CUSTOM_SRC := "res://assets/custom/sounds/"
const CUSTOM_OUT := "res://data/audio/custom/"
const CATALOG_DIR := "res://data/catalog/"
const SET_SCRIPT := "res://scenes/audio/sound_set.gd"
const CUE_SCRIPT := "res://scenes/audio/sound_cue.gd"
const NO_SET := ["", "cre8"]
const STREAM_EXTENSIONS := ["ogg", "wav", "mp3"]

## Creature, wizard and melee sets: SSET type -> SoundEvent.
const TYPE_EVENTS := {
	"Xcnt": &"selected",   # clicked / selected
	"Xcnf": &"ack",        # order acknowledged (move)
	"Xatt": &"swing",      # melee swing (the melee set)
	"Xdam": &"damaged",
	"Xdie": &"death",
	"Xinc": &"incantation",
}
## The `spel` set.
const WORLD_EVENTS := {
	"Xsac": &"sacrifice_round",
	"Xgib": &"sacrifice_end",
	"spir": &"soul",
	"SUMN": &"summon",
}
## The `ifac` set.
const UI_EVENTS := {
	"clik": &"click",
}
## Events a voice says; the rest of a custom creature's sounds go to SFX.
const VOICE_EVENTS := [&"selected", &"ack", &"incantation", &"advice"]

var _force := false
var _written := 0
var _kept := 0
var _failures: Array[String] = []
var _set_script: Script
var _cue_script: Script
var _streams := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_force = args.has("--force")
	var only := _arg(args, "--only", "")
	_set_script = load(SET_SCRIPT)
	_cue_script = load(CUE_SCRIPT)
	if _set_script == null or _cue_script == null:
		push_error("bake_sound_sets: SoundSet / SoundCue scripts missing")
		quit(1)
		return
	if only != "custom":
		_bake_original()
	if only != "original":
		_bake_custom(_arg(args, "--custom", CUSTOM_SRC), _arg(args, "--out-custom", CUSTOM_OUT))
	print("bake_sound_sets: wrote %d files, kept %d existing%s" % [_written, _kept, "" if _force else " (use -- --force to overwrite)"])
	for failure in _failures:
		push_error("bake_sound_sets: could not save " + failure)
	print("bake_sound_sets: %s" % ("FAIL" if not _failures.is_empty() else "done"))
	quit(1 if not _failures.is_empty() else 0)


func _bake_original() -> void:
	if not FileAccess.file_exists(INDEX):
		print("bake_sound_sets: no %s (the original's audio is not imported: tools/import/import_audio.py); original sets skipped" % INDEX)
		return
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
	if not index is Dictionary:
		_failures.append(INDEX + " (not JSON)")
		return
	var sets: Dictionary = index.get("sets", {})
	var melee := {}   # set name -> saved SoundSet
	var users := {"creatures": index.get("creatures", {}), "wizards": index.get("wizards", {})}
	for kind: String in users:
		for tag: String in users[kind]:
			var names: Array = users[kind][tag]
			for i in range(1, names.size()):
				var name: String = names[i]
				if not melee.has(name) and sets.has(name):
					melee[name] = _save_set(_make_set(sets[name], TYPE_EVENTS), OUT_DIR + "melee/%s.tres" % _file_stem(name))
	for kind: String in users:
		var files := _catalog_files(kind)
		var taken := {}
		for file: String in files.values():
			taken[file.to_lower()] = true
		for tag: String in users[kind]:
			var names: Array = users[kind][tag]
			if names.is_empty():
				continue
			var own: Dictionary = sets.get(names[0], {})
			var sound_set := _make_set(own, TYPE_EVENTS)
			if names.size() > 1:
				sound_set.fallback = melee.get(names[1])
			if sound_set.cues.is_empty() and sound_set.fallback == null:
				continue
			_save_set(sound_set, OUT_DIR + "%s/%s.tres" % [kind, files.get(tag, _free_name(tag, taken))])
	_save_set(_make_set(sets.get("spel", {}), WORLD_EVENTS), OUT_DIR + "world.tres")
	_save_set(_make_set(sets.get("advi", {}), {}, &"Voice"), OUT_DIR + "advisor.tres")
	_save_set(_make_set(sets.get("ifac", {}), UI_EVENTS), OUT_DIR + "ui.tres")


## A SoundSet from one SSET of the index ({type: [file under audio/]}).
func _make_set(types: Dictionary, events: Dictionary, bus: StringName = &"") -> Resource:
	var sound_set: Resource = _set_script.new()
	var keys := types.keys()
	keys.sort()
	for code: String in keys:
		var files: Array = types[code]
		var key: StringName = events.get(code, StringName(code))
		if sound_set.cues.has(key):
			continue
		var cue := _make_cue(files.map(func(rel: String) -> String: return AUDIO_ROOT + rel))
		cue.bus = bus if not bus.is_empty() else _bus_for(code, files)
		sound_set.cues[key] = cue
	return sound_set


func _make_cue(paths: Array) -> Resource:
	var cue: Resource = _cue_script.new()
	var streams: Array[AudioStream] = []
	for path: String in paths:
		streams.append(_stream_ref(path))
	cue.streams = streams
	return cue


## The original's voices go to Voice, its ambience (types A*, folder ambi) to Ambience, the rest to SFX.
static func _bus_for(code: String, files: Array) -> StringName:
	var first: String = files[0] if not files.is_empty() else ""
	if first.begins_with("voice/"):
		return &"Voice"
	if code.begins_with("A") or first.begins_with("sfx/ambi/"):
		return &"Ambience"
	return &"SFX"


## A stream that only carries its path: saved as an ext_resource, never loaded here (the audio may not be imported yet).
## One object per path (a path holds one resource; several cues share a file).
func _stream_ref(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var stream: AudioStream
	match path.get_extension():
		"ogg":
			stream = AudioStreamOggVorbis.new()
		"mp3":
			stream = AudioStreamMP3.new()
		_:
			stream = AudioStreamWAV.new()
	stream.resource_path = path
	_streams[path] = stream
	return stream


func _bake_custom(source: String, out: String) -> void:
	if not DirAccess.dir_exists_absolute(source):
		print("bake_sound_sets: no %s (no sounds of your own)" % source)
		return
	for kind in DirAccess.get_directories_at(source):
		for tag in DirAccess.get_directories_at(source.path_join(kind)):
			var folder := source.path_join(kind).path_join(tag)
			var events := {}
			var files := Array(DirAccess.get_files_at(folder))
			files.sort()
			for file: String in files:
				if file.get_extension().to_lower() not in STREAM_EXTENSIONS:
					continue
				var event := _event_of(file.get_basename())
				events[event] = events.get(event, []) + [folder.path_join(file)]
			if events.is_empty():
				continue
			var sound_set: Resource = _set_script.new()
			for event: StringName in events:
				var cue := _make_cue(events[event])
				cue.bus = &"Voice" if event in VOICE_EVENTS else &"SFX"
				sound_set.cues[event] = cue
			_save_set(sound_set, out.path_join(kind).path_join(tag + ".tres"))


## "death_2" -> &"death", "swing" -> &"swing".
static func _event_of(stem: String) -> StringName:
	var cut := stem.rfind("_")
	if cut > 0 and stem.substr(cut + 1).is_valid_int():
		return StringName(stem.substr(0, cut))
	return StringName(stem)


## Saves `sound_set` at `path` unless it exists (then the existing one is returned, so a fallback keeps pointing at it).
func _save_set(sound_set: Resource, path: String) -> Resource:
	if FileAccess.file_exists(path) and not _force:
		_kept += 1
		return load(path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var status := ResourceSaver.save(sound_set, path)
	if status != OK:
		_failures.append("%s (error %d)" % [path, status])
		return null
	sound_set.take_over_path(path)
	_written += 1
	return sound_set


## {tag: file stem} of data/catalog/<kind>/*.tres (read as text: only the `tag = "..."` line).
static func _catalog_files(kind: String) -> Dictionary:
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


## A file name for a tag the catalog has not got; a case-insensitive repeat gets _2, _3...
static func _free_name(tag: String, taken: Dictionary) -> String:
	var name := tag.validate_filename()
	var n := 1
	while taken.has(name.to_lower()):
		n += 1
		name = "%s_%d" % [tag.validate_filename(), n]
	taken[name.to_lower()] = true
	return name


## A set name as a file (capitals as _ + lower case, the rule of OriginalAssets.icon_file): "Hfae" -> "_hfae".
static func _file_stem(name: String) -> String:
	var out := ""
	for i in name.length():
		var letter := name[i]
		out += "_" + letter.to_lower() if letter != letter.to_lower() else letter
	return out


static func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	for arg in args:
		if arg.begins_with(key + "="):
			return arg.substr(key.length() + 1)
	return fallback
