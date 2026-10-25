extends "res://debug/audio/sound_refs_cases.gd"

## RFC-055 055o-c: every sound of the match is a typed reference, assigned in a scene or a type, never looked up by name.
## Both gates (it only loads resources; the dedicated server and the room server load all of it too):
## - match_typed: the five GodType carry `music` and `ambience` (with one-shots); advisor.tscn has 14 AdvisorLine with a
##   stream, the seven refusals and the eight warnings; match.tscn instances advisor.tscn, gives MusicDirector its
##   `default_music` and CommandVoice its Channel; boot.tscn gives MusicDirector the menu's `music`; RitualSounds and
##   SoulSounds carry their cues.
## - match_text_gone: scenes/ names no world.tres, advisor.tres, set_path, fallback_path nor one_shot_keys, and the files
##   of the two sets are gone.
## - match_parity: when tools/migrate/055o_match_parity.json is there (the one-shot migration's snapshot of how the music,
##   the ambience, the advisor and the sacrifice sounded before), the typed data gives the same streams and numbers. The file
##   goes with the migration.
## Inherits the helpers of sound_refs_cases (cue_problem, _files, _instance); sound_refs_cases.run calls `run_match`.
## Prints `SOUND REFS match gods=<a>/<b> lines=<c> parity=<p>/<q>`.

const GODS_DIR := "res://data/gods/"
const ADVISOR_SCENE := "res://scenes/audio/advisor/advisor.tscn"
const MATCH_SCENE := "res://scenes/match/match.tscn"
const BOOT_SCENE := "res://scenes/core/boot.tscn"
const MATCH_PARITY_JSON := "res://tools/migrate/055o_match_parity.json"
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
	var parity := parity_report(MATCH_PARITY_JSON)
	results["match_parity"] = {"ok": (parity["failures"] as PackedStringArray).is_empty(), "parity": parity}
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
		if god.music != null and god.ambience != null and not AmbienceDirector.one_shot_cues(god.ambience).is_empty():
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


## Compares the snapshot of how the match sounded before the migration with the typed data: {total, passed, failures}.
## No snapshot file (the migration is over): total 0.
func parity_report(json_path: String) -> Dictionary:
	var report := {"total": 0, "passed": 0, "failures": PackedStringArray()}
	if not FileAccess.file_exists(json_path):
		return report
	var snapshot: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not snapshot is Dictionary:
		(report["failures"] as PackedStringArray).append("%s no es un JSON válido" % json_path)
		return report
	var data: Dictionary = snapshot
	var cues: Dictionary = data.get("cues", {})
	for item: Dictionary in data.get("gods", []):
		_check(report, "dios %s" % item.get("tag", ""), _god_problem(item, cues))
	var voice := _instance(ADVISOR_SCENE) as AdvisorVoice
	var advisor: Dictionary = data.get("advisor", {})
	var lines := advisor_lines(voice) if voice != null else {}
	for item: Dictionary in advisor.get("lines", []):
		_check(report, "consejero %s" % item.get("name", ""), _line_problem(lines.get(item.get("name", "")), item, cues))
	var refusals: Dictionary = advisor.get("refusals", {})
	for key: String in refusals:
		var line := voice.line_for_refusal(StringName(key)) if voice != null else null
		_check(report, "rechazo %s" % key, "" if line != null and line.resource_name == str(refusals[key]) else "no apunta a %s" % refusals[key])
	var watch := _watch_lines(voice) if voice != null else {}
	for line_name: String in advisor.get("watch", []):
		var line := watch.get(line_name) as AdvisorLine
		_check(report, "aviso %s" % line_name, "" if line != null and line.resource_name == line_name else "no tiene la línea")
	if voice != null:
		voice.free()
	for item: Dictionary in data.get("sacrifice", []):
		_check(report, "%s %s" % [item.get("node", ""), item.get("prop", "")], _sacrifice_problem(item, cues))
	var directors: Dictionary = data.get("directors", {})
	var match_scene := load(MATCH_SCENE) as PackedScene
	var default_music: Variant = _state_value(match_scene, "MusicDirector", "default_music") if match_scene != null else null
	_check(report, "default_music", _path_problem(default_music, str(directors.get("match_default_music", ""))))
	var boot_scene := load(BOOT_SCENE) as PackedScene
	var boot_music: Variant = _state_value(boot_scene, "MusicDirector", "music") if boot_scene != null else null
	_check(report, "música del menú", _path_problem(boot_music, str(directors.get("boot_music", ""))))
	return report


func _check(report: Dictionary, label: String, problem: String) -> void:
	report["total"] += 1
	if problem.is_empty():
		report["passed"] += 1
	else:
		(report["failures"] as PackedStringArray).append("%s: %s" % [label, problem])


## "" when the god points at the music and ambience files it used to play and its one-shots are the same cues.
func _god_problem(item: Dictionary, cues: Dictionary) -> String:
	var god := load("res://" + str(item.get("path", ""))) as GodType
	if god == null:
		return "no carga"
	var problem := _path_problem(god.music, str(item.get("music", "")))
	if problem.is_empty():
		problem = _path_problem(god.ambience, str(item.get("ambience", "")))
	if not problem.is_empty():
		return problem
	var bed: Variant = item.get("bed")
	if bed != null:
		if god.ambience.bed == null:
			return "perdió el fondo"
		problem = cue_problem(god.ambience.bed, cues.get(str(bed), {}))
		if not problem.is_empty():
			return "fondo: " + problem
	var shots := AmbienceDirector.one_shot_cues(god.ambience)
	var wanted: Array = item.get("one_shots", [])
	if shots.size() != wanted.size():
		return "%d sueltos y eran %d" % [shots.size(), wanted.size()]
	for index in shots.size():
		problem = cue_problem(shots[index], cues.get(str(wanted[index]), {}))
		if not problem.is_empty():
			return "suelto %d: %s" % [index, problem]
	return ""


## "" when the advisor line has the cue, priority and quiet time the old table gave its code.
func _line_problem(line: AdvisorLine, item: Dictionary, cues: Dictionary) -> String:
	if line == null:
		return "no existe"
	var problem := cue_problem(line.cue, cues.get(str(item.get("cue", "")), {}))
	if not problem.is_empty():
		return problem
	if int(line.priority) != int(item.get("priority", -1)):
		return "prioridad %d y era %d" % [line.priority, int(item.get("priority", -1))]
	if not is_equal_approx(line.quiet_s, float(item.get("quiet_s", -1.0))):
		return "silencio %s y era %s" % [line.quiet_s, item.get("quiet_s")]
	return ""


## "" when RitualSounds / SoulSounds carry the cue file with the streams the world set gave that event.
func _sacrifice_problem(item: Dictionary, cues: Dictionary) -> String:
	var node := _instance("res://" + str(item.get("scene", "")))
	var sounds := node.get_node_or_null(NodePath(str(item.get("node", "")))) if node != null else null
	var cue := sounds.get(str(item.get("prop", ""))) as SoundCue if sounds != null else null
	var problem := "sin cue"
	if cue != null:
		problem = cue_problem(cue, cues.get(str(item.get("cue", "")), {}))
		if problem.is_empty() and cue.resource_path != "res://" + str(item.get("file", "")):
			problem = "cue %s y era %s" % [cue.resource_path, item.get("file")]
	if node != null:
		node.free()
	return problem


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


## "" when `resource` is the file `wanted` (a path without res://).
func _path_problem(resource: Variant, wanted: String) -> String:
	if not resource is Resource:
		return "sin recurso"
	var path: String = (resource as Resource).resource_path
	return "" if path == "res://" + wanted else "%s y era %s" % [path, wanted]


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
