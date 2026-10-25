extends SceneTree

## No necesita el juego original; usa los modelos y datos ya importados en assets/original (versionados).
## RFC-051: a creature of your own from a .glb (Blender, or anything that exports glTF with a skeleton and animations).
## Nothing here reads the original game's data (assets/original/models/index.json, the WADs): the clips, their length, the
## impact moment and the size all come from the .glb itself.
##
##   Godot --headless --path . --script res://tools/bake/new_creature.gd -- testmonster
##   Godot --headless --path . --script res://tools/bake/new_creature.gd -- res://assets/custom/models/testmonster.glb --name="Test Monster" --god=pyro
##
## It writes three files, never over an existing one (`--force` rewrites all three and throws away what you edited):
##   scenes/bodies/models/<tag>.tscn       BodyModel: the .glb, an AnimationTree with one state per role, the Events player.
##   data/catalog/body_sizes/<tag>.tres    BodySize measured from the mesh (box, height, radius, reach).
##   data/catalog/creatures/<tag>.tres     CreatureType: the stats of data/templates/creature.tres + the model + the clip facts
##                                          the rules read (melee/shoot timing, stun, flight, death).
## `--sync` re-reads the model scene of an existing creature and refreshes only its clip facts (keeps your stats). Run it after
## you change which clip a role plays, or an event, in the model scene.
##
## Roles are found by the NAME of each animation, tolerant of case, separators, a Blender suffix (`Attack.001`) and an armature
## prefix (`Armature|Run`): idle, run (or walk), attack, shoot, cast, hit, death, fly, takeoff, land, hover, knock, get_up...
## The impact moment of a clip is in its name: `attack_at45` = at 45 % of the clip, `attack_f18` = at frame 18. Without one it is
## the middle (50 %). Both are editable afterwards: the "attack" key of the Events animation in the model scene.
## Attack variants (F336): clips named `attack`, `attack2`, `attack3` (or `attack_a`, `attack_b`, `attack_c`; each with its own `_atNN`/`_fNN`
## impact) become up to three melee swings, the slots 0, 1 and 2 of `melee_animations`. The rules pick the slot 0 or the slot 1 at random
## for each swing; the slot 2 is the one against a target well below (a downward blow). Each swing plays its own clip.
## The HUD icon (F335): `assets/custom/icons/<tag>.png` if it exists (yours, never overwritten); else one is drawn from the model (the idle
## pose, the camera framing its box) with tools/bake/creature_icon_render.gd. Drawing needs a renderer: from a headless run it is skipped (a note
## says so) and `Godot --path . --script res://tools/bake/creature_icon.gd -- <tag>` (with a window) makes it afterwards.
## Sounds: it also writes data/audio/creatures/<tag>.tres, a SoundSet over the fist melee set, and puts it in the creature's `sounds`.
## When assets/custom/sounds/creatures/<tag>/ exists, its files (`death_1.wav`, `swing_1.ogg`...: the event names of SoundEvent.BODY)
## fill the fields of the set; without that folder the set is empty (drag the files onto it in the inspector). Never over an
## existing one (`--force` rewrites it). Also with `--sync`.
## Options: --name="Display name"  --god=<god tag>  --fps=<n> (default: the animation's own step, 30)  --force  --sync
##          --icon (draw the icon again even if the PNG exists)  --no-icon (do not draw one)
##          --sounds=res://dir/ --sounds-out=res://dir/ (another source / target for the sounds, e.g. a fixture)

const TEMPLATE := "res://data/templates/creature.tres"
const MODEL_DIR := "res://assets/custom/models/"
const SCENE_DIR := "res://scenes/bodies/models/"
const CREATURES_DIR := "res://data/catalog/creatures/"
const SIZES_DIR := "res://data/catalog/body_sizes/"
const SoundSetWriter := preload("res://tools/bake/sound_set_writer.gd")

const XFADE_S := 0.15
const GRID := Vector2(200.0, 110.0)
const GRID_ORIGIN := Vector2(260.0, 40.0)
const GRID_COLUMNS := 4
const DEFAULT_IMPACT := 0.5

