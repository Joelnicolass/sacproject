class_name AnimModelAudit
extends RefCounted

## Debug: audits every role of ONE model scene (scenes/bodies/models/<tag>.tscn) against the type data of its owners
## (AnimExpect) and against the clip itself (AnimSampler). It reads the scene as a resource, with no tree: the rig is inert
## headless. `rows` get one entry per role the scene has; `unmapped` one per role the data names and the scene lacks.
## Checks: map, clip, rate, loop, seam, motion, finite, drift, hands. Each is [status, note], status PASS / WARN / FAIL.

## Roles that repeat (the wrap tells the state of the mode when to change the clip) and roles that hold their last frame.
const MUST_LOOP: PackedStringArray = ["idle", "run", "fly", "hover", "thrash", "cower", "talk_cower", "work", "gesture", "cast_run"]
const MUST_HOLD: PackedStringArray = ["death", "fly_death", "fall"]
const HAND_ROLES: PackedStringArray = ["cast", "cast_run", "shoot"]
## A bone that jumps more than this (share of the model's size) between the last frame and the first breaks the loop.
const SEAM_LIMIT := 0.05
## A clip whose bones move less than this (share of the model's size) reads as frozen.
const MOTION_MIN := 0.01
## An in-place loop whose root or hip sways further than this (share of the model's size) on the ground reads as sliding.
const SLIDE_LIMIT := 0.25
## An in-place loop whose root or hip is further than this (share of the model's size) from its first-frame place on the
## last frame pops back when it wraps.
const NET_LIMIT := 0.05
## A state whose custom timeline lasts at most this many frames is a held pose (the Sac Doctor's idle: IdleSway moves it).
const HOLD_FRAMES := 1.5
## What the game shows for a role the scene lacks, and whether that is right.
const FALLBACKS := {
	"attack2": "WRONG: plays attack; the sim picks this swing at random and times it by its own clip (MeleeAttack._pick_swing)",
	"attack3": "WRONG: plays attack; the sim picks this swing when the foe is lower and times it by slot 2",
	"shoot": "OK: plays idle; its shoot0 is a still two-frame placeholder (PC00, DZ00), so the bake gives no shoot role",
	"hit_floor": "WRONG-ish: idle + Tween tilt (Stunned) for the whole fall stun, no landing clip",
	"knock": "WRONG-ish: idle + Tween tilt (Stunned), the stun lasts the clip's frames",
	"get_up": "WRONG-ish: idle + Tween tilt (Stunned), the stun lasts the clip's frames",
	"fly_damage": "AMBIGUOUS: idle + Tween (Stunned)", "death": "AMBIGUOUS: Tween tip-over (Corpse)",
	"fly_death": "OK: falls back to death, else the Tween", "cast": "WRONG: idle (BodyRig)", "cast_run": "WRONG: idle (BodyRig)",
	"gesture": "OK if the bake dropped it on purpose (F376 slide rule): the body rests on idle",
}

var rows: Array[Dictionary] = []
var unmapped: Array[Dictionary] = []
## One entry per role the scene holds on a single frame on purpose (see _hold_frame): "sacd/idle (SDst frame 10)".
var holds := PackedStringArray()
var _model := ""
var _root: BodyModel
var _machine: AnimationNodeStateMachine
var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _size := 1.0
var _up := Vector3.UP
var _custom := false
var _wanted: Dictionary = {}
var _measures: Dictionary = {}


func audit(model: String, owners: Array) -> void:
	_model = model
	_root = (load(BodyModel.scene_path(model)) as PackedScene).instantiate() as BodyModel
	var rig := ClipSlide.rig_of(_root.get_node("%Model"))
	_machine = (_root.get_node("%Tree") as AnimationTree).tree_root as AnimationNodeStateMachine
	_size = maxf(0.1, maxf(_root.bind_aabb.size.x, maxf(_root.bind_aabb.size.y, _root.bind_aabb.size.z)))
	if rig.is_empty() or _machine == null:
		rows.append(_row("-", "", 0, {"clip": ["FAIL", "scene has no clip player, skeleton or state machine"]}))
		_root.free()
		return
	_player = rig[0]
	_skeleton = rig[1]
	_custom = _root.get_node("%Model").scene_file_path.begins_with("res://assets/custom/")
	var to_world := BodyCatalog.pose(model, false, true).basis * (_root.get_node("%Model") as Node3D).transform.basis
	_up = (to_world.inverse() * Vector3.UP).normalized()
	_collect_wanted(owners)
	for role in BodyModel.ROLES:
		if _machine.has_node(role):
			_audit_role(role)
	_find_unmapped()
	_root.free()


func _collect_wanted(owners: Array) -> void:
	for owner: Dictionary in owners:
		var roles := AnimExpect.roles_of(owner)
		for role: String in roles:
			if not _wanted.has(role):
				_wanted[role] = []
			(_wanted[role] as Array).append({"who": owner["who"], "entry": roles[role]})


