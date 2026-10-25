@tool
class_name MpInput
extends Node

## Drop one next to an MpActor. On the owner's machine it reads the InputMap actions listed below and sends them to
## the server; on the server (and in solo) you read them with the same calls as Input, so the movement code is the
## single-player code: `input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")`.
## Extra values (an aim point, a cursor) go with `set_value` on the owner and come out of `get_value` on the server.
## With MpActor.predict the owner also simulates at once and keeps its frames to replay them (MpActor reconciles);
## `mp_move` then sees the same presses on the owner, on the server and while replaying (`is_replaying()` tells).
## Not: what an action does (the actor), discrete orders (MpActor.to_server).

## Without prediction a frame is sent when the input changes, and at least this often.
const KEEPALIVE_S := 0.1
## With prediction every tick is sent, together with the frames before it (a lost packet is filled by the next).
const REDUNDANCY := 3
## Frames the owner keeps to replay (2 s at 60 Hz).
const HISTORY := 120

## The MpActor this input belongs to. Empty = the MpActor next to this node.
@export var actor: MpActor
## InputMap actions this player sends. Only these can be read on the server.
@export var actions: PackedStringArray = PackedStringArray(["ui_left", "ui_right", "ui_up", "ui_down", "ui_accept"])

## Server: seq of the owner's frame applied this tick. Synced to the owner with prediction (it replays after it).
var acked_seq: int = 0

var _index: Dictionary = {}
var _current: MpInputFrame
var _previous: MpInputFrame
var _history: Array[MpInputFrame] = []
var _queue := MpInputQueue.new()
var _latest: MpInputFrame
var _tick_frames: Array[MpInputFrame] = []
var _since_sent: float = 0.0
var _replaying: bool = false
var _values: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if actor == null:
		actor = MpActor.of(get_parent())
	if actor == null:
		push_error("MpInput '%s': no MpActor next to it" % name)
		return
	for i in actions.size():
		_index[StringName(actions[i])] = i
	_current = MpInputFrame.sized(actions.size())
	_previous = _current
	## Before the actor's own _physics_process: it reads this tick's input.
	process_physics_priority = -100


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or actor == null:
		return
	if MpKit.is_networked() and not MpKit.is_server() and actor.is_local():
		_sample_and_send(delta)
	elif MpKit.is_server() and not actor.is_local():
		_advance_remote()


## True when the keys are read from Input itself (solo, the host's own player).
func reads_local() -> bool:
	return actor != null and actor.is_local() and MpKit.is_authority()


## True while MpActor replays old frames on the owner: put sounds and effects behind `not is_replaying()`.
func is_replaying() -> bool:
	return _replaying


func is_action_pressed(action: StringName) -> bool:
	return get_action_strength(action) > 0.0


func get_action_strength(action: StringName) -> float:
	if reads_local():
		return Input.get_action_strength(action)
	var i: int = _index.get(action, -1)
	return _current.strengths[i] if i >= 0 else 0.0


func is_action_just_pressed(action: StringName) -> bool:
	if reads_local():
		return Input.is_action_just_pressed(action)
	var i: int = _index.get(action, -1)
	return i >= 0 and _current.pressed_since(_previous, i)


func is_action_just_released(action: StringName) -> bool:
	if reads_local():
		return Input.is_action_just_released(action)
	var i: int = _index.get(action, -1)
	return i >= 0 and _current.released_since(_previous, i)


func get_axis(negative: StringName, positive: StringName) -> float:
	return get_action_strength(positive) - get_action_strength(negative)


## Same as Input.get_vector: the length never goes over 1.
func get_vector(left: StringName, right: StringName, up: StringName, down: StringName, deadzone: float = 0.2) -> Vector2:
	var v := Vector2(get_axis(left, right), get_axis(up, down))
	if v.length() < deadzone:
		return Vector2.ZERO
	return v.limit_length(1.0)


## Owner side: a value the server reads with get_value (an aim point, a cursor). Ignored elsewhere.
func set_value(key: StringName, value: Variant) -> void:
	_values[key] = value


func get_value(key: StringName, default: Variant = null) -> Variant:
	if reads_local():
		return _values.get(key, default)
	return _current.values.get(key, default)


## Owner with prediction: the frame the server applied last (or an empty one) followed by the ones it has not
## applied yet. Older frames are forgotten.
func replay_chain() -> Array[MpInputFrame]:
	while _history.size() > 1 and _history[1].seq <= acked_seq:
		_history.pop_front()
	var chain: Array[MpInputFrame] = []
	if _history.is_empty() or _history[0].seq > acked_seq:
		chain.append(MpInputFrame.sized(actions.size()))
	chain.append_array(_history)
	return chain


## Server with prediction: the owner's frames to simulate this tick, oldest first (may be empty).
func tick_frames() -> Array[MpInputFrame]:
	return _tick_frames


## MpActor: read `frame` (after `before`) as the input for one tick it simulates again (`replaying` on the owner).
func use_frame(frame: MpInputFrame, before: MpInputFrame, replaying: bool) -> void:
	_replaying = replaying
	_previous = before
	_current = frame


func current_frame() -> MpInputFrame:
	return _current


func previous_frame() -> MpInputFrame:
	return _previous


func _sample_and_send(delta: float) -> void:
	var frame := _current.next()
	for i in actions.size():
		var a := StringName(actions[i])
		frame.record(i, Input.get_action_strength(a), Input.is_action_just_pressed(a), Input.is_action_just_released(a))
	frame.values = _values.duplicate()
	_previous = _current
	_current = frame
	_since_sent += delta
	if actor.predict:
		_history.append(frame)
		if _history.size() > HISTORY:
			_history.pop_front()
	elif frame.same_as(_previous) and _since_sent < KEEPALIVE_S:
		return
	var packed: Array = []
	var from := maxi(_history.size() - REDUNDANCY, 0) if actor.predict else 0
	if actor.predict:
		for i in range(from, _history.size()):
			packed.append(_history[i].pack())
	else:
		packed.append(frame.pack())
	_since_sent = 0.0
	rpc_frames.rpc_id(MpAuthority.SERVER_PEER, packed)


## Server: the owner's input for this tick (each frame once and in order with prediction, the newest without).
func _advance_remote() -> void:
	_previous = _current
	if actor.predict:
		_tick_frames = _queue.take_for_tick()
		if not _tick_frames.is_empty():
			_current = _tick_frames[_tick_frames.size() - 1]
			acked_seq = _current.seq
		return
	if _latest:
		_current = _latest



@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_frames(packed: Array) -> void:
	if not multiplayer.is_server() or actor == null or packed.size() > REDUNDANCY:
		return
	if actor.owner_slot <= 0 or MpKit.slot_for_peer(multiplayer.get_remote_sender_id()) != actor.owner_slot:
		return
	for data in packed:
		if typeof(data) != TYPE_ARRAY:
			return
		var frame := MpInputFrame.unpack(data, actions.size())
		if frame == null:
			return
		if actor.predict:
			_queue.add(frame)
		elif _latest == null or frame.seq > _latest.seq:
			_latest = frame


func _get_configuration_warnings() -> PackedStringArray:
	if actor == null and MpActor.of(get_parent()) == null:
		return PackedStringArray(["Put an MpActor next to this MpInput (same parent)."])
	return PackedStringArray()