## Words that name a role. The first word of a list is the preferred one when a model has several clips for the same role
## (`run` before `walk`).
const WORDS := {
	"idle": ["idle", "stand", "stance", "rest", "breath", "breathe"],
	"run": ["run", "sprint", "gallop", "trot", "jog", "walk", "move", "locomotion", "charge"],
	"attack": ["attack", "melee", "slash", "bite", "swing", "punch", "claw", "strike", "smash", "stab", "bash"],
	"shoot": ["shoot", "fire", "ranged", "spit", "throw"],
	"cast": ["cast", "spell", "magic"],
	"hit": ["hit", "hurt", "damage", "flinch", "pain", "react"],
	"death": ["death", "die", "dying", "dead"],
	"fly": ["fly", "flying", "flap", "flight", "glide"],
	"takeoff": ["takeoff", "launch"],
	"land": ["land", "landing"],
	"hover": ["hover"],
	"knock": ["knock", "knockdown", "fall"],
	"getup": ["getup", "recover"],
	"cower": ["cower", "cringe"],
	"work": ["work", "dig"],
	"held": ["held", "grabbed"],
	"thrash": ["thrash", "struggle"],
	"rise": ["rise", "revive"],
	"gesture": ["gesture", "taunt", "emote"],
}
## Role -> the word groups a clip name must have ALL of. Compound roles come first so `fly_death` is not taken by `death`.
const RULES := [
	["fly_death", ["fly", "death"]], ["fly_damage", ["fly", "hit"]], ["cast_run", ["cast", "run"]],
	["takeoff", ["takeoff"]], ["land", ["land"]], ["hover", ["hover"]], ["get_up", ["getup"]], ["knock", ["knock"]],
	["talk_cower", []], ["cower", ["cower"]], ["work", ["work"]], ["held", ["held"]], ["thrash", ["thrash"]], ["rise", ["rise"]],
	["gesture", ["gesture"]], ["death", ["death"]], ["hit", ["hit"]], ["attack", ["attack"]], ["shoot", ["shoot"]],
	["cast", ["cast"]], ["fly", ["fly"]], ["run", ["run"]], ["idle", ["idle"]],
]
## A role with no clip of its own plays another role's (the rig itself rests on idle for the rest, e.g. `hit`).
const FALLBACKS := {"shoot": ["attack"], "hover": ["fly"], "fly_death": ["death"], "fly_damage": ["hit"]}
## The fallbacks of these roles only make sense for a body that flies.
const FLIGHT_FALLBACKS: PackedStringArray = ["hover", "fly_death", "fly_damage"]

## Role of each melee slot (CreatureType.melee_animations): the rules pick 0 or 1 at random, 2 is the downward blow.
const ATTACK_ROLES: PackedStringArray = ["attack", "attack2", "attack3"]

## CreatureType dictionary -> roles it holds (the rules read these; the key is the role).
const SETS := {
	"stun_animations": ["knock", "get_up", "fly_damage"],
	"death_animations": ["death", "fly_death"],
	"flight_animations": ["takeoff", "fly", "land", "hover"],
	"captive_animations": ["rise", "held", "thrash"],
	"extra_animations": ["cower", "talk_cower", "work"],
}

var _force := false
var _sync := false
var _fps_arg := 0
var _icon := false
var _no_icon := false
var _sounds_src: String = SoundSetWriter.CUSTOM_SRC
var _sounds_out: String = SoundSetWriter.CUSTOM_OUT
var _job: Callable
var _started := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var positional := ""
	var display := ""
	var god := ""
	for arg in args:
		if arg == "--force":
			_force = true
		elif arg == "--sync":
			_sync = true
		elif arg == "--icon":
			_icon = true
		elif arg == "--no-icon":
			_no_icon = true
		elif arg.begins_with("--sounds="):
			_sounds_src = arg.get_slice("=", 1)
		elif arg.begins_with("--sounds-out="):
			_sounds_out = arg.get_slice("=", 1)
		elif arg.begins_with("--fps="):
			_fps_arg = int(arg.get_slice("=", 1))
		elif arg.begins_with("--name="):
			display = arg.get_slice("=", 1)
		elif arg.begins_with("--god="):
			god = arg.get_slice("=", 1)
		elif not arg.begins_with("--") and positional.is_empty():
			positional = arg
	if positional.is_empty():
		push_error("new_creature: pass the model tag or the .glb path: ... --script res://tools/bake/new_creature.gd -- testmonster")
		quit(1)
		return
	var glb_path := positional if positional.ends_with(".glb") else MODEL_DIR + positional + ".glb"
	var tag := glb_path.get_file().get_basename()
	if tag != tag.validate_filename() or tag.is_empty() or tag.contains(" "):
		push_error("new_creature: «%s» is not a usable tag (no spaces or symbols: rename the .glb)" % tag)
		quit(1)
		return
	# BodyModel answers only once it is ready, and the root is not in the tree yet during _initialize: work on the first frame.
	_job = _sync_creature.bind(tag) if _sync else _create.bind(tag, glb_path, display, god)


