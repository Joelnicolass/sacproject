class_name MpProxyMotion
extends RefCounted

## Where a proxy (a node this machine only draws) is drawn between server states, for MpActor:
##   FOLLOW   - chases the newest state: no delay, but uneven packets show as small stutters;
##   BUFFERED - draws `delay_s` in the past, between two real states (MpInterpolator): smooth under jitter.
## The synchronizer writes the server's pose into MpActor (net_position / net_rotation), never into the node, so
## this is the only writer of the node's pose on a client. Not: the owner's predicted node, the server.

var delay_s: float = 0.1
var follow_speed: float = 14.0
var move_position: bool = true
var move_rotation: bool = true

var _node: Node
var _buffered: bool
var _buffer := MpInterpolator.new()
var _last_stamp: float = 0.0
var _shown_pos := Vector3.ZERO
var _shown_rot := Quaternion.IDENTITY


func _init(node: Node, buffered: bool) -> void:
	_node = node
	_buffered = buffered


## `stamp` 0 = no state from the server yet: the node stays where the scene put it.
func draw(delta: float, stamp: float, net_pos: Vector3, net_rot: Quaternion) -> void:
	if stamp <= 0.0:
		return
	if _last_stamp <= 0.0:
		_shown_pos = net_pos
		_shown_rot = net_rot
	if stamp != _last_stamp:
		_last_stamp = stamp
		MpNetClock.observe(stamp)
		_buffer.push(stamp, net_pos, net_rot)
	if _buffered:
		var pose := _buffer.sample(MpNetClock.server_time() - delay_s)
		_shown_pos = pose[0]
		_shown_rot = pose[1]
	else:
		var alpha := 1.0 - exp(-follow_speed * delta)
		_shown_pos = _shown_pos.lerp(net_pos, alpha)
		_shown_rot = _shown_rot.slerp(net_rot, alpha)
	write(_shown_pos, _shown_rot)


## Put the node at this pose now (and forget the history: a teleport or a respawn).
func snap(net_pos: Vector3, net_rot: Quaternion) -> void:
	_buffer.clear()
	_last_stamp = 0.0
	write(net_pos, net_rot)


func write(pos: Vector3, rot: Quaternion) -> void:
	if move_position:
		MpProxyMotion.set_position(_node, pos)
	if move_rotation:
		MpProxyMotion.set_rotation(_node, rot)


static func position_of(node: Node) -> Vector3:
	if node is Node2D:
		var p := (node as Node2D).position
		return Vector3(p.x, p.y, 0.0)
	if node is Node3D:
		return (node as Node3D).position
	return Vector3.ZERO


static func rotation_of(node: Node) -> Quaternion:
	if node is Node2D:
		return Quaternion(Vector3.BACK, (node as Node2D).rotation)
	if node is Node3D:
		return (node as Node3D).quaternion
	return Quaternion.IDENTITY


static func set_position(node: Node, value: Vector3) -> void:
	if node is Node2D:
		(node as Node2D).position = Vector2(value.x, value.y)
	elif node is Node3D:
		(node as Node3D).position = value


static func set_rotation(node: Node, value: Quaternion) -> void:
	if node is Node2D:
		(node as Node2D).rotation = value.get_euler().z
	elif node is Node3D:
		(node as Node3D).quaternion = value
