@tool
class_name BodyRig
extends Node3D

## A skeletal body: it holds the look the body wears (BodyMount hands it over: the model's scene scenes/bodies/models/<model>.tscn, a
## BodyModel with the .glb, its library of clips by role and the AnimationTree with one state per ROLE) under %ModelSlot and plays
## ROLES (idle, run, attack...) through that tree. Which clip a role plays, and how the animations look, is edited in the model's
## scene in the editor; this node only asks the tree to travel to a role.
## A look without a model (a hybrid drawn as a static mesh) is held too, and nothing plays.
## On the dedicated server (headless) nothing is mounted: the rig is inert.
## Presentation only: the simulation never reads the rig (it reads the same clips through ClipFacts).
## Ref: RFC-023 (023b), RFC-036 (036g).

## A look with a model was mounted under the rig (its skeleton and sockets exist now).
signal model_loaded
## A look was mounted (with or without a model): whoever draws the body can pick its mesh or its skeleton.
signal look_mounted(look: BodyLook)

## Role shown after loading (the editor preview and the starting role).
@export var preview_role := "idle":
	set(value):
		preview_role = value
		if is_node_ready() and _model_root != null:
			play(value)

var _look: BodyLook
var _pending: BodyLook
var _model_root: BodyModel
var _skeleton: Skeleton3D
var _fade := 0.0
var _paused := false
var _role := ""
## The hands of the model (BoneAttachment3D named Hand*) and the Marker3D under each: a hand shows only in the clips that have it.
var _hands: Array[BoneAttachment3D] = []
var _sockets: Array[Node3D] = []

@onready var _slot: Node3D = %ModelSlot


func _ready() -> void:
	if not BodyLook.loads_meshes():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	if _pending != null:
		var waiting := _pending
		_pending = null
		_adopt(waiting)


## Puts `look` under the rig, in place of the one it had. Safe before the rig is ready: the look waits for it.
func mount(look: BodyLook) -> void:
	if not is_node_ready():
		if _pending != null:
			_pending.free()
		_pending = look
		return
	_adopt(look)


## The look mounted now (null before one is).
func mounted_look() -> BodyLook:
	return _look


## True when `role` has a clip in the loaded model.
func has_role(role: String) -> bool:
	return _model_root != null and _model_root.has_role(role)


## The role that will play for `role`: itself, or idle when the model has no clip for it.
func resolve_role(role: String) -> String:
	return role if has_role(role) else "idle"


func active_role() -> String:
	return _role


## Clip tag (the .glb's), frame count and framerate of a role of the loaded model.
func role_tag(role: String) -> String:
	return _model_root.tag_for(resolve_role(role)) if _model_root != null else ""


func role_frames(role: String) -> int:
	return _model_root.frames_of(resolve_role(role)) if _model_root != null else 0


func role_framerate(role: String) -> float:
	return _model_root.framerate_of(resolve_role(role)) if _model_root != null else 30.0


## Seconds into the active clip (within the pass the state machine is in); 0 when nothing plays.
func play_position() -> float:
	var playback := _playback()
	return playback.get_current_play_position() if playback != null and _model_root.tree().active else 0.0


## The frame of the active clip's first `hit` marker (the strike lands on it), -1 without one.
func impact_frame() -> int:
	return _model_root.impact_frame(_role) if _model_root != null and not _role.is_empty() else -1


## The node the model scene gives for the sprite effect a creature carries (BodyModel.carried_fx_socket); null without one.
func carried_fx_socket() -> Node3D:
	return _model_root.carried_fx_socket if _model_root != null else null


func skeleton() -> Skeleton3D:
	return _skeleton


func is_loaded() -> bool:
	return _model_root != null


## World positions of the hands the active clip has (RFC-023 023d: where a wizard's casting particles go). A hand shows only in the
## clips that have it (a `visible` track of the clip), so these are the sockets whose hand is visible now. Empty when the clip has none
## or the model is not loaded.
func hand_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in _hands.size():
		if _hands[i].visible:
			points.append(_sockets[i].global_position)
	return points


