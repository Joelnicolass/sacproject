class_name MpProxyMotion
extends RefCounted

## Where a proxy (a node this machine only draws) is drawn between server states, for MpActor:
##   FOLLOW   - chases the newest state: no delay, but uneven packets show as small stutters;
##   BUFFERED - draws in the past, between two real states (MpInterpolator): smooth under jitter. With `adaptive`
##              the delay is what this proxy's states need, measured like Photon Fusion does: the percentile
##              (1 - late_tolerance) of the gaps between states plus the same percentile of how late they arrive,
##              plus one tick, at most `delay_s`. A steady network ends a few ticks behind; a lossy or jittery one
##              further. It moves toward that a fraction of the error per frame (as Unity's netcode), never so fast
##              that the drawn time goes back.
## The synchronizer writes the server's pose into MpActor (net_position / net_rotation), never into the node, so
## this is the only writer of the node's pose on a client. Not: the owner's predicted node, the server.

var delay_s: float = 0.1
var adaptive: bool = true
## Share of states allowed to arrive too late to be drawn on time (they are extrapolated over instead).
var late_tolerance: float = 0.03

## States measured (about 2 s at 60 Hz).
const WINDOW := 120
## Part of the error corrected per frame.
const CORRECTION := 0.1
## Limits of that correction, in seconds per second: up fast (late packets; the drawn time slows to a quarter at
## most, never backwards), down gently (a proxy that catches up runs at most 3 % fast), so motion never jumps.
const RAISE_PER_S := 0.75
const LOWER_PER_S := 0.03
## The first states (about half a second at 60 Hz): the delay goes straight to what they need, before the proxy
## has moved much; gradual after that.
const SETTLE_STATES := 30

var _gaps := PackedFloat64Array()
var _lates := PackedFloat64Array()
var _delay: float = -1.0
var _target: float = -1.0
var _states: int = 0
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
		if _last_stamp > 0.0 and stamp > _last_stamp:
			_gaps.append(stamp - _last_stamp)
			if _gaps.size() > WINDOW:
				_gaps.remove_at(0)
		_last_stamp = stamp
		MpNetClock.observe(stamp)
		_lates.append(maxf(MpNetClock.server_time() - stamp, 0.0))
		if _lates.size() > WINDOW:
			_lates.remove_at(0)
		_states += 1
		_target = -1.0
		_buffer.push(stamp, net_pos, net_rot)
	if _buffered:
		var delay := current_delay(delta)
		MpNetClock.view_delay = delay
		var pose := _buffer.sample(MpNetClock.server_time() - delay)
		_shown_pos = pose[0]
		_shown_rot = pose[1]
	else:
		var alpha := 1.0 - exp(-follow_speed * delta)
		_shown_pos = _shown_pos.lerp(net_pos, alpha)
		_shown_rot = _shown_rot.slerp(net_rot, alpha)
	write(_shown_pos, _shown_rot)


## The delay used this frame (BUFFERED). Not adaptive: `delay_s`.
func current_delay(delta: float = 0.0) -> float:
	if not adaptive:
		return delay_s
	if _target < 0.0:
		_target = target_delay()
	var target := _target
	if _delay < 0.0 or _states < SETTLE_STATES:
		_delay = target if _states >= 2 else delay_s
	else:
		var step := clampf((target - _delay) * CORRECTION, -LOWER_PER_S * delta, RAISE_PER_S * delta)
		_delay += step
	return _delay


## What the measured states need now (before the gradual correction).
func target_delay() -> float:
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	var keep := 1.0 - late_tolerance
	var gap := maxf(MpNetQuality.percentile(_gaps, keep), tick)
	return clampf(gap + MpNetQuality.percentile(_lates, keep) + tick, 0.0, delay_s)



## Put the node at this pose now (and forget the history: a teleport or a respawn).
func snap(net_pos: Vector3, net_rot: Quaternion) -> void:
	_buffer.clear()
	_last_stamp = 0.0
	_states = 0
	_target = -1.0
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
