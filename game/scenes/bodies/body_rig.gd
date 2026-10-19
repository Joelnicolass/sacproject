@tool
class_name BodyRig
extends Node3D

## RFC-023 (023b) / RFC-036 (036g): a skeletal body of the original game. It instances the model's scene
## (scenes/bodies/models/<model>.tscn, a BodyModel: the .glb, its AnimationTree with one state per ROLE and the clip events)
## under %ModelSlot and plays ROLES (idle, run, attack...) through that tree. Which clip a role plays, and how the animations
## look, is edited in the model's scene in the editor; this node only asks the tree to travel to a role.
## Without the scene (a model that is a static mesh) the rig shows nothing and warns in the inspector; no error.
## On the dedicated server (headless) nothing loads: the rig is inert.
## Presentation only: the simulation never reads the rig.

## The two hand sockets follow the skeleton of the instanced model; the .glb is drawn with z mirrored (BodyModel).
const MIRROR := Vector3(1.0, 1.0, -1.0)

## Body to show (a model tag: eorc, jnwr...). The owner sets it at run time; in the editor it is the preview.
@export var model := "":
	set(value):
		model = value
		_reload_if_ready()
## Role shown after loading (the editor preview and the starting role).
@export var preview_role := "idle":
	set(value):
		preview_role = value
		if is_node_ready() and _model_root != null:
			play(value)

var _model_root: BodyModel
var _skeleton: Skeleton3D
var _fade := 0.0
var _paused := false
var _role := ""
var _missing := false
## Which of the two hand sockets the active clip really has (a hand on the root bone is "no hand": sacengine leaves it NaN).
var _hand_on: Array[bool] = [false, false]

@onready var _slot: Node3D = %ModelSlot
@onready var _hand_l: BoneAttachment3D = %HandL
@onready var _hand_r: BoneAttachment3D = %HandR


func _ready() -> void:
	if not BodyCatalog.loads_meshes():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_reload()


## True when `role` has a clip in the loaded model.
func has_role(role: String) -> bool:
	return _model_root != null and _model_root.has_role(role)


## The role that will play for `role`: itself, or idle when the model has no clip for it.
func resolve_role(role: String) -> String:
	return role if has_role(role) else "idle"


func active_role() -> String:
	return _role


## Clip tag, frame count and framerate of a role of the loaded model.
func role_tag(role: String) -> String:
	return _model_root.tag_for(resolve_role(role)) if _model_root != null else ""


func role_frames(role: String) -> int:
	return _model_root.frames_of(role_tag(role)) if _model_root != null else 0


func role_framerate(role: String) -> float:
	return _model_root.framerate_of(role_tag(role)) if _model_root != null else 30.0


## Seconds into the active clip (within the pass the state machine is in); 0 when nothing plays.
func play_position() -> float:
	var playback := _playback()
	return playback.get_current_play_position() if playback != null and _model_root.tree().active else 0.0


## The frame of the active clip's first attack event (the strike lands on it), -1 without one.
func impact_frame() -> int:
	return _model_root.impact_frame(role_tag(_role)) if _model_root != null and not _role.is_empty() else -1


func skeleton() -> Skeleton3D:
	return _skeleton


func is_loaded() -> bool:
	return _model_root != null


## World positions of the hands the active clip has (RFC-023 023d: where a wizard's casting particles go). Empty when the
## clip has none or the model is not loaded.
func hand_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	if _skeleton == null:
		return points
	var sockets := [_hand_l, _hand_r]
	for i in 2:
		if _hand_on[i]:
			points.append((sockets[i] as BoneAttachment3D).get_node("Socket").global_position)
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
	_model_root.events_player().callback_mode_process = mode


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
	_apply_hands(wanted)
	_play_events(wanted)
	if at > 0.0:
		tree.advance(at)