func _process(_delta: float) -> bool:
	if _job.is_valid() and not _started:
		_started = true
		_run_job()
	return false


func _run_job() -> void:
	var code: int = await _job.call()
	quit(code)


# --- create ------------------------------------------------------------------------------------------------------------

func _create(tag: String, glb_path: String, display: String, god: String) -> int:
	if not ResourceLoader.exists(glb_path):
		push_error("new_creature: %s is not imported. Open the project in the editor once, or run `Godot --headless --path . --import`." % glb_path)
		return 1
	var glb := load(glb_path) as PackedScene
	if glb == null:
		push_error("new_creature: cannot load %s" % glb_path)
		return 1
	var instance := glb.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	var players := instance.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("new_creature: %s has no animations (export with the animations on; one action per clip)" % glb_path)
		instance.free()
		return 1
	var player := players[0] as AnimationPlayer
	var clips := _clips(player)
	var found := _roles(clips)
	var roles: Dictionary = found["roles"]
	if not roles.has("idle"):
		push_error("new_creature: no clip is named like «idle» (clips: %s)" % ", ".join(clips.keys()))
		instance.free()
		return 1
	var measure := _measure(instance)
	var scene_path := SCENE_DIR + tag + ".tscn"
	var type_path := CREATURES_DIR + tag + ".tres"
	var size_path := SIZES_DIR + tag + ".tres"
	var wrote := PackedStringArray()
	var kept := PackedStringArray()

	if _may_write(scene_path):
		if _save_scene(tag, glb, clips, roles, found["impacts"], measure["aabb"]):
			wrote.append(scene_path)
	else:
		kept.append(scene_path)
	if _may_write(size_path):
		if ResourceSaver.save(_body_size(tag, measure), size_path) == OK:
			wrote.append(size_path)
	else:
		kept.append(size_path)
	if _may_write(type_path):
		var type := (load(TEMPLATE) as CreatureType).duplicate() as CreatureType
		type.tag = tag
		type.display_name = display if not display.is_empty() else tag.capitalize()
		type.god = god
		type.model = tag
		if not roles.has("run") and roles.has("fly"):
			# A flier with no ground clip: it never walks.
			type.flying_speed = type.running_speed
			type.running_speed = 0.0
		if ResourceSaver.save(type, type_path) == OK:
			wrote.append(type_path)
	else:
		kept.append(type_path)
	instance.free()

	# The clip facts come from the saved model scene, the one a human edits: the same path as --sync.
	if wrote.has(type_path) and _fill_from_scene(tag) != OK:
		return 1

	var icon := await _make_icon(tag, str(roles["idle"]))
	_report(tag, clips, found, measure, wrote, kept, god, icon)
	return _bake_sounds(tag)


func _may_write(path: String) -> bool:
	return _force or not FileAccess.file_exists(path)


## name -> {seconds, fps, frames} of every clip of the .glb with more than one frame.
func _clips(player: AnimationPlayer) -> Dictionary:
	var out := {}
	for name in player.get_animation_list():
		var animation := player.get_animation(name)
		var fps := _fps_arg if _fps_arg > 0 else (roundi(1.0 / animation.step) if animation.step > 0.0 else BodyModel.DEFAULT_FRAMERATE)
		var frames := roundi(animation.length * fps)
		if frames > 1:
			out[String(name)] = {"seconds": animation.length, "fps": fps, "frames": frames}
	return out