func _audit_role(role: String) -> void:
	var node := _machine.get_node(role) as AnimationNodeAnimation
	var tag := _root.tag_for(role)
	var checks: Dictionary = {"map": _map(role, tag)}
	if not _player.has_animation(tag):
		checks["clip"] = ["FAIL", "clip %s is not in the .glb" % tag]
		rows.append(_row(role, tag, 0, checks))
		return
	var sampler := AnimSampler.new(_skeleton, _player.get_animation(tag), _custom)
	var frames := sampler.frames()
	var hold := _hold_frame(node, frames)
	if hold >= 0:
		_audit_hold(role, tag, hold, frames, checks)
		return
	checks["clip"] = _clip(role, tag, node, frames)
	checks["rate"] = _rate(tag)
	checks["loop"] = _loop(role, node)
	if not _measures.has(tag):
		_measures[tag] = sampler.measure(_up)
		_measures[tag]["keys_finite"] = sampler.keys_finite()
	var m: Dictionary = _measures[tag]
	checks["finite"] = ["PASS", ""] if bool(m["finite"]) and bool(m["keys_finite"]) else ["FAIL", "NaN or inf in the pose or the keys"]
	checks["motion"] = _motion(float(m["motion"]) / _size)
	if MUST_LOOP.has(role):
		checks["seam"] = _seam(float(m["seam"]) / _size, float(m["step"]) / _size)
		checks["drift"] = _drift(float(m["slide"]), float(m["net"]))
	if HAND_ROLES.has(role) and not _only_doctor(role):
		checks["hands"] = _hands(tag)
	rows.append(_row(role, tag, frames, checks))


## The frame a state holds (its custom timeline is about one frame long, starting at `start_offset`), -1 when it plays the clip.
func _hold_frame(node: AnimationNodeAnimation, frames: int) -> int:
	if not node.use_custom_timeline or node.timeline_length > HOLD_FRAMES / AnimSampler.FPS:
		return -1
	return clampi(roundi(node.start_offset * AnimSampler.FPS), 0, maxi(frames - 1, 0))


## A held pose is intentional: only the clip, the rate and the frame it holds are checked; the wrap checks (seam, drift,
## loop) do not apply to a pose that never plays.
func _audit_hold(role: String, tag: String, frame: int, frames: int, checks: Dictionary) -> void:
	checks["rate"] = _rate(tag)
	if frames <= 1:
		checks["clip"] = ["FAIL", "held clip %s has %d frame(s)" % [tag, frames]]
	else:
		checks["clip"] = ["PASS", ""]
		holds.append("%s/%s (%s frame %d of %d)" % [_model, role, tag, frame, frames])
	var m := _measures_of(tag)
	checks["finite"] = ["PASS", ""] if bool(m["finite"]) and bool(m["keys_finite"]) else ["FAIL", "NaN or inf in the pose or the keys"]
	rows.append(_row(role, tag, frames, checks))


func _measures_of(tag: String) -> Dictionary:
	if not _measures.has(tag):
		var sampler := AnimSampler.new(_skeleton, _player.get_animation(tag), _custom)
		_measures[tag] = sampler.measure(_up)
		_measures[tag]["keys_finite"] = sampler.keys_finite()
	return _measures[tag]


## The doctor's «cast» is its lift work, not a spell: no hands to check.
func _only_doctor(role: String) -> bool:
	for want: Dictionary in _wanted.get(role, []):
		if not str(want["who"]).begins_with("doctor"):
			return false
	return true


func _map(role: String, tag: String) -> Array:
	if not _wanted.has(role):
		return ["WARN", "the type data names no clip for this role"]
	var good := 0
	var notes := PackedStringArray()
	for want: Dictionary in _wanted[role]:
		var entry: Dictionary = want["entry"]
		if (entry["accept"] as PackedStringArray).has(tag):
			good += 1
			if role == "idle" and tag != entry["tag"] and _player.has_animation(entry["tag"]):
				return ["WARN", "rests on %s though stance1 %s exists (%s)" % [tag, entry["tag"], want["who"]]]
		else:
			notes.append("%s wants %s" % [want["who"], entry["tag"]])
	if good == 0:
		return ["FAIL", "plays %s; %s" % [tag, ", ".join(notes)]]
	return ["PASS", ""] if notes.is_empty() else ["WARN", "shared model, %s" % ", ".join(notes)]


func _clip(role: String, tag: String, node: AnimationNodeAnimation, frames: int) -> Array:
	if frames <= 1:
		return ["FAIL", "%d frame(s)" % frames]
	for want: Dictionary in _wanted.get(role, []):
		var entry: Dictionary = want["entry"]
		if entry["tag"] == tag and int(entry["frames"]) > 0 and int(entry["frames"]) != frames:
			return ["FAIL", "%s data says %d frames, the clip has %d" % [want["who"], entry["frames"], frames]]
	var anim := _root.clips_player().get_animation(node.animation)
	if absf(anim.length - float(frames) / AnimSampler.FPS) > 0.002:
		return ["FAIL", "library length %.3f s, want %.3f s" % [anim.length, float(frames) / AnimSampler.FPS]]
	if node.use_custom_timeline:
		return ["FAIL", "the state keeps a custom timeline: the Animation of the library carries the length"]
	return ["PASS", ""]


