extends "res://debug/audio/sound_refs_cases.gd"

## RFC-055 055o-c: every sound of the match is a typed reference, assigned in a scene or a type, never looked up by name.
## Both gates (it only loads resources; the dedicated server and the room server load all of it too):
## - match_typed: the five GodType carry `music` and `ambience` (with one-shots); advisor.tscn has 14 AdvisorLine with a
##   stream, the seven refusals and the eight warnings; match.tscn instances advisor.tscn, gives MusicDirector its
##   `default_music` and CommandVoice its Channel; boot.tscn gives MusicDirector the menu's `music`; RitualSounds and
##   SoulSounds carry their cues.
## - match_text_gone: scenes/ names no world.tres, advisor.tres, set_path, fallback_path nor one_shot_keys, and the files
##   of the two sets are gone.
## - match_streams: every cue of the advisor's lines has its streams.
## Inherits the helpers of sound_refs_cases (streams_report, _files, _instance); sound_refs_cases.run calls `run_match`.
## Prints `SOUND REFS match gods=<a>/<b> lines=<c> parity=<p>/<q>` (p of q advisor cues with all their streams).

const GODS_DIR := "res://data/gods/"
const ADVISOR_SCENE := "res://scenes/audio/advisor/advisor.tscn"
const MATCH_SCENE := "res://scenes/match/match.tscn"
const BOOT_SCENE := "res://scenes/core/boot.tscn"
const EXPECTED_GODS := 5
const EXPECTED_LINES := 14
const EXPECTED_REFUSALS := 7
const EXPECTED_WATCH := 8
const REMOVED_FILES: PackedStringArray = ["res://data/audio/world.tres", "res://data/audio/advisor.tres"]
const STALE_NEEDLES: PackedStringArray = ["data/audio/world", "data/audio/advisor.tres", "set_path", "fallback_path", "one_shot_keys",
	"one_shot_source", "lookup(\"world\""]


func run_match() -> Dictionary:
	var results := {}
	var counts := match_counts()
	results["match_typed"] = {"ok": int(counts["gods"]) == EXPECTED_GODS and int(counts["gods_typed"]) == EXPECTED_GODS \
		and int(counts["lines"]) == EXPECTED_LINES and int(counts["refusals"]) == EXPECTED_REFUSALS \
		and int(counts["watch"]) == EXPECTED_WATCH and bool(counts["advisor_instance"]) and bool(counts["command_channel"]) \
		and bool(counts["default_music"]) and bool(counts["boot_music"]) and bool(counts["sacrifice_cues"]), "counts": counts}
	var stale := stale_references()
	results["match_text_gone"] = {"ok": stale.is_empty(), "found": stale}
	var parity := streams_report(_advisor_cues())
	results["match_streams"] = {"ok": (parity["failures"] as PackedStringArray).is_empty(), "streams": parity}
	print("SOUND REFS match gods=%d/%d lines=%d parity=%d/%d" % [int(counts["gods_typed"]), int(counts["gods"]), int(counts["lines"]),
		int(parity["passed"]), int(parity["total"])])
	return results


## {gods, gods_typed, lines, refusals, watch, advisor_instance, command_channel, default_music, boot_music, sacrifice_cues}.
func match_counts() -> Dictionary:
	var counts := {"gods": 0, "gods_typed": 0, "lines": 0, "refusals": 0, "watch": 0, "advisor_instance": false,
		"command_channel": false, "default_music": false, "boot_music": false, "sacrifice_cues": false}
	var files := PackedStringArray()
	_files(GODS_DIR, ".tres", files)
	for path in files:
		var god := load(path) as GodType
		if god == null:
			continue
		counts["gods"] += 1
		if god.look != null and god.look.music != null and god.look.ambience != null and not AmbienceDirector.one_shot_cues(god.look.ambience).is_empty():
			counts["gods_typed"] += 1
	var voice := _instance(ADVISOR_SCENE) as AdvisorVoice
	if voice != null:
		var lines := advisor_lines(voice)
		counts["lines"] = lines.size()
		counts["refusals"] = voice.refusal_lines.size()
		counts["watch"] = _watch_lines(voice).size()
		voice.free()
	var match_scene := load(MATCH_SCENE) as PackedScene
	if match_scene != null:
		var advisor_node := _state_node(match_scene, "AdvisorVoice")
		counts["advisor_instance"] = advisor_node >= 0 and match_scene.get_state().get_node_instance(advisor_node) != null \
			and match_scene.get_state().get_node_instance(advisor_node).resource_path == ADVISOR_SCENE
		var channel := _state_node(match_scene, "CommandVoice/Channel")
		counts["command_channel"] = channel >= 0 and match_scene.get_state().get_node_type(channel) == &"AudioStreamPlayer"
		counts["default_music"] = _state_value(match_scene, "MusicDirector", "default_music") is MusicSet
	var boot_scene := load(BOOT_SCENE) as PackedScene
	counts["boot_music"] = boot_scene != null and _state_value(boot_scene, "MusicDirector", "music") is MusicSet
	counts["sacrifice_cues"] = _sacrifice_cues_ok()
	return counts