# --- names -> roles ----------------------------------------------------------------------------------------------------

## {roles: role -> clip name, impacts: clip name -> fraction of the clip (0..1), unused: clips no role took}.
func _roles(clips: Dictionary) -> Dictionary:
	var parsed := {}
	var impacts := {}
	for name: String in clips:
		var info := _parse(name)
		parsed[name] = info
		if info["impact"] >= 0.0:
			impacts[name] = info["impact"]
		elif info["impact_frame"] >= 0:
			impacts[name] = clampf(float(info["impact_frame"]) / float(clips[name]["frames"]), 0.0, 1.0)
	var roles := {}
	var taken := {}
	# The melee swings first: a variant (`attack2`) must not be taken for the plain `attack`.
	var swings := {}
	for name: String in clips:
		var variant := int(parsed[name]["variant"])
		if variant < 0:
			continue
		var rank := _score(parsed[name]["tokens"], parsed[name]["flat"], ["attack"])
		if not swings.has(variant) or rank > swings[variant]["rank"]:
			swings[variant] = {"name": name, "rank": rank}
	for variant: int in swings:
		roles[ATTACK_ROLES[variant]] = swings[variant]["name"]
		taken[swings[variant]["name"]] = true
	if not roles.has("attack") and not swings.is_empty():
		roles["attack"] = roles[ATTACK_ROLES[swings.keys().min()]]  # only an `attack2`: it is the creature's attack
	for rule: Array in RULES:
		var role: String = rule[0]
		var groups: Array = rule[1]
		if groups.is_empty() or roles.has(role):
			continue
		var best := ""
		var best_score := -1
		for name: String in clips:
			if taken.has(name):
				continue
			var score := _score(parsed[name]["tokens"], parsed[name]["flat"], groups)
			if score > best_score:
				best_score = score
				best = name
		if best_score >= 0:
			roles[role] = best
			taken[best] = true
	for role: String in FALLBACKS:
		if roles.has(role) or (FLIGHT_FALLBACKS.has(role) and not roles.has("fly")):
			continue
		for other: String in FALLBACKS[role]:
			if roles.has(other):
				roles[role] = roles[other]
				break
	var unused := PackedStringArray()
	for name: String in clips:
		if not taken.has(name):
			unused.append(name)
	return {"roles": roles, "impacts": impacts, "unused": unused}


## The lower-case name without its decorations: tokens, the flat (no separators) form, the impact if the name has one and, for a
## melee clip, its `variant` (0 attack, 1 attack2, 2 attack3; -1 for any other clip). Tokens and flat are those of the name without the
## variant suffix.
func _parse(name: String) -> Dictionary:
	var text := name.to_lower()
	if text.contains("|"):
		text = text.substr(text.rfind("|") + 1)
	var impact := -1.0
	var impact_frame := -1
	var regex := RegEx.new()
	regex.compile("[_\\-\\. ]+(at|f)(\\d+)$")
	var mark := regex.search(text)
	if mark != null:
		if mark.get_string(1) == "f":
			impact_frame = int(mark.get_string(2))
		else:
			impact = clampf(float(mark.get_string(2)) / 100.0, 0.0, 1.0)
		text = text.substr(0, mark.get_start())
	regex.compile("\\.\\d{3}$")
	text = regex.sub(text, "")  # Blender's `.001`
	var variant := -1
	# `attack2`, `attack_3`, `attack_b`: the suffix tells which swing of the creature it is.
	regex.compile("^(.*[a-z])[_\\-\\. ]*([123abc])$")
	var suffix := regex.search(text)
	if suffix != null:
		var base := _tokens_of(suffix.get_string(1))
		if _is_attack(base, "".join(base)):
			variant = "1a2b3c".find(suffix.get_string(2)) >> 1
			text = suffix.get_string(1)
	regex.compile("[_\\-\\. ]+\\d{1,3}$")
	text = regex.sub(text, "")  # a numbered copy (`idle_01`)
	regex.compile("[_\\-\\. ]*loop$")
	text = regex.sub(text, "")
	var tokens := _tokens_of(text)
	var flat := "".join(tokens)
	if variant < 0 and _is_attack(tokens, flat):
		variant = 0
	return {"tokens": tokens, "flat": flat, "impact": impact, "impact_frame": impact_frame, "variant": variant}


