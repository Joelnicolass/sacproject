class_name BodyAnimator
extends ClipPlayback

## Plays the clips of a creature unit by ROLE. The body picks the role (from its replicated mode)
## with play(); on a client this node makes the BodyRig under the visual travel to it. The animation
## tree of the model's scene does the rest, and clip_looped is emitted when the clip the rig plays
## wraps. A look with no model (the hybrids, which are static meshes) is not drawn by the rig: the
## visual shows the mesh of the look. The dedicated server mounts no look, so it plays nothing and
## reports no clips and no loops; nothing in the simulation depends on that.
## It listens to the rig: whenever BodyMount hands the rig a look, this node tells the visual what
## to draw and starts the wanted role.
## Presentation only: the simulation takes its ticks from CreatureType and never reads this node.

## The body's visual (Tilt/Mesh). Its `rig` is the BodyRig that draws the skeleton; it has the pose
## and the measures.
@export var visual: BodyVisual

var _skeletal := false
## The role the body asked for.
var _wanted := ""
## What the rig was told to play (the wanted role, or "idle" when the model has no clip for it).
var _shown_role := ""
## Wrap detection: the role and the seconds into its clip at the last physics tick.
var _seen_role := ""
var _seen_pos := 0.0


## One tick per physics frame on a client: the clip wrapped when its position went back while the
## role stayed.
func _physics_process(_delta: float) -> void:
	var rig := _rig()
	if not _skeletal or frozen or rig == null or not rig.is_loaded():
		return
	var role := rig.active_role()
	var pos := rig.play_position()
	if role == _seen_role and pos < _seen_pos - 0.001:
		clip_looped.emit(role)
	_seen_role = role
	_seen_pos = pos


func _ready() -> void:
	var rig := _rig()
	if rig == null:
		return
	rig.look_mounted.connect(_on_look_mounted)
	var mounted := rig.mounted_look()
	if mounted != null:
		_on_look_mounted(mounted)


func play(role: String, restart := false) -> void:
	if frozen:
		return
	_wanted = role
	_follow(restart)


## Plays `role` with the skeleton already on its last frame (a corpse that a late peer sees on the
## ground).
func play_ended(role: String) -> void:
	play(role, true)
	var rig := _rig()
	if not _skeletal or rig == null or not rig.is_loaded() or active_role().is_empty():
		return
	rig.play(role, true, float(rig.role_frames(role)) / maxf(rig.role_framerate(role), 1.0) + 0.5)


## The role the body asked for, "" when the model has no clip for it.
func active_role() -> String:
	return _wanted if has_role(_wanted) else ""


func has_role(role: String) -> bool:
	var rig := _rig()
	return _skeletal and rig != null and rig.has_role(role)


func active_tag() -> String:
	var rig := _rig()
	return (
		rig.role_tag(active_role())
		if _skeletal and rig != null and not active_role().is_empty()
		else ""
	)


func active_framerate() -> int:
	var rig := _rig()
	return (
		int(rig.role_framerate(active_role()))
		if _skeletal and rig != null and not active_role().is_empty()
		else 0
	)


## Frame of the clip the rig is in (from the tree's position).
func active_frame() -> int:
	var rig := _rig()
	if not _skeletal or rig == null or active_role().is_empty():
		return 0
	var frames := rig.role_frames(active_role())
	return int(rig.play_position() * rig.role_framerate(active_role())) % maxi(frames, 1)


func impact_frame() -> int:
	var rig := _rig()
	return rig.impact_frame() if _skeletal and rig != null else -1


## true while the skeleton (a BodyRig) is what draws this body.
func is_skeletal() -> bool:
	return _skeletal


func _frozen_changed() -> void:
	var rig := _rig()
	if rig != null:
		rig.set_paused(frozen)


func _rig() -> BodyRig:
	return visual.rig if visual != null else null


## A look was mounted: a skeleton or the visual's own static mesh draws it. The dedicated server
## mounts none.
func _on_look_mounted(look: BodyLook) -> void:
	if visual == null:
		return
	_skeletal = look.has_model()
	visual.draw_look(look)
	_shown_role = ""
	_seen_role = ""
	_follow()


## Makes the rig show the wanted role. A role the model has no clip for rests on idle.
func _follow(restart := false) -> void:
	var rig := _rig()
	if not _skeletal or rig == null or not rig.is_loaded():
		return
	var role := _wanted if not _wanted.is_empty() else "idle"
	if role == _shown_role and not restart:
		return
	var late := _shown_role.is_empty()
	_shown_role = role
	# A restart (or the first role after loading) starts the clip; any other change travels with the
	# state machine's blend.
	rig.play(role, restart or late)
	_seen_role = ""
