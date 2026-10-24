extends SceneTree

## No necesita el juego original; usa los modelos ya importados en assets/original (los .glb y su index.json).
## RFC-036 (036g, F208): writes scenes/bodies/models/<tag>.tscn, one per skeletal model of assets/original/models/.
## Each scene is a BodyModel: the .glb instanced as "Model" (z mirrored, like the baked meshes), an AnimationTree whose state
## machine has one state per ROLE playing the model's clip for it, and an "Events" AnimationPlayer whose method tracks fire
## the clip's SKEL events (the "attack" key is the impact). After this runs the scenes are edited in the editor, so a plain
## run writes only the MISSING scenes and keeps the existing ones ("wrote N, kept M"). `--force` rebuilds every scene and
## throws away the edits made in the editor.
##
## Which clip each role plays is the rule the game used to apply at run time (UnitClipRoles): the creature's CreatureType
## (data/catalog/creatures/), the wizard's WizardType (data/catalog/wizards/) and the Sac Doctor's three works. It lives here
## now, once, and the result is saved in the scene.
## The clip facts (frames, framerate, events, hands) and the measures come from assets/original/models/index.json, which
## tools/import/export_skeletal.py writes. Nothing at run time reads that file.
##
## Run:  Godot --headless --path . --script res://tools/bake/bake_body_scenes.gd

const INDEX := "res://assets/original/models/index.json"
const GLB_DIR := "res://assets/original/models/"
const OUT_DIR := "res://scenes/bodies/models/"
const CREATURES_DIR := "res://data/catalog/creatures/"
const WIZARDS_DIR := "res://data/catalog/wizards/"

const EXTRA_ROLES: PackedStringArray = ["cower", "talk_cower", "work"]
const FLIGHT_ROLES: PackedStringArray = ["takeoff", "fly", "land", "hover"]
const STUN_ROLES: PackedStringArray = ["knock", "get_up", "fly_damage"]
const DEATH_ROLES: PackedStringArray = ["death", "fly_death"]
const CAPTIVE_ROLES: PackedStringArray = ["rise", "held", "thrash"]
const CAST_ROLES: PackedStringArray = ["cast", "cast_run"]
## The Sac Doctor (sacd) plays its melee slots as works: slot -> role of the state machine (doctor_body.gd work_slots/work_roles).
const DOCTOR_MODEL := "sacd"
const DOCTOR_SLOT_ROLES := {1: "work", 2: "cast", 0: "attack"}

const XFADE_S := 0.15
## F376 (RFC-053 053g): a rest gesture whose root or hip slides more than this on the ground (ClipSlide) reads as a step on the
## spot, so the model gets no `gesture` role. debug/units/f376_idle_truth.tscn measures every scene against the same limit.
## A scene that is kept (no --force) and still has the gesture is printed: remove its `gesture` state in the editor.
const MAX_GESTURE_SLIDE_M := 0.1
const GRID := Vector2(200.0, 110.0)
const GRID_ORIGIN := Vector2(260.0, 40.0)
const GRID_COLUMNS := 4

var _index: Dictionary = {}
## --force: rebuild the scenes that already exist (the edits made in the editor are lost) and delete the stale ones.
var _force := false
## --only=hero,sage: touch just these models (with --force it rebuilds only them).
var _only := PackedStringArray()


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
	if not parsed is Dictionary:
		push_error("bake_body_scenes: cannot read %s" % INDEX)
		quit(1)
		return
	_index = parsed
	_force = OS.get_cmdline_user_args().has("--force")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7).split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var maps := _role_maps()
	var made := PackedStringArray()
	var kept := PackedStringArray()
	var skipped := PackedStringArray()
	var models: Array = _index.keys()
	models.sort()
	for model: String in models:
		if not _only.is_empty() and not _only.has(model):
			continue
		var roles := _playable(model, maps.get(model, {}))
		_drop_sliding_gesture(model, roles)
		if not roles.has("idle"):
			skipped.append(model)
			if _force:
				_remove_stale(model)
			continue
		if not _force and FileAccess.file_exists(OUT_DIR + model + ".tscn"):
			kept.append(model)
			continue
		if _bake(model, roles):
			made.append(model)
		else:
			skipped.append(model)
	print("BAKE_BODY_SCENES wrote %d, kept %d%s" % [made.size(), kept.size(), " (--force)" if _force else " (existing scenes untouched; --force rebuilds them)"])
	print("BAKE_BODY_SCENES made=%d skipped=%d" % [made.size(), skipped.size()])
	print("BAKE_BODY_SCENES skipped (no playable idle: they stay static meshes): %s" % ", ".join(skipped))
	quit(0)