func _tokens_of(text: String) -> PackedStringArray:
	var tokens := PackedStringArray()
	var regex := RegEx.new()
	regex.compile("[a-z]+|\\d+")
	for found in regex.search_all(text):
		tokens.append(found.get_string())
	return tokens


## A name that is a melee swing and nothing else (`fly_attack` or `death_attack` are not).
func _is_attack(tokens: PackedStringArray, flat: String) -> bool:
	if _score(tokens, flat, ["attack"]) < 0:
		return false
	for rule: Array in RULES:
		if rule[0] != "attack" and not (rule[1] as Array).is_empty() and _score(tokens, flat, rule[1]) >= 0:
			return false
	return true


## -1: the clip is not this role's. Higher is a closer name: the name IS a word, then its first token is, then any token is.
## Within a level the earlier word of the list wins (`run` over `walk`).
func _score(tokens: PackedStringArray, flat: String, groups: Array) -> int:
	var total := 0
	for group: String in groups:
		var words: Array = WORDS[group]
		var best := -1
		for i in words.size():
			var level := -1
			if flat == words[i]:
				level = 3
			elif _token_is(tokens[0] if not tokens.is_empty() else "", words[i]):
				level = 2
			else:
				for token in tokens:
					if _token_is(token, words[i]):
						level = 1
						break
			if level >= 0:
				best = maxi(best, level * 100 - i)
		if best < 0:
			return -1
		total += best
	return total + 1000 - 10 * tokens.size()  # fewer extra words = closer


func _token_is(token: String, word: String) -> bool:
	if token == word:
		return true
	if not token.begins_with(word):
		return false
	var rest := token.substr(word.length())
	return rest.is_valid_int() or (word.length() >= 4 and rest.length() <= 4)  # attack2, attacking, running


# --- size --------------------------------------------------------------------------------------------------------------

## {aabb: the skinned meshes' rest-pose box in model space, raw: the union of their own boxes}.
func _measure(root: Node3D) -> Dictionary:
	var box := AABB()
	var raw := AABB()
	var first := true
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var to_root := Transform3D.IDENTITY
		var node: Node = mesh
		while node != null and node != root:
			to_root = (node as Node3D).transform * to_root
			node = node.get_parent()
		var local := mesh.mesh.get_aabb()
		var moved := to_root * local
		box = moved if first else box.merge(moved)
		raw = local if first else raw.merge(local)
		first = false
	return {"aabb": box, "raw": raw}


## height = the box's; the capsule radius = half its narrow side; reach = half its long side (the melee box). Tune them in the .tres.
func _body_size(tag: String, measure: Dictionary) -> BodySize:
	var box: AABB = measure["aabb"]
	var size := BodySize.new()
	size.tag = tag
	size.box = PackedFloat64Array([_mm(box.position.x), _mm(box.position.y), _mm(box.position.z), _mm(box.size.x), _mm(box.size.y), _mm(box.size.z)])
	size.height = _mm(box.size.y)
	size.radius = _mm(minf(box.size.x, box.size.z) * 0.5)
	size.reach = _mm(maxf(box.size.x, box.size.z) * 0.5)
	size.upright_fix = PackedFloat64Array([0.0, 0.0, 0.0])
	return size


## Rounded to the millimeter (a .tres should read 0.475, not 0.47500000000000003).
func _mm(value: float) -> float:
	return roundf(value * 1000.0) / 1000.0


# --- model scene -------------------------------------------------------------------------------------------------------