## Every AdvisorLine of `voice` by name: its refusals and the warnings of its AdvisorWatch child.
func advisor_lines(voice: AdvisorVoice) -> Dictionary:
	var found := {}
	for key: StringName in voice.refusal_lines:
		var line := voice.refusal_lines[key]
		if line != null and line.cue != null and not line.cue.is_silent():
			found[line.resource_name] = line
	var watch := _watch_lines(voice)
	for line_name: String in watch:
		var line: AdvisorLine = watch[line_name]
		if line.cue != null and not line.cue.is_silent():
			found[line_name] = line
	return found


## Lines of scenes/ (scripts and scenes) that still name what this cut removed.
func stale_references() -> PackedStringArray:
	var found := PackedStringArray()
	for path in REMOVED_FILES:
		if FileAccess.file_exists(path):
			found.append("%s todavía existe" % path)
	var files := PackedStringArray()
	_files("res://scenes", ".gd", files)
	_files("res://scenes", ".tscn", files)
	for path in files:
		var body := FileAccess.get_file_as_string(path)
		for needle in STALE_NEEDLES:
			if body.contains(needle):
				found.append("%s: %s" % [path, needle])
	return found


func _sacrifice_cues_ok() -> bool:
	var ritual := _instance("res://scenes/sacrifice/ritual.tscn")
	var soul := _instance("res://scenes/souls/soul.tscn")
	var ritual_sounds := ritual.get_node_or_null("RitualSounds") as RitualSounds if ritual != null else null
	var soul_sounds := soul.get_node_or_null("SoulSounds") as SoulSounds if soul != null else null
	var ok := ritual_sounds != null and soul_sounds != null and ritual_sounds.round_cue != null and ritual_sounds.finished_cue != null \
		and ritual_sounds.converted_cue != null and soul_sounds.collected_cue != null
	for node: Node in [ritual, soul]:
		if node != null:
			node.free()
	return ok


## The cue of every advisor line (refusals and warnings).
func _advisor_cues() -> Array[SoundCue]:
	var out: Array[SoundCue] = []
	var voice := _instance(ADVISOR_SCENE) as AdvisorVoice
	if voice == null:
		return out
	var lines := advisor_lines(voice)
	for line_name: String in lines:
		var line: AdvisorLine = lines[line_name]
		out.append(line.cue)
	voice.free()
	return out


## The AdvisorLine exports of the voice's AdvisorWatch child by property name.
func _watch_lines(voice: AdvisorVoice) -> Dictionary:
	var out := {}
	var watch := voice.get_node_or_null("AdvisorWatch") as AdvisorWatch
	if watch == null:
		return out
	for info: Dictionary in watch.get_property_list():
		if info.get("class_name") == &"AdvisorLine":
			var line := watch.get(info.name) as AdvisorLine
			if line != null:
				out[str(info.name)] = line
	return out


## Index of the node at `node_path` in `packed`'s state, or -1.
func _state_node(packed: PackedScene, node_path: String) -> int:
	var state := packed.get_state()
	for index in state.get_node_count():
		## A PackedScene state names the root's children "./Child".
		var path := String(state.get_node_path(index)).trim_prefix("./")
		if path == node_path:
			return index
	return -1


## The value `packed` sets on `prop` of the node at `node_path`, or null.
func _state_value(packed: PackedScene, node_path: String, prop: String) -> Variant:
	var index := _state_node(packed, node_path)
	if index < 0:
		return null
	var state := packed.get_state()
	for slot in state.get_node_property_count(index):
		if state.get_node_property_name(index, slot) == prop:
			return state.get_node_property_value(index, slot)
	return null
