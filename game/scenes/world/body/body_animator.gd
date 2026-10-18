class_name BodyAnimator
extends ClipPlayback

## RFC-023 (023c): plays the clips of a creature unit by ROLE. It owns a ClipClock (role, frame, impact; no mesh, so the
## dedicated server runs it too) and, on a client, makes the body show what the clock says: the BodyRig under the
## visual travels to the clock's role (and seeks when it arrives late). The clock never reads the rig.
## A model with no skeletal asset, or that did not close against the original (BodyCatalog.SKELETAL_FALLBACK), keeps the
## baked per-frame meshes: a ClipPosePlayer made at run time that only draws, while the clock stays the one reading.
## Presentation only: the simulation takes its ticks from CreatureType and never reads this node.

## The body's visual (Tilt/Mesh). Its `rig` is the BodyRig that draws the skeleton; it has the pose and the measures.
@export var visual: BodyVisual

var _clock := ClipClock.new()
var _model := ""
var _roles: Dictionary = {}
var _base_pos := Vector3.ZERO
var _base_rot := Vector3.ZERO
var _skeletal := false
## What the rig was told to play (the clock's role, or "idle" when it has none).
var _shown_role := ""
var _baked: ClipPosePlayer


func _ready() -> void:
	_clock.looped.connect(clip_looped.emit)


## One tick per physics frame, on every peer. Bodies only choose the role with play(): they must not advance too.
func _physics_process(delta: float) -> void:
	_clock.advance(delta)


func setup(model: String, role_to_tag: Dictionary, mesh_base_pos: Vector3, mesh_base_rot: Vector3) -> void:
	_base_pos = mesh_base_pos
	_base_rot = mesh_base_rot
	if model == _model and role_to_tag == _roles:
		return
	_model = model
	_roles = role_to_tag.duplicate()
	_clock.setup(model, _roles)
	_choose_body()


func play(role: String, restart := false) -> void:
	if frozen:
		return
	_clock.play(role, restart)
	if _baked != null:
		_baked.play(role, restart)
	_follow(restart)


## Plays `role` with the skeleton already on its last frame (a corpse that a late peer sees on the ground). The clock
## starts the clip as usual: only the draw jumps to the end.
func play_ended(role: String) -> void:
	play(role, true)
	var rig := _rig()
	if not _skeletal or rig == null or not rig.is_loaded() or _clock.active_role().is_empty():
		return
	rig.play(role, true, float(rig.role_frames(role)) / maxf(rig.role_framerate(role), 1.0) + 0.5)


func active_role() -> String:
	return _clock.active_role()


func has_role(role: String) -> bool:
	return _clock.has_role(role)


func has_clip(model: String, tag: String) -> bool:
	return ClipClock.has_clip(model, tag)


func active_tag() -> String:
	return _clock.active_tag()


func active_framerate() -> int:
	return _clock.active_framerate()


func active_frame() -> int:
	return _clock.active_frame()


func impact_frame() -> int:
	return _clock.impact_frame()


## true while the skeleton (a BodyRig) is what draws this body.
func is_skeletal() -> bool:
	return _skeletal


func _frozen_changed() -> void:
	_clock.frozen = frozen
	if _baked != null:
		_baked.frozen = frozen
	var rig := _rig()
	if rig != null:
		rig.set_paused(frozen)


func _rig() -> BodyRig:
	return visual.rig if visual != null else null


## Skeleton or baked meshes for the model just set. The dedicated server draws neither: it keeps the clock only.
func _choose_body() -> void:
	if not BodyCatalog.loads_meshes() or visual == null:
		return
	var rig := _rig()
	var idle_tag := str(_roles.get("idle", ""))
	_skeletal = rig != null and BodyCatalog.has_skeletal(_model) and ClipClock.has_clip(_model, idle_tag)
	visual.use_skeleton(_skeletal)
	if _skeletal:
		if _baked != null:
			_baked.queue_free()
			_baked = null
		_shown_role = ""
		rig.set_body(_model, BodyClips.from_roles(_model, _roles))
		_follow()
		return
	if rig != null:
		rig.set_body("", null)
	if _baked == null:
		_baked = ClipPosePlayer.new()
		_baked.name = "Baked"
		# It is a child of this node: the visual is found from here, before the player's own _ready looks for it.
		_baked.mesh_path = NodePath("../" + str(get_path_to(visual)))
		add_child(_baked)
	_baked.frozen = frozen
	_baked.setup(_model, _roles, _base_pos, _base_rot)
	var role := _clock.active_role()
	if not role.is_empty():
		_baked.play(role)


## Makes the rig show the clock's role. A role the model has no clip for rests on idle (the clock holds ""). When the
## model has just loaded and the clock is already inside a pass, the clip starts where the clock is.
func _follow(restart := false) -> void:
	var rig := _rig()
	if not _skeletal or rig == null or not rig.is_loaded():
		return
	var role := _clock.active_role()
	if role.is_empty():
		role = "idle"
	if role == _shown_role and not restart:
		return
	var late := _shown_role.is_empty()
	_shown_role = role
	# A restart (or the first role after loading) starts the clip; any other change travels with the state machine's blend.
	rig.play(role, restart or late, _clock.time_s() if late else 0.0)