func _save_scene(tag: String, glb: PackedScene, clips: Dictionary, roles: Dictionary, impacts: Dictionary, box: AABB) -> bool:
	var root := BodyModel.new()
	root.name = tag
	root.model = tag
	root.bind_aabb = box
	var table := {}
	for name: String in clips:
		table[name] = {"frames": clips[name]["frames"], "framerate": clips[name]["fps"], "hands": []}
	root.clips = table

	var instance := glb.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	instance.name = "Model"
	instance.unique_name_in_owner = true
	# A custom model is already in the game's axes (glTF faces +Z): no mirror, unlike the original's.
	root.add_child(instance)
	instance.owner = root
	var found := instance.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer

	var tree := AnimationTree.new()
	tree.name = "Tree"
	tree.unique_name_in_owner = true
	tree.root_node = NodePath("../Model")
	tree.anim_player = NodePath("../Model/" + str(instance.get_path_to(found)))
	tree.tree_root = _machine(roles, clips)
	tree.deterministic = true
	tree.active = false
	root.add_child(tree)
	tree.owner = root

	var events := AnimationPlayer.new()
	events.name = "Events"
	events.unique_name_in_owner = true
	events.root_node = NodePath("..")
	events.deterministic = true
	events.add_animation_library(&"", _events_library(roles, clips, impacts))
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
		push_error("new_creature: cannot pack %s (%d)" % [tag, error])
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIR))
	error = ResourceSaver.save(packed, SCENE_DIR + tag + ".tscn")
	if error != OK:
		push_error("new_creature: cannot save %s.tscn (%d)" % [tag, error])
		return false
	return true


## One state per role, travel transitions between all, one-shot roles back to idle by themselves (as bake_body_scenes does).
func _machine(roles: Dictionary, clips: Dictionary) -> AnimationNodeStateMachine:
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
		var tag: String = roles[role]
		var clip := AnimationNodeAnimation.new()
		clip.animation = StringName(tag)
		# The glTF clip is not marked as a loop: the state says whether it repeats. Change the clip of a state and
		# set `timeline_length` to the new clip's seconds.
		clip.use_custom_timeline = true
		clip.stretch_time_scale = false
		clip.timeline_length = float(clips[tag]["seconds"])
		clip.loop_mode = Animation.LOOP_NONE if BodyModel.HOLD_ROLES.has(role) else Animation.LOOP_LINEAR
		var at := names.size()
		machine.add_node(StringName(role), clip, GRID_ORIGIN + Vector2(GRID.x * (at % GRID_COLUMNS), GRID.y * (at / GRID_COLUMNS)))
		names.append(role)
	machine.set_node_position(&"Start", Vector2(60.0, 100.0))
	machine.add_transition(&"Start", &"idle", start)
	for from in names:
		for to in names:
			if from != to:
				machine.add_transition(StringName(from), StringName(to), to_idle if to == "idle" and BodyModel.ONE_SHOT_ROLES.has(from) else travel)
	return machine


## One small animation per clip a role plays: a method track with ClipEvents.fire(kind) at the impact. attack, attack2 and
## attack3 -> "attack", shoot -> "shoot", cast -> "cast". No mark in the name = the middle of the clip.
func _events_library(roles: Dictionary, clips: Dictionary, impacts: Dictionary) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for role in ["attack", "attack2", "attack3", "shoot", "cast"]:
		if not roles.has(role):
			continue
		var tag: String = roles[role]
		if library.has_animation(StringName(tag)):
			continue
		var seconds: float = clips[tag]["seconds"]
		var animation := Animation.new()
		animation.length = seconds
		animation.loop_mode = Animation.LOOP_NONE
		var track := animation.add_track(Animation.TYPE_METHOD)
		animation.track_set_path(track, NodePath("ClipEvents"))
		animation.track_insert_key(track, seconds * float(impacts.get(tag, DEFAULT_IMPACT)), {"method": &"fire", "args": ["attack" if role.begins_with("attack") else role]})
		library.add_animation(StringName(tag), animation)
	return library


# --- clip facts for the rules ------------------------------------------------------------------------------------------

func _sync_creature(tag: String) -> int:
	if not FileAccess.file_exists(CREATURES_DIR + tag + ".tres") or not BodyModel.exists(tag):
		push_error("new_creature --sync: %s.tres or its model scene %s.tscn do not exist" % [tag, tag])
		return 1
	var code := _fill_from_scene(tag)
	if code == OK:
		print("NEW_CREATURE synced %s: the clip facts of data/catalog/creatures/%s.tres follow scenes/bodies/models/%s.tscn" % [tag, tag, tag])
		var type := ResourceLoader.load(CREATURES_DIR + tag + ".tres", "", ResourceLoader.CACHE_MODE_REPLACE) as CreatureType
		print("NEW_CREATURE icon: %s" % await _make_icon(tag, str(type.idle_animation.get("tag", ""))))
		code = _bake_sounds(tag)
	return code


