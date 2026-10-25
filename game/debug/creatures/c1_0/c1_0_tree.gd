extends SceneTree

## c1-0 probe, step 3 (disposable): does an AnimationTree with one state per role fire the method tracks that live INSIDE each
## Animation of a library loaded from .res files, at the frame the dictionaries give today? (questions 3 and 12)
## For each library of c1_0_build.gd it assembles the new model shape: Model (the .glb), Clips (AnimationPlayer, root_node ../Model,
## the library), ClipEvents (a sink) and Tree (AnimationTree, root_node ../Model, anim_player ../Clips, a state per role, xfade 0.15
## like today). It steps the Tree by hand (1/120 s) and records at which position of the state each method call arrives.
## Three variants of the state: `plain` (no custom timeline, the library's own length and loop: the plan), `timeline` (the custom
## timeline of today) and `oneshot_none` (plain, with the one-shot roles' Animation set to LOOP_NONE: does AT_END need it?).
## "$GODOT" --headless --path game --script res://debug/creatures/c1_0/c1_0_tree.gd
## Prints C1_0 markers ok=n/m (plain, direct start), one C1_0 markers variant=... line each, C1_0 roundtrip ..., C1_0 VERDICT events_in_library=...

const Common := preload("res://debug/creatures/c1_0/c1_0_common.gd")
const Sink := preload("res://debug/creatures/c1_0/c1_0_sink.gd")
const DT := 1.0 / 120.0
const FADE_S := 0.15
const EPS := 0.0001
const VARIANTS: PackedStringArray = ["plain", "timeline", "oneshot_none"]
## The analysis stops (and says PARTIAL) after this, before the 120 s watchdog.
const BUDGET_MS := 90000
const MAX_STEPS := 2400
const MAX_MISS_LINES := 8

var _started_ms := 0
var _partial := false
var _miss_lines := 0


func _initialize() -> void:
	Common.arm_watchdog(self)
	_started_ms = Time.get_ticks_msec()
	_main()


func _main() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Common.MANIFEST))
	if not parsed is Dictionary:
		Common.fail(self, "no manifest: run c1_0_build.gd first")
		return
	var libs: Array = (parsed as Dictionary)["libs"]
	var ticks := Common.creature_ticks()
	var tallies: Dictionary = {}
	for variant: String in VARIANTS:
		tallies[variant] = {"m_ok": 0, "m_total": 0, "d_ok": 0, "d_total": 0, "t_ok": 0, "t_total": 0, "end_ok": 0, "end_total": 0}
	var round_tally := {"marker_ok": 0, "marker_total": 0, "length_ok": 0, "length_total": 0}
	for path: String in libs:
		var model := path.get_file().trim_suffix("_clips.tres")
		var library := ResourceLoader.load(path) as AnimationLibrary
		var glb := load(Common.GLB_DIR + model + ".glb") as PackedScene
		if library == null or glb == null:
			Common.fail(self, "cannot load the library or the .glb of " + model)
			return
		_check_roundtrip(model, library, ticks.get(model, {}), round_tally)
		for variant: String in VARIANTS:
			if variant == "oneshot_none":
				_set_one_shots_to_none(library)
			var done: bool = await _run_variant(model, library, glb, variant, ticks.get(model, {}), tallies[variant])
			if not done:
				return
	_report(tallies, round_tally)
	quit(0)


func _report(tallies: Dictionary, round_tally: Dictionary) -> void:
	for variant: String in VARIANTS:
		var t: Dictionary = tallies[variant]
		print("C1_0 markers variant=%s ok=%d/%d methods=%d/%d travel=%d/%d at_end=%d/%d"
			% [variant, t["m_ok"], t["m_total"], t["d_ok"], t["d_total"], t["t_ok"], t["t_total"], t["end_ok"], t["end_total"]])
	var plain: Dictionary = tallies["plain"]
	print("C1_0 markers ok=%d/%d" % [plain["m_ok"], plain["m_total"]])
	print("C1_0 roundtrip markers=%d/%d length_is_whole_frames=%d/%d" % [round_tally["marker_ok"], round_tally["marker_total"],
		round_tally["length_ok"], round_tally["length_total"]])
	var fires: bool = plain["m_total"] > 0 and plain["m_ok"] == plain["m_total"] and plain["d_ok"] == plain["d_total"] \
		and plain["t_ok"] == plain["t_total"]
	var verdict := "NO DATA" if plain["m_total"] == 0 and plain["d_total"] == 0 else ("YES" if fires else "NO")
	print("C1_0 VERDICT events_in_library=%s%s (plain: markers %d/%d, methods %d/%d, with xfade %d/%d)" % [verdict,
		" PARTIAL" if _partial else "", plain["m_ok"], plain["m_total"], plain["d_ok"], plain["d_total"], plain["t_ok"], plain["t_total"]])