## The instanced model scene (null before it loads); what changes when the rig loads another one.
func model_root() -> BodyModel:
	return _model_root


## The skinned MeshInstance3D nodes of the loaded model (empty before it loads): what StoneLook dresses and set_fade fades.
func skinned_meshes() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if _model_root != null:
		for node in _model_root.find_children("*", "MeshInstance3D", true, false):
			found.append(node as MeshInstance3D)
	return found


## GeometryInstance3D.transparency of the whole body (0 opaque, 1 invisible). It does not inherit, so it goes mesh by mesh;
## a model that loads later gets it too.
func set_fade(value: float) -> void:
	_fade = value
	for mesh in skinned_meshes():
		mesh.transparency = value


## Holds the pose (a petrified body) or lets it move again.
func set_paused(on: bool) -> void:
	_paused = on
	if _model_root == null:
		return
	var mode := AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if on else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	_model_root.tree().callback_mode_process = mode


## Plays `role` through the state machine (travel: it blends with xfade). `restart` starts it again from frame 0.
## `at` > 0 moves the new clip that many seconds in (a body that shows up when its clip is already running).
func play(role: String, restart := false, at := 0.0) -> void:
	if _model_root == null:
		return
	var tree := _model_root.tree()
	var wanted := resolve_role(role)
	if wanted == _role and not restart and tree.active:
		return
	var first := _role.is_empty() or not tree.active
	_stop_player()
	tree.active = true
	var playback := _playback()
	if playback == null:
		return
	if restart or first:
		playback.start(wanted, true)
	else:
		playback.travel(wanted)
	_role = wanted
	if at > 0.0:
		tree.advance(at)


## Holds the body at `seconds` of `role`'s clip, outside the state machine (comparisons and captures). The skeleton
## starts from its rest pose first: the glTF importer drops constant tracks equal to the rest, so a bone the clip
## does not animate would keep the previous clip's pose.
func pose_at(role: String, seconds: float) -> void:
	if _model_root == null:
		return
	var wanted := resolve_role(role)
	var player := _model_root.clips_player()
	_model_root.tree().active = false
	_skeleton.reset_bone_poses()
	player.play(_model_root.animation_for(wanted))
	player.seek(seconds, true)
	player.pause()
	_role = wanted


## Steps the state machine by hand (tests and, later, a body-LOD that updates far bodies less often).
func advance(delta: float) -> void:
	if _model_root != null and _model_root.tree().active:
		_model_root.tree().advance(delta)


func _playback() -> AnimationNodeStateMachinePlayback:
	if _model_root == null:
		return null
	return _model_root.tree().get(BodyModel.PLAYBACK) as AnimationNodeStateMachinePlayback


## Stops the clips player only when it holds a clip (pose_at left it paused): stop() seeks it.
func _stop_player() -> void:
	var player := _model_root.clips_player() if _model_root != null else null
	if player != null and not player.assigned_animation.is_empty():
		player.stop()


func _adopt(look: BodyLook) -> void:
	_clear()
	_look = look
	_slot.add_child(look)
	_model_root = look.model
	if _model_root != null:
		_skeleton = _model_root.skeleton()
		_collect_hands()
	set_fade(_fade)
	set_paused(_paused)
	if _model_root != null:
		play(preview_role, true)
	look_mounted.emit(look)
	if _model_root != null:
		model_loaded.emit()


func _clear() -> void:
	for child in _slot.get_children():
		_slot.remove_child(child)
		child.free()
	_hands.clear()
	_sockets.clear()
	_look = null
	_model_root = null
	_skeleton = null
	_role = ""


## The hands are nodes of the model scene (BoneAttachment3D HandL, HandR... under its skeleton), placed in the editor.
func _collect_hands() -> void:
	for child in _skeleton.get_children():
		var hand := child as BoneAttachment3D
		var socket := hand.get_child(0) as Node3D if hand != null and hand.get_child_count() > 0 else null
		if socket != null and String(hand.name).begins_with("Hand"):
			_hands.append(hand)
			_sockets.append(socket)
