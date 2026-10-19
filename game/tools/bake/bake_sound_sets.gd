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
##   From your own sounds, assets/custom/sounds/<kind>/<tag>/<event>[_n].{ogg,wav}, into data/audio/custom/<kind>/<file>.tres
##   (searched first: yours win over the original's). Every file of one event is a variant of its cue; the event names are
##   SoundEvent.ALL (a file named otherwise is baked under its own key and noted). Needs nothing of the original. The writing
##   is tools/bake/sound_set_writer.gd (also used by tools/bake/new_creature.gd).
##
## The SSET type codes become SoundEvent names (SoundEvent.CREATURE_CODES, WORLD_CODES, UI_CODES; data/audio/README.md has the table).
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
const SoundSetWriter := preload("res://tools/bake/sound_set_writer.gd")

## SSET type -> SoundEvent: the tables live in SoundEvent (one owner; the game and the bake read the same names).
const _EVENTS := preload("res://scenes/audio/sound_event.gd")
const TYPE_EVENTS := _EVENTS.CREATURE_CODES
const WORLD_EVENTS := _EVENTS.WORLD_CODES
const UI_EVENTS := _EVENTS.UI_CODES

var _writer := SoundSetWriter.new()
var _failures: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_writer.force = args.has("--force")
	var only := _arg(args, "--only", "")
	if not _writer.is_ready():
		push_error("bake_sound_sets: SoundSet / SoundCue scripts missing")
		quit(1)
		return
	if only != "custom":
		_bake_original()
	if only != "original":
		var source := _arg(args, "--custom", SoundSetWriter.CUSTOM_SRC)
		if DirAccess.dir_exists_absolute(source):
			var from := _writer.written.size()
			_writer.bake_custom(source, _arg(args, "--out-custom", SoundSetWriter.CUSTOM_OUT))
			for i in range(from, _writer.written.size()):
				print("bake_sound_sets: wrote " + _writer.written[i])
		else:
			print("bake_sound_sets: no %s (no sounds of your own)" % source)
	for path in _writer.unknown:
		print("bake_sound_sets: note: %s is not an event the game plays (baked under its own name). Events: %s" % [path, SoundSetWriter.event_help()])
	print("bake_sound_sets: wrote %d files, kept %d existing%s" % [_writer.written.size(), _writer.kept.size(), "" if _writer.force else " (use -- --force to overwrite)"])
	_failures.append_array(Array(_writer.failures))
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
					melee[name] = _writer.save_set(_make_set(sets[name], TYPE_EVENTS), OUT_DIR + "melee/%s.tres" % _file_stem(name))
	for kind: String in users:
		var files := SoundSetWriter.catalog_files(kind)
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
			_writer.save_set(sound_set, OUT_DIR + "%s/%s.tres" % [kind, files.get(tag, _free_name(tag, taken))])
	_writer.save_set(_make_set(sets.get("spel", {}), WORLD_EVENTS), OUT_DIR + "world.tres")
	_writer.save_set(_make_set(sets.get("advi", {}), {}, &"Voice"), OUT_DIR + "advisor.tres")
	_writer.save_set(_make_set(sets.get("ifac", {}), UI_EVENTS), OUT_DIR + "ui.tres")


## A SoundSet from one SSET of the index ({type: [file under audio/]}).
func _make_set(types: Dictionary, events: Dictionary, bus: StringName = &"") -> Resource:
	var sound_set: Resource = _writer.new_set()
	var keys := types.keys()
	keys.sort()
	for code: String in keys:
		var files: Array = types[code]
		var key: StringName = events.get(code, StringName(code))
		if sound_set.cues.has(key):
			continue
		var cue: Resource = _writer.make_cue(files.map(func(rel: String) -> String: return AUDIO_ROOT + rel))
		cue.bus = bus if not bus.is_empty() else _bus_for(code, files)
		sound_set.cues[key] = cue
	return sound_set


## The original's voices go to Voice, its ambience (types A*, folder ambi) to Ambience, the rest to SFX.
static func _bus_for(code: String, files: Array) -> StringName:
	var first: String = files[0] if not files.is_empty() else ""
	if first.begins_with("voice/"):
		return &"Voice"
	if code.begins_with("A") or first.begins_with("sfx/ambi/"):
		return &"Ambience"
	return &"SFX"


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
