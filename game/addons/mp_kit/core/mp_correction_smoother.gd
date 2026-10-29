class_name MpCorrectionSmoother
extends RefCounted

## Owner with prediction: hides the jump of a server correction (a knockback, a stun the client did not predict),
## as Source's cl_smoothtime, Photon Fusion's KCC and Unity Netcode's prediction smoothing do: only the drawn pose is
## smoothed. The node itself goes to the corrected pose at once, so its physics, mp_move and the server never see an
## offset; what is drawn carries the error, which fades out over about `time_s`. MpActor draws it (in _process, or
## at the end of each physics tick when the engine's physics interpolation is on) and puts the real pose back before
## the next physics frame (SceneTree.physics_frame).
## The game keeps the last word: if something else places or turns the node, that pose is drawn and nothing of the
## correction is left on it. A teleport (MpActor.snap on the server, or past `snap_distance`) is drawn at once.
## Not: proxies (MpProxyMotion).

## About how long a correction takes to fade (the time constant of an exponential). 0 = drawn at once.
var time_s: float = 0.1
## A correction longer than this (in the node's units) is drawn at once. 0 = every correction fades.
var snap_distance: float = 0.0
var move_position: bool = true
var move_rotation: bool = true

## Two rotations closer than this (|dot| of the quaternions) are the same: about 0.16 degrees, above float noise.
const _SAME_ROTATION_DOT := 1.0 - 1e-6

var _node: Node
## What is drawn = the real pose + this offset (rotation: _offset_rot * real).
var _offset_pos := Vector3.ZERO
var _offset_rot := Quaternion.IDENTITY
## The pose the last physics tick left (so a pose written by someone else afterwards is told apart).
var _tick_pos := Vector3.ZERO
var _tick_rot := Quaternion.IDENTITY
## While drawn: the real pose, and what this wrote over it.
var _real_pos := Vector3.ZERO
var _real_rot := Quaternion.IDENTITY
var _written_pos := Vector3.ZERO
var _written_rot := Quaternion.IDENTITY
var _pos_drawn := false
var _rot_drawn := false
var _jump_next := false


func _init(node: Node) -> void:
	_node = node
	mark_tick()


## A reconciliation moved the node from `before_*` to where it is now: keep drawing it where it was, then fade.
func absorb(before_pos: Vector3, before_rot: Quaternion) -> void:
	if time_s <= 0.0:
		return
	restore()
	if _jump_next:
		_jump_next = false
		jump()
		return
	var now_rot := MpProxyMotion.rotation_of(_node)
	var offset_pos := _offset_pos + before_pos - MpProxyMotion.position_of(_node)
	if snap_distance > 0.0 and offset_pos.length() > snap_distance:
		jump()
		return
	if move_position:
		_offset_pos = offset_pos
	if move_rotation:
		_offset_rot = (_offset_rot * before_rot * now_rot.inverse()).normalized()


## The next correction is a teleport: draw it at once (MpActor.snap called on a client, before its state arrived).
func jump_next() -> void:
	_jump_next = true


## A teleport: drawn at the real pose at once, with no fade and no engine interpolation from the old pose.
func jump() -> void:
	clear()
	if _node.is_inside_tree() and _node.is_physics_interpolated_and_enabled():
		_node.reset_physics_interpolation()


## Draw the node at its real pose from now on.
func clear() -> void:
	restore()
	_offset_pos = Vector3.ZERO
	_offset_rot = Quaternion.IDENTITY


## How far the drawn node is from the real one now (0 = no correction showing).
func offset() -> float:
	return _offset_pos.length()


## After each physics tick: the pose physics left.
func mark_tick() -> void:
	_tick_pos = MpProxyMotion.position_of(_node)
	_tick_rot = MpProxyMotion.rotation_of(_node)


## Every frame (or tick): fade the offset and draw the node with what is left.
func draw(delta: float) -> void:
	if _offset_pos == Vector3.ZERO and _offset_rot == Quaternion.IDENTITY:
		return
	var keep := exp(-delta / maxf(time_s, 0.001))
	_offset_pos *= keep
	_offset_rot = Quaternion.IDENTITY.slerp(_offset_rot, keep)
	if _offset_pos.length_squared() < 1e-6 and _same_rotation(_offset_rot, Quaternion.IDENTITY):
		clear()
		return
	if move_position and _offset_pos != Vector3.ZERO:
		var now := MpProxyMotion.position_of(_node)
		if not now.is_equal_approx(_written_pos if _pos_drawn else _tick_pos):
			## Placed by someone else since: that is the real pose, and nothing is left to fade on it.
			_pos_drawn = false
			_offset_pos = Vector3.ZERO
		else:
			if not _pos_drawn:
				_real_pos = now
				_pos_drawn = true
			_written_pos = _real_pos + _offset_pos
			MpProxyMotion.set_position(_node, _written_pos)
	if move_rotation and _offset_rot != Quaternion.IDENTITY:
		var now := MpProxyMotion.rotation_of(_node)
		if not _same_rotation(now, _written_rot if _rot_drawn else _tick_rot):
			## Turned by someone else since (an aim set every frame): its rotation wins.
			_rot_drawn = false
			_offset_rot = Quaternion.IDENTITY
		else:
			if not _rot_drawn:
				_real_rot = now
				_rot_drawn = true
			_written_rot = (_offset_rot * _real_rot).normalized()
			MpProxyMotion.set_rotation(_node, _written_rot)


## Before physics: the node back at its real pose (unless something else moved it since: then that stays).
func restore() -> void:
	if _pos_drawn:
		_pos_drawn = false
		if MpProxyMotion.position_of(_node).is_equal_approx(_written_pos):
			MpProxyMotion.set_position(_node, _real_pos)
		else:
			_offset_pos = Vector3.ZERO
	if _rot_drawn:
		_rot_drawn = false
		if _same_rotation(MpProxyMotion.rotation_of(_node), _written_rot):
			MpProxyMotion.set_rotation(_node, _real_rot)
		else:
			_offset_rot = Quaternion.IDENTITY


static func _same_rotation(a: Quaternion, b: Quaternion) -> bool:
	return absf(a.dot(b)) > _SAME_ROTATION_DOT