## One-shot roles must end by themselves (AT_END) with no custom timeline: this variant checks if the Animation needs LOOP_NONE.
func _set_one_shots_to_none(library: AnimationLibrary) -> void:
	for role: String in Common.ONE_SHOT_ROLES:
		if library.has_animation(StringName(role)):
			library.get_animation(StringName(role)).loop_mode = Animation.LOOP_NONE


## Markers of the loaded Animations against the dictionaries' ticks (hit/shoot at the same frame) and whole-frame lengths.
func _check_roundtrip(model: String, library: AnimationLibrary, model_ticks: Dictionary, tally: Dictionary) -> void:
	var seen: Dictionary = {}
	for role in library.get_animation_list():
		var anim := library.get_animation(StringName(role))
		if seen.has(anim):
			continue
		seen[anim] = true
		var fps := 1.0 / anim.step if anim.step > 0.0 else 30.0
		tally["length_total"] += 1
		if absf(anim.length * fps - roundf(anim.length * fps)) < 0.001:
			tally["length_ok"] += 1
		var info: Dictionary = model_ticks.get(anim.resource_path.get_file().get_basename(), {})
		for field: String in ["hits", "shoots"]:
			var frames: Array = info.get(field, [])
			for i in frames.size():
				var base := "hit" if field == "hits" else "shoot"
				var marker := StringName(base if i == 0 else "%s%d" % [base, i + 1])
				tally["marker_total"] += 1
				if anim.has_marker(marker) and roundi(anim.get_marker_time(marker) * fps) == int(frames[i]):
					tally["marker_ok"] += 1
				else:
					print("C1_0 miss roundtrip model=%s clip=%s marker=%s" % [model, anim.resource_path.get_file(), marker])


## Assembles the rig, steps the Tree by hand and fills `tally`. Returns false when the probe failed (already reported).
func _run_variant(model: String, library: AnimationLibrary, glb: PackedScene, variant: String, model_ticks: Dictionary, tally: Dictionary) -> bool:
	var machine := _machine(library, variant == "timeline")
	if machine == null:
		Common.fail(self, "%s: the library has no idle role" % model)
		return false
	var rig := Node3D.new()
	rig.name = "Rig"
	var model_node := glb.instantiate()
	model_node.name = "Model"
	var clips := AnimationPlayer.new()
	clips.name = "Clips"
	clips.root_node = NodePath("../Model")
	clips.add_animation_library(&"", library)
	var sink := Sink.new()
	sink.name = "ClipEvents"
	var anim_tree := AnimationTree.new()
	anim_tree.name = "Tree"
	anim_tree.root_node = NodePath("../Model")
	anim_tree.tree_root = machine
	anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim_tree.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	for child: Node in [model_node, clips, sink, anim_tree]:
		rig.add_child(child)
	anim_tree.anim_player = NodePath("../Clips")
	root.add_child(rig)
	await process_frame
	anim_tree.active = true
	anim_tree.advance(0.0)
	var playback := anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if playback == null:
		Common.fail(self, "%s: the Tree has no playback" % model)
		return false
	var seen: Dictionary = {}
	for role in library.get_animation_list():
		if _over_budget():
			break
		var anim := library.get_animation(StringName(role))
		var first_of_anim := not seen.has(anim)
		seen[anim] = true
		var one_shot := Common.ONE_SHOT_ROLES.has(String(role)) and anim.length <= 3.0
		var keys := _method_keys(anim)
		var marks := _marks(anim, model_ticks)
		if not (one_shot or (first_of_anim and (not keys.is_empty() or not marks.is_empty()))):
			continue
		var direct := _play(anim_tree, playback, sink, StringName(role), anim.length, false)
		if one_shot:
			tally["end_total"] += 1
			if direct["last"] == &"idle":
				tally["end_ok"] += 1
		if not first_of_anim:
			continue
		for mark: Array in marks:
			tally["m_total"] += 1
			if _matched(direct["fires"], StringName(role), float(mark[1]), ""):
				tally["m_ok"] += 1
			else:
				_miss(variant, model, role, "marker " + str(mark[0]), float(mark[1]), direct["fires"])
		var travelled := _play(anim_tree, playback, sink, StringName(role), anim.length, true) if String(role) != "idle" else direct
		for key: Array in keys:
			if float(key[0]) <= 0.0:
				continue
			tally["d_total"] += 1
			tally["t_total"] += 1
			if _matched(direct["fires"], StringName(role), float(key[0]), String(key[1])):
				tally["d_ok"] += 1
			else:
				_miss(variant, model, role, "direct " + String(key[1]), float(key[0]), direct["fires"])
			if _matched(travelled["fires"], StringName(role), float(key[0]), String(key[1])):
				tally["t_ok"] += 1
			else:
				_miss(variant, model, role, "travel " + String(key[1]), float(key[0]), travelled["fires"])
	root.remove_child(rig)
	rig.free()
	return true


