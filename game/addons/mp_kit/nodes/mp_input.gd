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
## With prediction every tick is sent, together with every frame the server has not confirmed yet (as Overwatch
## does; delta-coded, MpInputPacket), and never fewer than this many: a burst of lost packets loses no frame.
const REDUNDANCY := 3
## Frames the owner keeps to replay (2 s at 60 Hz).
const HISTORY := 120
## Server, with prediction: how often it tells the owner how many of its frames are waiting beyond the buffer.
const SLACK_S := 0.1
## Owner: at most one frame more (the server is short) or one less (it has more than one frame beyond its buffer)
## every this many ticks: about 6 % faster or slower, as Overwatch's client speeds up or slows down to keep the
## server's buffer just full. MpActor draws either without a hitch (the correction smoother takes the step).
const PACE_EVERY := 16
## Owner: the server's slack above which it sends a frame less.
const SLACK_HIGH := 1

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
## Server: the connection whose frames this takes (0 = the seat has none: it dropped, or nobody sat yet).
var _owner_peer: int = 0
var _latest: MpInputFrame
var _tick_frames: Array[MpInputFrame] = []
var _since_sent: float = 0.0
var _replaying: bool = false
var _values: Dictionary = {}
var _since_slack: float = 0.0
## Owner: the server's last word on its buffer (frames beyond the depth; negative = short).
var _server_slack: int = 0
var _since_extra: int = 0
## Owner: a frame sampled this tick before the regular one (pacing), and the frame before it. MpActor runs it first.
var _extra: MpInputFrame
var _extra_before: MpInputFrame
## Owner: no frame this tick (pacing down); MpActor simulates nothing new.
var _skip: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_queue = _new_queue()
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


## Owner, pacing: the extra frame to simulate before this tick's own (null almost always), taken once.
## Owner, pacing: true when this tick sampled no frame (taken once).
func take_skip() -> bool:
	var skipped := _skip
	_skip = false
	return skipped


func take_extra() -> Array:
	if _extra == null:
		return []
	var out := [_extra, _extra_before]
	_extra = null
	_extra_before = null
	return out


## Server, with prediction: frames of this owner waiting beyond the buffer (negative = short).
func server_slack() -> int:
	return _queue.slack()


## Server, with prediction: the buffer's depth in ticks (how long this owner's frames wait).
func server_depth() -> int:
	return _queue.depth


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
	if actor.predict:
		_pace()
		if _skip:
			_send_unconfirmed()
			return
	var frame := _current.next()
	## Behind the server (this client froze or stalled and the server went on with guesses): carry on after the
	## server's last frame, so these frames count again.
	if actor.predict and frame.seq <= acked_seq:
		frame.seq = acked_seq + 1
	for i in actions.size():
		var a := StringName(actions[i])
		frame.record(i, Input.get_action_strength(a), Input.is_action_just_pressed(a), Input.is_action_just_released(a))
	frame.values = _values.duplicate()
	frame.view = MpNetClock.view_stamp()
	_previous = _current
	_current = frame
	_since_sent += delta
	if actor.predict:
		_history.append(frame)
		if _history.size() > HISTORY:
			_history.pop_front()
	elif frame.same_as(_previous) and _since_sent < KEEPALIVE_S:
		return
	if actor.predict:
		_send_unconfirmed()
		return
	_since_sent = 0.0
	var one: Array[MpInputFrame] = [frame]
	rpc_frames.rpc_id(MpAuthority.SERVER_PEER, MpInputPacket.encode(one))


## Owner with prediction: every frame the server has not confirmed, at least REDUNDANCY, consecutive (a seq jump
## starts a new run).
func _send_unconfirmed() -> void:
	if _history.is_empty():
		return
	var from := _history.size() - 1
	while from > 0 and _history[from - 1].seq == _history[from].seq - 1 \
			and (_history.size() - from < REDUNDANCY or _history[from - 1].seq > acked_seq):
		from -= 1
	_since_sent = 0.0
	rpc_frames.rpc_id(MpAuthority.SERVER_PEER, MpInputPacket.encode(_history.slice(from)))


