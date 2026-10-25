extends SceneTree

## 055s s2 (one-shot migration, needs Godot): turns the hands of the models into nodes and tracks.
## For each scenes/bodies/models/<model>.tscn it reads `clips` (clip tag -> {hands: [{on, bone_name, offset}, {...}]}), the table of
## the original, and the library <model>_clips.tres (role -> Animation, the Animation named after its clip tag), and finds which hands
## the model really has: one per distinct (slot, bone, offset) of a clip that has that hand on (HandL, HandR; a second set is HandL2...).
## Then it writes into the library what the scene will use:
##   - in every Animation whose clip has a hand on: a `Skeleton3D/<Hand>:visible = true` track, one key at 0;
##   - an Animation named RESET with `visible = false` for every hand, so every role without the hand hides it again.
## The nodes themselves (BoneAttachment3D + Marker3D Socket) are written by write_hands_055s.py from tools/migrate/hands_055s.json,
## which this script writes. Run it BEFORE that python (it needs the `clips` table the python removes from the scenes).
## Run:  Godot --headless --path game --script res://tools/migrate/bake_hands_055s.gd
## No autoloads in --script mode: nothing here instances a scene. Every exit goes through quit(); a 120 s guard stops a hang.
## Prints HANDS models=<n> with_hands=<n> nodes=<n> tracks=<n> resets=<n> and HANDS DONE | HANDS FAIL.

const MODELS_DIR := "res://scenes/bodies/models/"
const OUT := "res://tools/migrate/hands_055s.json"
const LIMIT_S := 120.0
const RESET := &"RESET"
const PATH := "Skeleton3D/%s:visible"
## A RESET animation has no length of its own; a thousandth of a second is the shortest the editor accepts.
const RESET_LENGTH_S := 0.001

var _started := 0.0
var _tracks := 0
var _resets := 0


func _initialize() -> void:
	_started = Time.get_ticks_msec() / 1000.0
	create_timer(LIMIT_S).timeout.connect(func() -> void:
		print("HANDS FAIL timeout")
		quit(2))
	quit(_run())


func _run() -> int:
	var report := {}
	var models := 0
	var nodes_total := 0
	var failures := 0
	for file in DirAccess.get_files_at(MODELS_DIR):
		if not file.ends_with(".tscn"):
			continue
		if Time.get_ticks_msec() / 1000.0 - _started > LIMIT_S - 5.0:
			print("HANDS FAIL out of time before %s" % file)
			return 2
		var model := file.trim_suffix(".tscn")
		models += 1
		var found := _model(model)
		if found.is_empty():
			failures += 1
			continue
		if not (found["nodes"] as Array).is_empty():
			report[model] = {"nodes": found["nodes"]}
			nodes_total += (found["nodes"] as Array).size()
	var out := FileAccess.open(OUT, FileAccess.WRITE)
	if out == null:
		print("HANDS FAIL cannot write %s" % OUT)
		return 1
	out.store_string(JSON.stringify(report, "\t", true))
	out.close()
	print("HANDS models=%d with_hands=%d nodes=%d tracks=%d resets=%d" % [models, report.size(), nodes_total, _tracks, _resets])
	print("HANDS DONE" if failures == 0 else "HANDS FAIL %d models did not load" % failures)
	return 0 if failures == 0 else 1


## The hand nodes of one model ({nodes: [{name, bone, offset}]}), after writing its tracks. {} when the model does not load.
func _model(model: String) -> Dictionary:
	var scene := load(MODELS_DIR + model + ".tscn") as PackedScene
	var library := load(MODELS_DIR + model + "_clips.tres") as AnimationLibrary
	if scene == null or library == null:
		print("HANDS FAIL %s does not load" % model)
		return {}
	var table: Dictionary = _root_value(scene, &"clips")
	var nodes: Array[Dictionary] = []
	var roles_on: Dictionary = {}
	for role: StringName in library.get_animation_list():
		var hands: Array = (table.get(library.get_animation(role).resource_name, {}) as Dictionary).get("hands", [])
		for slot in mini(hands.size(), 2):
			var hand: Dictionary = hands[slot]
			if not bool(hand.get("on", false)):
				continue
			var hand_name := _name_of(nodes, slot, str(hand["bone_name"]), hand["offset"])
			var list: Array = roles_on.get(role, [])
			list.append(hand_name)
			roles_on[role] = list
	if nodes.is_empty():
		return {"nodes": []}
	_write_tracks(library, nodes, roles_on)
	var rows: Array[Dictionary] = []
	for node in nodes:
		var offset: Vector3 = node["offset"]
		rows.append({"name": node["name"], "bone": node["bone"], "offset": [offset.x, offset.y, offset.z]})
	return {"nodes": rows}


## The name of the hand node for (slot, bone, offset); a new one is added the first time it shows up.
func _name_of(nodes: Array[Dictionary], slot: int, bone: String, offset: Vector3) -> String:
	var same_slot := 0
	for node in nodes:
		if node["slot"] != slot:
			continue
		same_slot += 1
		if node["bone"] == bone and (node["offset"] as Vector3) == offset:
			return node["name"]
	var base := "HandL" if slot == 0 else "HandR"
	var chosen := base if same_slot == 0 else "%s%d" % [base, same_slot + 1]
	nodes.append({"name": chosen, "slot": slot, "bone": bone, "offset": offset})
	return chosen


## `visible = true` in the Animations that show a hand, and the RESET that hides them all; saves what changed.
func _write_tracks(library: AnimationLibrary, nodes: Array[Dictionary], roles_on: Dictionary) -> void:
	for role: StringName in roles_on:
		var anim := library.get_animation(role)
		var changed := false
		for hand_name: String in roles_on[role]:
			if _has_track(anim, hand_name):
				continue
			_add_visible(anim, hand_name, true)
			changed = true
			_tracks += 1
		if changed and not anim.resource_path.is_empty():
			ResourceSaver.save(anim, anim.resource_path)
	var reset := library.get_animation(RESET) if library.has_animation(RESET) else Animation.new()
	reset.length = RESET_LENGTH_S
	for node in nodes:
		if not _has_track(reset, node["name"]):
			_add_visible(reset, node["name"], false)
	if not library.has_animation(RESET):
		library.add_animation(RESET, reset)
		_resets += 1
	ResourceSaver.save(library, library.resource_path)


func _has_track(anim: Animation, hand_name: String) -> bool:
	return anim.find_track(NodePath(PATH % hand_name), Animation.TYPE_VALUE) >= 0


func _add_visible(anim: Animation, hand_name: String, shown: bool) -> void:
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(PATH % hand_name))
	anim.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	anim.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
	anim.track_insert_key(track, 0.0, shown)


## The value `property` has in the root node of a saved scene, read from its state without instancing it ({} when it has none).
func _root_value(scene: PackedScene, property: StringName) -> Dictionary:
	var state := scene.get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == property:
			return state.get_node_property_value(0, i)
	return {}