func _over_budget() -> bool:
	if Time.get_ticks_msec() - _started_ms > BUDGET_MS:
		_partial = true
	return _partial


## One state per role of the library, a travel transition between every pair, one-shot roles going back to idle by themselves
## (the shape tools/bake/bake_body_scenes.gd gives the Tree today). null without an idle role.
func _machine(library: AnimationLibrary, timeline: bool) -> AnimationNodeStateMachine:
	var machine := AnimationNodeStateMachine.new()
	var travel := AnimationNodeStateMachineTransition.new()
	travel.xfade_time = FADE_S
	var to_idle := AnimationNodeStateMachineTransition.new()
	to_idle.xfade_time = FADE_S
	to_idle.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	to_idle.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	var start := AnimationNodeStateMachineTransition.new()
	start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	var names := PackedStringArray()
	for role in library.get_animation_list():
		var state := AnimationNodeAnimation.new()
		state.animation = StringName(role)
		if timeline:
			var anim := library.get_animation(StringName(role))
			state.use_custom_timeline = true
			state.stretch_time_scale = false
			state.timeline_length = anim.length
			state.loop_mode = anim.loop_mode
		machine.add_node(StringName(role), state, Vector2(120.0 * names.size(), 0.0))
		names.append(String(role))
	if not names.has("idle"):
		return null
	machine.add_transition(&"Start", &"idle", start)
	for from_role in names:
		for to_role in names:
			if from_role != to_role:
				var back := to_idle if to_role == "idle" and Common.ONE_SHOT_ROLES.has(from_role) else travel
				machine.add_transition(StringName(from_role), StringName(to_role), back)
	return machine


## Starts `role` (directly, or travelling from idle with the crossfade) and steps the Tree by hand for its length + 0.6 s.
## Returns {fires: [[kind, position of the state after the step, state]], last: the state at the end}.
func _play(anim_tree: AnimationTree, playback: AnimationNodeStateMachinePlayback, sink, role: StringName, length: float, travel: bool) -> Dictionary:
	playback.start(&"idle", true)
	for _i in 8:
		anim_tree.advance(DT)
	sink.fired.clear()
	if travel:
		playback.travel(role)
	else:
		playback.start(role, true)
	var fires: Array = []
	var seen := 0
	var steps := mini(int(ceil((length + 0.6) / DT)) + 2, MAX_STEPS)
	for _i in steps:
		anim_tree.advance(DT)
		var position := playback.get_current_play_position()
		var node := playback.get_current_node()
		while seen < sink.fired.size():
			fires.append([sink.fired[seen], position, node])
			seen += 1
	return {"fires": fires, "last": playback.get_current_node()}


## True when a call arrived while `role` was the state, at a position in [expected, expected + one step] (the step that crosses the key).
func _matched(fires: Array, role: StringName, expected: float, kind: String) -> bool:
	for fire: Array in fires:
		if fire[2] != role:
			continue
		var diff := float(fire[1]) - expected
		if diff >= -EPS and diff <= DT + EPS and (kind.is_empty() or String(fire[0]) == kind):
			return true
	return false


func _miss(variant: String, model: String, role: Variant, what: String, expected: float, fires: Array) -> void:
	_miss_lines += 1
	if _miss_lines <= MAX_MISS_LINES:
		print("C1_0 miss variant=%s model=%s role=%s %s expected_s=%.4f fires=%s" % [variant, model, role, what, expected, str(fires.slice(0, 6))])


## [[time, kind]] of every method key of an Animation.
func _method_keys(anim: Animation) -> Array:
	var keys: Array = []
	for track in anim.get_track_count():
		if anim.track_get_type(track) != Animation.TYPE_METHOD:
			continue
		for key in anim.track_get_key_count(track):
			var value: Dictionary = anim.track_get_key_value(track, key)
			var args: Array = value.get("args", [])
			keys.append([anim.track_get_key_time(track, key), str(args[0]) if not args.is_empty() else ""])
	return keys


## [[name, expected time]] of every marker: the dictionary's tick / fps when the creature has one, else the marker's own time.
func _marks(anim: Animation, model_ticks: Dictionary) -> Array:
	var info: Dictionary = model_ticks.get(anim.resource_path.get_file().get_basename(), {})
	var fps := 1.0 / anim.step if anim.step > 0.0 else 30.0
	var out: Array = []
	for marker in anim.get_marker_names():
		var base := String(marker).rstrip("0123456789")
		var index := 0 if String(marker) == base else int(String(marker).trim_prefix(base)) - 1
		var frames: Array = info.get("hits" if base == "hit" else "shoots", [])
		var at := float(frames[index]) / fps if index < frames.size() else anim.get_marker_time(marker)
		out.append([String(marker), at])
	return out