# --- role -> clip tag --------------------------------------------------------------------------------------------------

## model -> role -> tag, from every CreatureType and WizardType. The first type that names a role wins; a clash is printed.
func _role_maps() -> Dictionary:
	var maps: Dictionary = {}
	for file in _files(CREATURES_DIR):
		var type := load(CREATURES_DIR + file) as CreatureType
		if type == null or type.model.is_empty() or not _index.has(type.model):
			continue
		var roles := _creature_roles(type, type.model)
		if type.model == DOCTOR_MODEL:
			for slot: int in DOCTOR_SLOT_ROLES:
				if slot < type.melee_animations.size():
					roles[DOCTOR_SLOT_ROLES[slot]] = str(type.melee_animations[slot].get("tag", ""))
		_merge(maps, type.model, roles, "creature " + type.tag)
	for file in _files(WIZARDS_DIR):
		var wizard := load(WIZARDS_DIR + file) as WizardType
		if wizard == null or wizard.model.is_empty() or not _index.has(wizard.model):
			continue
		_merge(maps, wizard.model, _wizard_roles(wizard, wizard.model), "wizard " + wizard.tag)
	return maps


func _merge(maps: Dictionary, model: String, roles: Dictionary, who: String) -> void:
	if not maps.has(model):
		maps[model] = roles
		return
	var have: Dictionary = maps[model]
	for role: String in roles:
		if str(roles[role]).is_empty():
			continue
		if not have.has(role) or str(have[role]).is_empty():
			have[role] = roles[role]
		elif have[role] != roles[role]:
			print("BAKE_BODY_SCENES clash %s role %s: kept %s, %s wants %s" % [model, role, have[role], who, roles[role]])


func _creature_roles(type: CreatureType, model: String) -> Dictionary:
	var idle_tag := str(type.idle_animation.get("tag", ""))
	var rest_tag := _rest_tag(type, model, idle_tag)
	# sacengine plays the run state whenever a body moves (state.d:8007-8011); walk is only a fallback for a type with no run clip.
	var run: Dictionary = type.run_animation
	if int(run.get("frames", 0)) <= 1:
		run = type.walk_animation
	var attack_tag := ""
	if not type.melee_animations.is_empty():
		attack_tag = str((type.melee_animations[0] as Dictionary).get("tag", ""))
	var roles := {"idle": rest_tag, "run": str(run.get("tag", "")), "attack": attack_tag}
	# sacengine plays idle0 now and then on top of the rest pose (state.d:7957-7992): the gesture. Only when idle0 is not the rest.
	if rest_tag != idle_tag and not idle_tag.is_empty():
		roles["gesture"] = idle_tag
	var sets: Array = [[type.extra_animations, EXTRA_ROLES], [type.flight_animations, FLIGHT_ROLES], [type.stun_animations, STUN_ROLES],
		[type.captive_animations, CAPTIVE_ROLES], [type.death_animations, DEATH_ROLES]]
	for pair: Array in sets:
		for role: String in pair[1]:
			var clip: Variant = (pair[0] as Dictionary).get(role, {})
			var tag := str((clip as Dictionary).get("tag", "")) if clip is Dictionary else ""
			if not tag.is_empty():
				roles[role] = tag
	return roles


func _wizard_roles(type: WizardType, model: String) -> Dictionary:
	var idle_tag := str(type.idle_animation.get("tag", ""))
	var stance := str(type.stance_animation.get("tag", ""))
	var rest_tag := idle_tag
	if not stance.is_empty() and stance != idle_tag and _has_clip(model, stance):
		rest_tag = stance
	# sacengine plays the run state whenever a body moves (state.d:8007-8011); walk is only a fallback for a type with no run clip.
	var run: Dictionary = type.run_animation
	if int(run.get("frames", 0)) <= 1:
		run = type.walk_animation
	var roles := {"idle": rest_tag, "run": str(run.get("tag", ""))}
	if rest_tag != idle_tag and not idle_tag.is_empty():
		roles["gesture"] = idle_tag
	for role: String in CAST_ROLES:
		var clip: Variant = type.cast_animations.get("run_cast" if role == "cast_run" else role, {})
		var tag := str((clip as Dictionary).get("tag", "")) if clip is Dictionary else ""
		if not tag.is_empty():
			roles[role] = tag
	return roles


