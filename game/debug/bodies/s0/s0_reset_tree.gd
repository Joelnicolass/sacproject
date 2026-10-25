extends SceneTree
## 055s s0 (disposable), question 4: in Godot 4.7, does an AnimationTree (state machine, one state per role) bring a property
## that only SOME roles animate back to its RESET value when a role without that track plays?
## The plan's case: `Skeleton3D/HandL:visible` is a track only in the roles with a hand (`true`); RESET holds `false`.
## Two variants: `with_reset` (an Animation named RESET with visible=false) and `no_reset` (none; the node starts invisible).
## Prints `S0 4 ...` and `S0 VERDICT reset_tree ...`. Always ends in quit().

const STEPS: Array = [
	["idle", false], ["cast", true], ["run", false], ["idle", false], ["cast", true], ["idle", false], ["cast", true], ["run", false],
]
const SETTLE_FRAMES := 5

var _variant := "with_reset"
var _variants: Array[String] = ["with_reset", "no_reset"]
var _body: Node3D
var _hand: Node3D
var _tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var _step := -1
var _frames := 0
var _failures := 0
var _total := 0
var _by_variant := {}


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("S0 VERDICT reset_tree TIMEOUT")
		quit(2))
	_build(_variants[0])


func _process(_delta: float) -> bool:
	if _tree == null:
		return false
	_tree.advance(0.1)
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return false
	if _step >= 0:
		var want: bool = STEPS[_step][1]
		var got := _hand.visible
		_total += 1
		if got != want:
			_failures += 1
		print("S0 4 %s role=%s hand.visible=%s expected=%s %s" % [_variant, str(STEPS[_step][0]), got, want, "ok" if got == want else "MISMATCH"])
	_step += 1
	_frames = 0
	if _step >= STEPS.size():
		return _next_variant()
	_playback.travel(StringName(STEPS[_step][0]))
	return false


func _next_variant() -> bool:
	_by_variant[_variant] = _failures
	_failures = 0
	_body.free()
	_tree = null
	var idx := _variants.find(_variant)
	if idx + 1 < _variants.size():
		_build(_variants[idx + 1])
		return false
	# Judgement: the plan expects `with_reset` to return to RESET. `no_reset` is information only.
	var ok: bool = _by_variant.get("with_reset", 1) == 0
	print("S0 4 mismatches with_reset=%s no_reset=%s (no_reset is information: does the node return to its initial value without a RESET animation?)" % [str(_by_variant.get("with_reset")), str(_by_variant.get("no_reset"))])
	print("S0 VERDICT reset_tree %s" % ("PASS the Tree returns hand.visible to RESET on roles without the track" if ok else "FAIL a role without the track kept the hand: write the explicit false key in every role without hand (plan question 9)"))
	quit(0 if ok else 1)
	return true


func _anim(track_visible: Variant, with_motion: bool) -> Animation:
	var a := Animation.new()
	a.length = 0.5
	if with_motion:
		var t := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t, NodePath(".:position:x"))
		a.track_insert_key(t, 0.0, 0.0)
		a.track_insert_key(t, 0.5, 1.0)
	if track_visible != null:
		var v := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(v, NodePath("Skeleton3D/HandL:visible"))
		a.value_track_set_update_mode(v, Animation.UPDATE_DISCRETE)
		a.track_insert_key(v, 0.0, track_visible)
	return a


func _build(variant: String) -> void:
	_variant = variant
	_body = Node3D.new()
	_body.name = "Body"
	var sk := Node3D.new()
	sk.name = "Skeleton3D"
	_body.add_child(sk)
	_hand = Node3D.new()
	_hand.name = "HandL"
	_hand.visible = variant != "no_reset"
	sk.add_child(_hand)
	var player := AnimationPlayer.new()
	player.name = "Clips"
	_body.add_child(player)
	var lib := AnimationLibrary.new()
	if variant == "with_reset":
		lib.add_animation(&"RESET", _anim(false, false))
	lib.add_animation(&"idle", _anim(null, true))
	lib.add_animation(&"run", _anim(null, true))
	lib.add_animation(&"cast", _anim(true, true))
	player.add_animation_library(&"", lib)
	_tree = AnimationTree.new()
	_tree.name = "Tree"
	_body.add_child(_tree)
	var sm := AnimationNodeStateMachine.new()
	var roles: Array[StringName] = [&"idle", &"run", &"cast"]
	for r in roles:
		var n := AnimationNodeAnimation.new()
		n.animation = r
		sm.add_node(r, n)
	for a in roles:
		for b in roles:
			if a != b:
				var tr := AnimationNodeStateMachineTransition.new()
				tr.xfade_time = 0.0
				sm.add_transition(a, b, tr)
	var start_tr := AnimationNodeStateMachineTransition.new()
	start_tr.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition(&"Start", &"idle", start_tr)
	_tree.tree_root = sm
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	root.add_child(_body)
	_tree.anim_player = _tree.get_path_to(player)
	_tree.active = true
	_playback = _tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	_step = -1
	_frames = 0
	_failures = 0
	if _playback == null:
		print("S0 VERDICT reset_tree ERROR no playback object")
		quit(1)
		return
	print("S0 4 variant=%s tree.deterministic=%s hand starts visible=%s" % [variant, str(_tree.get("deterministic")), _hand.visible])