func _rate(tag: String) -> Array:
	var step := _player.get_animation(tag).step
	if absf(step - 1.0 / 30.0) > 0.0005:
		return ["FAIL", "step %.4f, want %.4f (30 fps)" % [step, 1.0 / 30.0]]
	return ["PASS", ""]


func _loop(role: String, node: AnimationNodeAnimation) -> Array:
	var mode := _root.clips_player().get_animation(node.animation).loop_mode
	if MUST_HOLD.has(role) and mode != Animation.LOOP_NONE:
		return ["FAIL", "should hold its last frame but repeats"]
	if MUST_LOOP.has(role) and mode == Animation.LOOP_NONE:
		return ["FAIL", "should repeat but plays once"]
	if BodyModel.ONE_SHOT_ROLES.has(role) and mode != Animation.LOOP_NONE:
		return ["FAIL", "one-shot whose Animation repeats: it would never go back to idle"]
	if BodyModel.ONE_SHOT_ROLES.has(role) and not _returns_to_idle(role):
		return ["FAIL", "one-shot with no automatic transition back to idle"]
	return ["PASS", ""]


func _returns_to_idle(role: String) -> bool:
	for i in _machine.get_transition_count():
		if _machine.get_transition_from(i) == StringName(role) and _machine.get_transition_to(i) == &"idle":
			return _machine.get_transition(i).switch_mode == AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	return false


func _seam(seam: float, step: float) -> Array:
	if seam > SEAM_LIMIT and seam > step * 1.5:
		return ["WARN", "seam %.1f%% of size (one frame moves %.1f%%)" % [seam * 100.0, step * 100.0]]
	return ["PASS", "seam %.1f%%" % (seam * 100.0) if seam > SEAM_LIMIT else ""]


func _drift(slide: float, net: float) -> Array:
	if net / _size > NET_LIMIT:
		return ["WARN", "root/hip pops %.2f m at the wrap (%.0f%% of size)" % [net, net / _size * 100.0]]
	if slide / _size > SLIDE_LIMIT:
		return ["WARN", "root/hip sways %.2f m (%.0f%% of size)" % [slide, slide / _size * 100.0]]
	return ["PASS", ""]


func _motion(share: float) -> Array:
	if share <= 0.0:
		return ["FAIL", "no bone moves"]
	return ["WARN", "moves %.2f%% of size" % (share * 100.0)] if share < MOTION_MIN else ["PASS", ""]


func _hands(tag: String) -> Array:
	var hands: Array = _root.hands_of(tag)
	var on := 0
	for hand: Dictionary in hands:
		if bool(hand.get("on", false)):
			on += 1
			if _skeleton.find_bone(str(hand.get("bone_name", ""))) < 0 or not (hand["offset"] as Vector3).is_finite():
				return ["FAIL", "hand bone %s missing or offset not finite" % hand.get("bone_name", "")]
	return ["PASS", ""] if on > 0 else ["WARN", "no hand point (both on the root bone)"]


func _find_unmapped() -> void:
	for role: String in _wanted:
		if _machine.has_node(role) or not BodyModel.ROLES.has(role):
			continue
		for want: Dictionary in _wanted[role]:
			var tag: String = want["entry"]["tag"]
			if _player.has_animation(tag) and AnimSampler.new(_skeleton, _player.get_animation(tag), _custom).frames() > 1:
				unmapped.append({"model": _model, "role": role, "tag": tag, "who": want["who"], "fallback": FALLBACKS.get(role, "idle (BodyRig)"),
					"detail": _gesture_detail(tag) if role == "gesture" else ""})
				break


## The bake drops the gesture when ClipSlide (the skeleton's X and Z) says it slides; the same clip measured on the ground.
func _gesture_detail(tag: String) -> String:
	var animation := _player.get_animation(tag)
	var bake_says := float(ClipSlide.measure(_player, _skeleton, animation)["slide"])
	var ground := float(AnimSampler.new(_skeleton, animation, _custom).measure(_up)["slide"])
	return "bake %.2f m, ground %.2f m" % [bake_says, ground]


func _row(role: String, tag: String, frames: int, checks: Dictionary) -> Dictionary:
	var status := "PASS"
	for check: Array in checks.values():
		if check[0] == "FAIL":
			status = "FAIL"
		elif check[0] == "WARN" and status != "FAIL":
			status = "WARN"
	return {"model": _model, "role": role, "tag": tag, "frames": frames, "checks": checks, "status": status}