## Owner: keep the server's buffer just full. Short of frames: sample one more this tick (same keys, simulated before
## this tick's own). More than SLACK_HIGH beyond it: sample none this tick. The others never see the player stall or
## hurry; MpActor smooths the step on this screen.
func _pace() -> void:
	_since_extra += 1
	if _since_extra < PACE_EVERY or (_server_slack >= 0 and _server_slack <= SLACK_HIGH):
		return
	_since_extra = 0
	if _server_slack > SLACK_HIGH:
		## The server holds more of this owner's frames than its buffer needs: one frame less, and its wait shortens
		## without the others seeing the player hitch.
		_server_slack -= 1
		_skip = true
		return
	_server_slack += 1
	var extra := _current.next()
	for i in actions.size():
		var a := StringName(actions[i])
		extra.record(i, Input.get_action_strength(a), false, false)
	extra.values = _values.duplicate()
	extra.view = MpNetClock.view_stamp()
	_extra_before = _current
	_extra = extra
	_history.append(extra)
	_current = extra


## Server: the owner's input for this tick (each frame once and in order with prediction, the newest without).
func _advance_remote() -> void:
	_follow_owner_peer(MpKit.peer_id_for(actor.owner_slot))
	_previous = _current
	if _owner_peer == 0:
		## Nobody plays this seat now (dropped, within its grace): no keys held, and with prediction the server goes on
		## simulating it, so gravity, a knockback or a stun run their course (as an engine with no input does).
		_tick_frames = []
		if actor.predict:
			_tick_frames.append(_current)
		return
	if actor.predict:
		_since_slack += get_physics_process_delta_time()
		if _since_slack >= SLACK_S:
			_since_slack = 0.0
			## Only once the owner has this node (a rejoining owner is still loading its world).
			if actor.reaches(_owner_peer):
				rpc_slack.rpc_id(_owner_peer, _queue.slack())
		_tick_frames = _queue.take_for_tick(Time.get_ticks_usec() / 1000000.0)
		if not _tick_frames.is_empty():
			_current = _tick_frames[_tick_frames.size() - 1]
			acked_seq = _current.seq
		return
	if _latest:
		_current = _latest



@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_frames(packet: PackedByteArray) -> void:
	if not multiplayer.is_server() or actor == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if actor.owner_slot <= 0 or MpKit.slot_for_peer(sender) != actor.owner_slot:
		return
	_follow_owner_peer(sender)
	for frame in MpInputPacket.decode(packet, actions.size()):
		if actor.predict:
			_queue.add(frame, Time.get_ticks_usec() / 1000000.0)
		elif _latest == null or frame.seq > _latest.seq:
			_latest = frame


## Server: the seat's connection changed (a rejoin is a new one, whose frames count from 1 again; or it dropped):
## start its input over, with no keys held. The kept actor then answers the new connection at once.
func _follow_owner_peer(peer: int) -> void:
	if peer == _owner_peer:
		return
	_owner_peer = peer
	_queue = _new_queue()
	_latest = null
	_tick_frames = []
	_current = MpInputFrame.sized(actions.size())
	_previous = _current
	acked_seq = 0


## The server's input buffer sizes itself to this owner's network (MpInputQueue.adaptive).
func _new_queue() -> MpInputQueue:
	var queue := MpInputQueue.new()
	queue.adaptive = true
	queue.depth = queue.min_depth
	return queue


@rpc("authority", "call_remote", "unreliable")
func rpc_slack(slack: int) -> void:
	_server_slack = clampi(slack, -64, 64)


func _get_configuration_warnings() -> PackedStringArray:
	if actor == null and MpActor.of(get_parent()) == null:
		return PackedStringArray(["Put an MpActor next to this MpInput (same parent)."])
	return PackedStringArray()

