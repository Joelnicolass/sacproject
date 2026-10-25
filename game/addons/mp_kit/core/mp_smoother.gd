class_name MpSmoother
extends RefCounted

## Smooths a proxy's position and rotation between network updates (an exponential follow).
## Runs on the peers that only draw the node. Not: prediction, rollback or the authority's own movement.
## How it works: the synchronizer writes the network value; `step` sees it moved, takes it as the new
## target and writes back a value part of the way there, so the eye never sees the jump.

const EPSILON_SQ := 0.0000001

var _primed: bool = false
var _display_pos: Vector3 = Vector3.ZERO
var _net_pos: Vector3 = Vector3.ZERO
var _display_rot: float = 0.0
var _net_rot: float = 0.0
var _display_quat: Quaternion = Quaternion.IDENTITY
var _net_quat: Quaternion = Quaternion.IDENTITY


## Forget the history (a teleport, a respawn): the next step starts from where the node is.
func reset() -> void:
	_primed = false


func step(target: Node, delta: float, speed: float) -> void:
	var alpha := 1.0 - exp(-speed * delta)
	if target is Node2D:
		_step_2d(target as Node2D, alpha)
	elif target is Node3D:
		_step_3d(target as Node3D, alpha)


func _step_2d(n: Node2D, alpha: float) -> void:
	var live := n.position
	if not _primed:
		_display_pos = Vector3(live.x, live.y, 0.0)
		_net_pos = _display_pos
		_display_rot = n.rotation
		_net_rot = n.rotation
		_primed = true
		return
	if live.distance_squared_to(Vector2(_display_pos.x, _display_pos.y)) > EPSILON_SQ:
		_net_pos = Vector3(live.x, live.y, 0.0)
		_net_rot = n.rotation
	_display_pos = _display_pos.lerp(_net_pos, alpha)
	_display_rot = lerp_angle(_display_rot, _net_rot, alpha)
	n.position = Vector2(_display_pos.x, _display_pos.y)
	n.rotation = _display_rot


func _step_3d(n: Node3D, alpha: float) -> void:
	if not _primed:
		_display_pos = n.position
		_net_pos = n.position
		_display_quat = n.quaternion
		_net_quat = n.quaternion
		_primed = true
		return
	if n.position.distance_squared_to(_display_pos) > EPSILON_SQ:
		_net_pos = n.position
		_net_quat = n.quaternion
	_display_pos = _display_pos.lerp(_net_pos, alpha)
	_display_quat = _display_quat.slerp(_net_quat, alpha)
	n.position = _display_pos
	n.quaternion = _display_quat
