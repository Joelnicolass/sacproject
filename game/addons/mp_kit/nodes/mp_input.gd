@tool
class_name MpInput
extends Node

## Drop one next to an MpActor. On the owner's machine it reads the InputMap actions listed below and sends them to
## the server; on the server (and in solo) you read them with the same calls as Input, so the movement code is the
## single-player code: `input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")`.
## Extra values (an aim point, a cursor) go with `set_value` on the owner and come out of `get_value` on the server.
## Not: what an action does (the actor), discrete orders (MpActor.to_server).

## Sent even when nothing changed, so a lost packet is fixed within this time.
const KEEPALIVE_S := 0.1

## The MpActor this input belongs to. Empty = the MpActor next to this node.
@export var actor: MpActor
## InputMap actions this player sends. Only these can be read on the server.
@export var actions: PackedStringArray = PackedStringArray(["ui_left", "ui_right", "ui_up", "ui_down", "ui_accept"])

var _index: Dictionary = {}
var _sent: MpInputFrame
var _since_sent: float = 0.0
var _latest: MpInputFrame
var _seen: MpInputFrame
var _just_pressed := PackedByteArray()
var _just_released := PackedByteArray()
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
	_latest = MpInputFrame.sized(actions.size())
	_seen = _latest
	_sent = _latest
	_just_pressed.resize(actions.size())
	_just_released.resize(actions.size())
	## Before the actor's own _physics_process: it reads this tick's input.
	process_physics_priority = -100


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or actor == null:
		return
	if MpKit.is_networked() and not MpKit.is_server() and actor.is_local():
		_send_sample(delta)
	elif MpKit.is_server() and not actor.is_local():
		_consume_remote()


## True when this machine reads the keyboard itself for this player (solo, the host's own, the owner client).
func reads_local() -> bool:
	return actor != null and actor.is_local()


func is_action_pressed(action: StringName) -> bool:
	return get_action_strength(action) > 0.0


func get_action_strength(action: StringName) -> float:
	if reads_local():
		return Input.get_action_strength(action)
	var i: int = _index.get(action, -1)
	return _seen.strengths[i] if i >= 0 else 0.0


func is_action_just_pressed(action: StringName) -> bool:
	if reads_local():
		return Input.is_action_just_pressed(action)
	var i: int = _index.get(action, -1)
	return i >= 0 and _just_pressed[i] == 1


func is_action_just_released(action: StringName) -> bool:
	if reads_local():
		return Input.is_action_just_released(action)
	var i: int = _index.get(action, -1)
	return i >= 0 and _just_released[i] == 1


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
	return _seen.values.get(key, default)


## The seq of the last frame the server applied (0 before any). Reconciliation reads it.
func last_seq() -> int:
	return _seen.seq if _seen else 0


func _send_sample(delta: float) -> void:
	var frame := _sent.next()
	for i in actions.size():
		var a := StringName(actions[i])
		frame.record(i, Input.get_action_strength(a), Input.is_action_just_pressed(a), Input.is_action_just_released(a))
	frame.values = _values.duplicate()
	_since_sent += delta
	if frame.same_as(_sent) and _since_sent < KEEPALIVE_S:
		return
	_sent = frame
	_since_sent = 0.0
	rpc_frame.rpc_id(MpAuthority.SERVER_PEER, frame.pack())


func _consume_remote() -> void:
	for i in actions.size():
		_just_pressed[i] = 1 if _latest.pressed_since(_seen, i) else 0
		_just_released[i] = 1 if _latest.released_since(_seen, i) else 0
	_seen = _latest


@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_frame(data: Array) -> void:
	if not multiplayer.is_server() or actor == null:
		return
	if MpKit.slot_for_peer(multiplayer.get_remote_sender_id()) != actor.owner_slot or actor.owner_slot <= 0:
		return
	var frame := MpInputFrame.unpack(data, actions.size())
	if frame == null or frame.seq <= _latest.seq:
		return
	_latest = frame


func _get_configuration_warnings() -> PackedStringArray:
	if actor == null and MpActor.of(get_parent()) == null:
		return PackedStringArray(["Put an MpActor next to this MpInput (same parent)."])
	return PackedStringArray()