## Loads the saved model scene and the creature file of `tag`, rewrites the creature's clip dictionaries from the scene
## (role -> clip from the AnimationTree, frames and framerate from the clip, impact from the Events animation) and saves it.
func _fill_from_scene(tag: String) -> int:
	var type := ResourceLoader.load(CREATURES_DIR + tag + ".tres", "", ResourceLoader.CACHE_MODE_REPLACE) as CreatureType
	var packed := ResourceLoader.load(BodyModel.scene_path(tag), "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if type == null or packed == null:
		push_error("new_creature: cannot read the creature or the scene of %s" % tag)
		return 1
	var model := packed.instantiate() as BodyModel
	# BodyModel finds its nodes when it is ready: it has to be in the tree to answer.
	root.add_child(model)
	var roles := model.roles()

	var idle := _clip(model, "idle")
	type.idle_animation = idle
	type.stance_animation = {}
	var run := _clip(model, "run")
	type.run_animation = run
	type.walk_animation = run
	type.melee_animations = [] as Array[Dictionary]
	if roles.has("attack"):
		# The slot 1 is the second of the random pair: without an `attack2` but with an `attack3`, it repeats the attack.
		var slots: Array[String] = ["attack", "attack2" if roles.has("attack2") else ("attack" if roles.has("attack3") else "")]
		if roles.has("attack3"):
			slots.append("attack3")
		for role in slots:
			if not role.is_empty():
				var swing := _clip(model, role)
				swing["attack_ticks"] = [_impact_frame(model, role)]
				type.melee_animations.append(swing)
	type.shoot_animations = [] as Array[Dictionary]
	if roles.has("shoot"):
		var shoot := _clip(model, "shoot")
		shoot["shoot_ticks"] = [_impact_frame(model, "shoot")]
		type.shoot_animations.append(shoot)
	for property: String in SETS:
		var table := {}
		for role: String in SETS[property]:
			if roles.has(role):
				table[role] = _clip(model, role)
		type.set(property, table)
	root.remove_child(model)
	model.free()
	var error := ResourceSaver.save(type, CREATURES_DIR + tag + ".tres")
	if error != OK:
		push_error("new_creature: cannot save %s.tres (%d)" % [tag, error])
		return 1
	return OK


## {tag, frames, framerate} of the clip a role plays in the scene ({} when it has none).
func _clip(model: BodyModel, role: String) -> Dictionary:
	if not model.has_role(role):
		return {}
	var tag := model.tag_for(role)
	return {"tag": tag, "frames": model.frames_of(tag), "framerate": model.framerate_of(tag)}


## The frame of the first event of the role's clip in the Events animation; the middle of the clip without one.
func _impact_frame(model: BodyModel, role: String) -> float:
	var tag := model.tag_for(role)
	var events := model.events_player()
	if events != null and events.has_animation(tag):
		var animation := events.get_animation(tag)
		for track in animation.get_track_count():
			if animation.track_get_type(track) == Animation.TYPE_METHOD and animation.track_get_key_count(track) > 0:
				return snappedf(animation.track_get_key_time(track, 0) * model.framerate_of(tag), 0.01)
	return float(model.frames_of(tag)) * DEFAULT_IMPACT


# --- icon ---------------------------------------------------------------------------------------------------------------

## Draws assets/custom/icons/<tag>.png when it is missing (or `--icon`), keeps yours when it is there. Returns what happened.
func _make_icon(tag: String, idle_clip: String) -> String:
	if _no_icon:
		return "skipped (--no-icon)"
	return await CreatureIconRender.ensure(root, tag, idle_clip, _icon)


# --- sounds -------------------------------------------------------------------------------------------------------------

## The creature's SoundSet (tools/bake/sound_set_writer.gd): the files of `_sounds_src`/creatures/<tag>/ as its fields, or an empty
## set over the fist melee set when there are none. It becomes the creature's `sounds` when the set went to data/audio/ and the
## creature has none yet.
func _bake_sounds(tag: String) -> int:
	var folder := _sounds_src.path_join("creatures").path_join(tag)
	var has_files := SoundSetWriter.has_sounds(tag, _sounds_src)
	var writer := SoundSetWriter.new()
	writer.force = _force
	var path := writer.write_creature_set(tag, _sounds_src, _sounds_out)
	for file in writer.unknown:
		print("NEW_CREATURE sounds note: %s is not an event with a field in the set. Events: %s" % [file, SoundSetWriter.event_help()])
	if not writer.failures.is_empty():
		push_error("new_creature: could not save the sounds: %s" % ", ".join(writer.failures))
		return 1
	if writer.written.has(path):
		print("NEW_CREATURE sounds wrote: %s" % path)
		if not has_files:
			print("NEW_CREATURE sounds: the set is empty (it uses the fist melee sounds); drag .ogg or .wav files onto its fields, or put <event>_1.wav in %s/ and run again with --force" % folder)
	else:
		print("NEW_CREATURE sounds kept (exists; --force rewrites it): %s" % path)
	_assign_sounds(tag, path)
	return OK


## `type.sounds = set` in data/catalog/creatures/<tag>.tres when the set is a product file (not a test output) and the creature has none.
func _assign_sounds(tag: String, set_path: String) -> void:
	if not set_path.begins_with(SoundSetWriter.CUSTOM_OUT):
		return
	var type_path := CREATURES_DIR + tag + ".tres"
	var type := ResourceLoader.load(type_path, "", ResourceLoader.CACHE_MODE_REPLACE) as CreatureType
	if type == null or type.sounds != null:
		return
	type.sounds = load(set_path) as SoundSet
	if ResourceSaver.save(type, type_path) == OK:
		print("NEW_CREATURE sounds: %s uses %s" % [type_path, set_path])


# --- output ------------------------------------------------------------------------------------------------------------

func _report(tag: String, clips: Dictionary, found: Dictionary, measure: Dictionary, wrote: PackedStringArray, kept: PackedStringArray, god: String, icon: String) -> void:
	var roles: Dictionary = found["roles"]
	var lines := PackedStringArray()
	for role in BodyModel.ROLES:
		if roles.has(role):
			var name: String = roles[role]
			var note := ""
			if found["impacts"].has(name):
				note = "  impact %d %%" % roundi(float(found["impacts"][name]) * 100.0)
			lines.append("  %-10s <- %s (%d frames @ %d)%s" % [role, name, clips[name]["frames"], clips[name]["fps"], note])
	print("NEW_CREATURE %s" % tag)
	print("NEW_CREATURE roles:\n%s" % "\n".join(lines))
	if not (found["unused"] as PackedStringArray).is_empty():
		print("NEW_CREATURE clips no role took (rename them like a role, or point a state of the model scene at them): %s" % ", ".join(found["unused"]))
	for role in ["run", "attack", "death"]:
		if not roles.has(role):
			print("NEW_CREATURE note: no «%s» clip%s" % [role, " (the creature rests on idle while it walks)" if role == "run" else (" (it hits on the last frame of an empty swing)" if role == "attack" else " (the body tips over instead)")])
	var box: AABB = measure["aabb"]
	print("NEW_CREATURE size: height %.2f, box %.2f x %.2f" % [box.size.y, box.size.x, box.size.z])
	print("NEW_CREATURE wrote: %s" % ", ".join(wrote))
	print("NEW_CREATURE icon: %s" % icon)
	if not kept.is_empty():
		print("NEW_CREATURE kept (exist; --force rewrites them, --sync refreshes the clip facts only): %s" % ", ".join(kept))
	print("NEW_CREATURE next: put data/catalog/creatures/%s.tres in the book of %s (data/gods/%s.tres > book > creatures, and a line in unlocks), then run the catalog validator." % [tag, god if not god.is_empty() else "a god", god if not god.is_empty() else "<god>"])