## Holds the body at `seconds` of `role`'s clip, outside the state machine (comparisons and captures). The skeleton
## starts from its rest pose first: the glTF importer drops constant tracks equal to the rest, so a bone the clip
## does not animate would keep the previous clip's pose.
func pose_at(role: String, seconds: float) -> void:
	if _model_root == null:
		return
	var wanted := resolve_role(role)
	var player := _model_root.clip_player()
	_model_root.tree().active = false
	_model_root.events_player().stop()
	_skeleton.reset_bone_poses()
	player.play(_model_root.tag_for(wanted))
	player.seek(seconds, true)
	player.pause()
	_role = wanted
	_apply_hands(wanted)


## Steps the state machine by hand (tests and, later, a body-LOD that updates far bodies less often).
func advance(delta: float) -> void:
	if _model_root != null and _model_root.tree().active:
		_model_root.tree().advance(delta)


## Sets the model and loads it.
func set_body(model_tag: String) -> void:
	model = model_tag


func _playback() -> AnimationNodeStateMachinePlayback:
	if _model_root == null:
		return null
	return _model_root.tree().get(BodyModel.PLAYBACK) as AnimationNodeStateMachinePlayback


## Stops the .glb's own player only when it holds a clip (pose_at left it paused): stop() seeks it.
func _stop_player() -> void:
	var player := _model_root.clip_player() if _model_root != null else null
	if player != null and not player.assigned_animation.is_empty():
		player.stop()


## The Events player runs the method tracks (ClipEvents.fire) of the clip a role plays, from its start.
func _play_events(role: String) -> void:
	var events := _model_root.events_player()
	var tag := _model_root.tag_for(role)
	if events.has_animation(tag):
		events.play(tag)
	else:
		events.stop()


func _reload_if_ready() -> void:
	if is_node_ready() and BodyCatalog.loads_meshes():
		_reload()


func _reload() -> void:
	_clear()
	_missing = false
	if model.is_empty():
		update_configuration_warnings()
		return
	if not BodyModel.exists(model):
		_missing = true
		update_configuration_warnings()
		return
	var packed := load(BodyModel.scene_path(model)) as PackedScene
	var root := packed.instantiate() as BodyModel if packed != null else null
	if root == null:
		_missing = true
		update_configuration_warnings()
		return
	_slot.add_child(root)
	_model_root = root
	_skeleton = root.skeleton()
	set_fade(_fade)
	set_paused(_paused)
	_bind_hands()
	update_configuration_warnings()
	play(preview_role, true)


func _clear() -> void:
	for attach in [_hand_l, _hand_r]:
		attach.use_external_skeleton = false
		attach.external_skeleton = NodePath()
	_hand_on = [false, false]
	for child in _slot.get_children():
		_slot.remove_child(child)
		child.free()
	_model_root = null
	_skeleton = null
	_role = ""


## The hand attachments follow the skeleton of the instanced model; their bone changes with the clip.
func _bind_hands() -> void:
	for attach in [_hand_l, _hand_r]:
		# Start on the root bone: the bone name of the previous model may not exist in this skeleton.
		attach.bone_name = _skeleton.get_bone_name(0)
		attach.use_external_skeleton = true
		attach.external_skeleton = attach.get_path_to(_skeleton)
		(attach.get_node("Socket") as Node3D).scale = MIRROR


func _apply_hands(role: String) -> void:
	if _skeleton == null:
		return
	var hands: Array = _model_root.clip_data(_model_root.tag_for(role)).get("hands", [])
	var attachments := [_hand_l, _hand_r]
	_hand_on = [false, false]
	for i in mini(hands.size(), 2):
		var attach: BoneAttachment3D = attachments[i]
		var hand: Dictionary = hands[i]
		_hand_on[i] = bool(hand.get("on", false))
		if attach.bone_name != str(hand["bone_name"]):
			attach.bone_name = str(hand["bone_name"])
		(attach.get_node("Socket") as Node3D).position = hand["offset"]


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if _missing:
		warnings.append("No scene %s: bake it with tools/bake_body_scenes.gd (a model with no playable idle clip is a static mesh)." % BodyModel.scene_path(model))
	return warnings