## sacengine plays stance1 at the start of every idle loop; idle0..3 are gestures. A model with no stance1 clip rests on idle0.
func _rest_tag(type: CreatureType, model: String, idle_tag: String) -> String:
	var stance := str(type.stance_animation.get("tag", ""))
	if stance.is_empty() or stance == idle_tag or not _has_clip(model, stance):
		return idle_tag
	return stance


## The roles of `model` that a state can play: a known role, whose clip the model has with more than one frame.
func _playable(model: String, wanted: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for role in BodyModel.ROLES:
		var tag := str(wanted.get(role, ""))
		if not tag.is_empty() and _has_clip(model, tag):
			out[role] = tag
	return out


func _has_clip(model: String, tag: String) -> bool:
	return int(_clip(model, tag).get("frames", 0)) > 1


func _clip(model: String, tag: String) -> Dictionary:
	return ((_index.get(model, {}) as Dictionary).get("clips", {}) as Dictionary).get(tag, {})


## F376: takes `gesture` out of `roles` when its clip slides the body more than MAX_GESTURE_SLIDE_M.
func _drop_sliding_gesture(model: String, roles: Dictionary) -> void:
	if not roles.has("gesture"):
		return
	var glb := load(GLB_DIR + model + ".glb") as PackedScene
	var instance := glb.instantiate() if glb != null else null
	if instance == null:
		return
	var rig := ClipSlide.rig_of(instance)
	var tag := str(roles["gesture"])
	if not rig.is_empty() and (rig[0] as AnimationPlayer).has_animation(tag):
		var slide := float(ClipSlide.measure(rig[0], rig[1], (rig[0] as AnimationPlayer).get_animation(tag))["slide"])
		if slide > MAX_GESTURE_SLIDE_M:
			roles.erase("gesture")
			var kept := FileAccess.file_exists(OUT_DIR + model + ".tscn") and FileAccess.get_file_as_string(OUT_DIR + model + ".tscn").contains("states/gesture/node")
			print("BAKE_BODY_SCENES no gesture %s: %s slides %.2f m%s" % [model, tag, slide, " (the kept scene still has it: remove its gesture state)" if kept and not _force else ""])
	instance.free()


# --- scene -------------------------------------------------------------------------------------------------------------

func _bake(model: String, roles: Dictionary) -> bool:
	var info: Dictionary = _index[model]
	var glb := load(GLB_DIR + model + ".glb") as PackedScene
	if glb == null:
		push_error("bake_body_scenes: cannot load %s.glb" % model)
		return false

	var root := BodyModel.new()
	root.name = model
	root.model = model
	root.bind_aabb = _aabb(info.get("bind_aabb", {}))
	root.surface_parts = info.get("surface_parts", [])
	root.clips = _clip_table(model, info, roles)

	var instance := glb.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	instance.name = "Model"
	instance.unique_name_in_owner = true
	# The exporter writes the OBJ axes of sacengine; the game draws them with z mirrored.
	instance.scale = Vector3(1.0, 1.0, -1.0)
	root.add_child(instance)
	instance.owner = root
	var players := instance.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("bake_body_scenes: %s.glb has no AnimationPlayer" % model)
		root.free()
		return false

	var tree := AnimationTree.new()
	tree.name = "Tree"
	tree.unique_name_in_owner = true
	tree.root_node = NodePath("../Model")
	tree.anim_player = NodePath("../Model/" + str(instance.get_path_to(players[0])))
	tree.tree_root = _machine(model, roles)
	tree.deterministic = true
	tree.active = false
	root.add_child(tree)
	tree.owner = root

	var events := AnimationPlayer.new()
	events.name = "Events"
	events.unique_name_in_owner = true
	events.root_node = NodePath("..")
	events.deterministic = true
	events.add_animation_library(&"", _events_library(model, roles))
	root.add_child(events)
	events.owner = root

	var sink := ClipEvents.new()
	sink.name = "ClipEvents"
	sink.unique_name_in_owner = true
	root.add_child(sink)
	sink.owner = root

	var packed := PackedScene.new()
	var error := packed.pack(root)
	root.free()
	if error != OK:
		push_error("bake_body_scenes: cannot pack %s (%d)" % [model, error])
		return false
	error = ResourceSaver.save(packed, OUT_DIR + model + ".tscn")
	if error != OK:
		push_error("bake_body_scenes: cannot save %s (%d)" % [model, error])
		return false
	return true


func _aabb(box: Dictionary) -> AABB:
	if box.is_empty():
		return AABB()
	var low: Array = box["min"]
	var high: Array = box["max"]
	var start := Vector3(low[0], low[1], low[2])
	return AABB(start, Vector3(high[0], high[1], high[2]) - start)


## tag -> {frames, framerate, hands} for the clips the roles use.
func _clip_table(model: String, info: Dictionary, roles: Dictionary) -> Dictionary:
	var scaling := float(info.get("scaling", 1.0))
	var table: Dictionary = {}
	for role: String in roles:
		var tag := str(roles[role])
		if table.has(tag):
			continue
		var clip := _clip(model, tag)
		var hands: Array = []
		for hand: Dictionary in clip.get("hands", []):
			var raw: Array = hand["offset_raw"]
			# Same conversion as the exporter's to_obj: (-x, y, z) times the model's scaling.
			hands.append({"on": int(hand.get("bone", 0)) != 0, "bone_name": str(hand["bone_name"]),
				"offset": Vector3(-raw[0], raw[1], raw[2]) * scaling})
		table[tag] = {"frames": int(clip.get("frames", 0)), "framerate": int(clip.get("framerate", 30)), "hands": hands}
	return table


## One state per role, a travel transition between every pair (the rig asks the machine to travel to a role), and the
## one-shot roles going back to idle by themselves.
func _machine(model: String, roles: Dictionary) -> AnimationNodeStateMachine:
	var machine := AnimationNodeStateMachine.new()
	var travel := AnimationNodeStateMachineTransition.new()
	travel.xfade_time = XFADE_S
	var to_idle := AnimationNodeStateMachineTransition.new()
	to_idle.xfade_time = XFADE_S
	to_idle.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	to_idle.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	var start := AnimationNodeStateMachineTransition.new()
	start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO

	var names := PackedStringArray()
	for role in BodyModel.ROLES:
		if not roles.has(role):
			continue
		var tag := str(roles[role])
		var clip := AnimationNodeAnimation.new()
		clip.animation = StringName(tag)
		# The original shows `frames` frames per pass and wraps; the .glb's own length and loop flag are not used.
		clip.use_custom_timeline = true
		clip.stretch_time_scale = false
		clip.timeline_length = _length(model, tag)
		clip.loop_mode = Animation.LOOP_NONE if BodyModel.HOLD_ROLES.has(role) else Animation.LOOP_LINEAR
		var at := names.size()
		machine.add_node(StringName(role), clip,
			GRID_ORIGIN + Vector2(GRID.x * (at % GRID_COLUMNS), GRID.y * (at / GRID_COLUMNS)))
		names.append(role)
	machine.set_node_position(&"Start", Vector2(60.0, 100.0))
	machine.add_transition(&"Start", &"idle", start)
	for from in names:
		for to in names:
			if from == to:
				continue
			var back := to_idle if to == "idle" and BodyModel.ONE_SHOT_ROLES.has(from) else travel
			machine.add_transition(StringName(from), StringName(to), back)
	return machine


## Seconds of one pass of a clip (frames / framerate).
func _length(model: String, tag: String) -> float:
	var clip := _clip(model, tag)
	return float(clip.get("frames", 1)) / maxf(float(clip.get("framerate", 30)), 1.0)


## One animation per clip tag that has events: a method track with ClipEvents.fire(kind) at each event's frame.
func _events_library(model: String, roles: Dictionary) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	var looping: Dictionary = {}
	for role: String in roles:
		looping[str(roles[role])] = looping.get(str(roles[role]), false) or not BodyModel.HOLD_ROLES.has(role)
	for tag: String in looping:
		var clip := _clip(model, tag)
		var list: Array = clip.get("events", [])
		if list.is_empty():
			continue
		var fps := maxf(float(clip.get("framerate", 30)), 1.0)
		var animation := Animation.new()
		animation.length = float(clip.get("frames", 1)) / fps
		animation.loop_mode = Animation.LOOP_LINEAR if looping[tag] else Animation.LOOP_NONE
		var track := animation.add_track(Animation.TYPE_METHOD)
		animation.track_set_path(track, NodePath("ClipEvents"))
		for event: Dictionary in list:
			var at := minf(float(event["frame"]) / fps, animation.length)
			animation.track_insert_key(track, at, {"method": &"fire", "args": [str(event["kind"])]})
		library.add_animation(StringName(tag), animation)
	return library


# --- files -------------------------------------------------------------------------------------------------------------

func _files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tres"):
			out.append(file)
	out.sort()
	return out


func _remove_stale(model: String) -> void:
	var path := OUT_DIR + model + ".tscn"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
