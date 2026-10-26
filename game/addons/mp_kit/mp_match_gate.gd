class_name MpMatchGate
extends Node

## The door of a match: who may sit and when it starts. Before the start every free seat is open; the match starts (the tree unpauses)
## once the seats it waits for have loaded their world. After the start only a seat that is away comes back, within rejoin_grace_s;
## anybody else is turned away with a reason. Not: who wins, what an abandon means (the game listens), the room's tokens (MpMatchAgent).
## MpKit owns it (`/root/MpKit/Gate`) and feeds it: admit() on each presentation, mark_loaded() on world_ready, mark_left() on a drop.
## Two ways to name a seat: open (LAN, a dedicated by hand: the first free seat gets a fresh credential that brings it back) or
## identity (a room's ticket: `identity.call(peer_id, credential) -> slot`). In Remote: phase, expected, loaded, away.

## Every peer (clients through the state RPC): the match waits (`loaded` of `expected` seats in) or runs.
signal waiting_changed(waiting: bool, loaded: int, expected: int)
## Server: a seat got in; `back` = it had been in before (a rejoin).
signal seat_admitted(slot: int, back: bool)
## Server, before the start: a seat finished loading its world.
signal seat_loaded(slot: int, loaded: int, expected: int)
## Server: "all_loaded" | "host_started" | "load_timeout" | "no_hold".
signal started(why: String)
## Server: an admitted seat dropped; it may come back within rejoin_grace_s.
signal seat_away(slot: int)
## Server: a seat is out for good ("grace_over" | "not_loaded" | what give_up says). is_abandoned(slot) is already true here.
signal seat_abandoned(slot: int, why: String)
## Server: every expected seat is past the grace (nobody is left to play).
signal all_gone
## Server: a peer was turned away with `reason`.
signal turned_away(peer_id: int, reason: String)

enum Phase { IDLE, FILLING, RUNNING }

const MATCH_STARTED := "match_started"
const FULL := "full"
const GRACE_OVER := "grace_over"
const SEAT_TAKEN := "slot_taken"
const UNKNOWN := "rejected"
const NOT_LOADED := "not_loaded"

## Seconds a seat that dropped keeps its place.
var rejoin_grace_s := 60.0
## Seconds after the first admission the match waits for the rest to load before it starts with whoever loaded.
var load_timeout_s := 60.0
## The clients pause their world too while the match waits (nobody walks ahead).
var pause_clients := true
## True on a listen host: the host may start with whoever loaded (can_start_now). MpFlow sets it before arm().
var host_present := false
## Milliseconds now. Tests inject a clock.
var now_ms: Callable = Time.get_ticks_msec

var phase: Phase = Phase.IDLE
var expected: Array[int]:
	get:
		return expected_slots()
var loaded: Array[int]:
	get:
		return loaded_slots()
var away: Array[int]:
	get:
		return away_slots()

var _seats: Array[int] = []
var _need: int = 0
var _identity: Callable = Callable()
var _hold: bool = true
var _waiting: bool = false
var _paused_by_me: bool = false
var _first_admit_ms: int = -1
var _all_gone_sent: bool = false
## slot -> credential (open mode)
var _credentials: Dictionary = {}
## slot -> peer id while connected
var _peer_of: Dictionary = {}
var _admitted: Dictionary = {}
var _loaded: Dictionary = {}
## slot -> ms it left
var _away_ms: Dictionary = {}
## slot -> why, for seats the match no longer waits for (give_up, load timeout)
var _given_up: Dictionary = {}
## slot -> why
var _abandoned: Dictionary = {}


class Admission:
	var slot := 0
	var reason := ""
	var credential := ""


func _process(_delta: float) -> void:
	poll()


## Opens the door. `seats`: the human slots (a listen host's own slot is not one: it is always in). `need` = how many must load
## to start (0 = all). Empty `identity` = open seats with fresh credentials. `hold` = pause the tree until the start.
func arm(seats: Array[int], need: int = 0, identity: Callable = Callable(), hold: bool = true) -> void:
	reset()
	_seats = seats.duplicate()
	_seats.sort()
	_need = maxi(0, need)
	_identity = identity
	_hold = hold
	if not hold:
		phase = Phase.RUNNING
		started.emit("no_hold")
		return
	phase = Phase.FILLING
	_set_waiting(true)
	_check_start()


func is_armed() -> bool:
	return phase != Phase.IDLE


## MpKit only: the peer presented `credential` (a ticket, a stored credential or ""). slot 0 = turned away (see reason).
func admit(peer_id: int, credential: String) -> Admission:
	var out := Admission.new()
	out.reason = _judge(peer_id, credential, out)
	if not out.reason.is_empty():
		out.slot = 0
		turned_away.emit(peer_id, out.reason)
		return out
	var back := _admitted.has(out.slot)
	_admitted[out.slot] = true
	_peer_of[out.slot] = peer_id
	_away_ms.erase(out.slot)
	if _first_admit_ms < 0:
		_first_admit_ms = _now()
	seat_admitted.emit(out.slot, back)
	return out


## MpKit only: the seat's client loaded its world.
func mark_loaded(slot: int) -> void:
	if not _seats.has(slot) or not _admitted.has(slot):
		return
	var first := not _loaded.has(slot)
	_loaded[slot] = true
	if phase == Phase.FILLING and first:
		seat_loaded.emit(slot, _loaded_count(), _target())
		_check_start()
		## Still waiting: every loaded seat (this one too) hears the new count. Started: _start already told them.
		if phase == Phase.FILLING:
			_set_waiting(true, true)
		return
	_send_state_to(int(_peer_of.get(slot, 0)))


## MpKit only: the seat's peer dropped.
func mark_left(slot: int) -> void:
	_peer_of.erase(slot)
	if not _admitted.has(slot) or _abandoned.has(slot) or _away_ms.has(slot):
		return
	_away_ms[slot] = _now()
	seat_away.emit(slot)


## The listen host starts with whoever loaded. False when it may not (see can_start_now).
func start_now() -> bool:
	if not can_start_now():
		return false
	_start("host_started")
	return true


## True on a listen host whose open match waits and has at least one client loaded.
func can_start_now() -> bool:
	return phase == Phase.FILLING and host_present and not _identity.is_valid() and _loaded_count() > 0


## The game gives up on `slot` (e.g. it never sent its pick): the match stops waiting for it, and it is abandoned (`why`) as soon
## as somebody else is in.
func give_up(slot: int, why: String) -> void:
	if not _seats.has(slot) or _abandoned.has(slot):
		return
	_given_up[slot] = why
	_away_ms[slot] = _now() - _grace_ms() - 1
	_peer_of.erase(slot)
	poll()
	_check_start()


func is_waiting() -> bool:
	return _waiting


func is_abandoned(slot: int) -> bool:
	return _abandoned.has(slot)


func expected_slots() -> Array[int]:
	return _seats.duplicate()


func loaded_slots() -> Array[int]:
	var out: Array[int] = []
	for slot in _seats:
		if _loaded.has(slot):
			out.append(slot)
	return out


func away_slots() -> Array[int]:
	var out: Array[int] = []
	for slot in _seats:
		if _away_ms.has(slot):
			out.append(slot)
	return out


## Back to IDLE (MpKit.leave()). Unpauses the tree only if the gate paused it.
func reset() -> void:
	phase = Phase.IDLE
	_seats.clear()
	_need = 0
	_identity = Callable()
	_hold = true
	_first_admit_ms = -1
	_all_gone_sent = false
	_credentials.clear()
	_peer_of.clear()
	_admitted.clear()
	_loaded.clear()
	_away_ms.clear()
	_given_up.clear()
	_abandoned.clear()
	_waiting = false
	if _paused_by_me:
		_paused_by_me = false
		if is_inside_tree():
			get_tree().paused = false


## The timers (load timeout, grace). Every frame; tests call it after moving the clock.
func poll() -> void:
	if phase == Phase.IDLE or not _is_server():
		return
	var now := _now()
	if phase == Phase.FILLING and _first_admit_ms >= 0 and now - _first_admit_ms > int(load_timeout_s * 1000.0):
		_start("load_timeout")
	var gone: Array[int] = []
	for slot in _away_ms.keys():
		if now - int(_away_ms[slot]) > _grace_ms():
			gone.append(int(slot))
	if gone.is_empty():
		return
	gone.sort()
	if phase == Phase.FILLING and not _identity.is_valid():
		for slot in gone:
			_free_seat(slot)
		_set_waiting(true, true)
		return
	if _present_slots().is_empty():
		_check_all_gone(gone)
		return
	for slot in gone:
		_away_ms.erase(slot)
		var why := str(_given_up.get(slot, GRACE_OVER))
		_abandoned[slot] = why
		seat_abandoned.emit(slot, why)


func _judge(peer_id: int, credential: String, out: Admission) -> String:
	if phase == Phase.IDLE:
		return UNKNOWN
	if _identity.is_valid():
		out.slot = int(_identity.call(peer_id, credential))
		if out.slot <= 0 or not _seats.has(out.slot):
			return UNKNOWN
		return _judge_known(peer_id, out.slot)
	for slot in _credentials.keys():
		if not credential.is_empty() and _credentials[slot] == credential:
			out.slot = int(slot)
			out.credential = credential
			return _judge_known(peer_id, out.slot)
	if phase == Phase.RUNNING:
		return MATCH_STARTED
	for slot in _seats:
		if not _credentials.has(slot) and not _given_up.has(slot):
			out.slot = slot
			out.credential = _fresh_credential()
			_credentials[slot] = out.credential
			return ""
	return FULL


## A seat the gate knows (its credential or its ticket): in unless it is out for good, past the grace, or held by a live peer.
func _judge_known(peer_id: int, slot: int) -> String:
	if _abandoned.has(slot) or _given_up.has(slot):
		return GRACE_OVER
	var holder := int(_peer_of.get(slot, 0))
	if holder != 0 and holder != peer_id:
		return SEAT_TAKEN
	if _away_ms.has(slot) and _now() - int(_away_ms[slot]) > _grace_ms():
		return GRACE_OVER
	return ""


func _check_start() -> void:
	if phase != Phase.FILLING:
		return
	var count := _loaded_count()
	if count >= _target() and (count > 0 or _required().is_empty()):
		_start("all_loaded")


func _start(why: String) -> void:
	if phase != Phase.FILLING:
		return
	phase = Phase.RUNNING
	## Open seats nobody took close; a seat still loading after the timeout is out ("not_loaded").
	if not _identity.is_valid():
		_seats = _slots_where(func(slot: int) -> bool: return _admitted.has(slot))
	if why == "load_timeout":
		for slot in _required():
			if not _loaded.has(slot):
				_given_up[slot] = NOT_LOADED
				_away_ms[slot] = _now() - _grace_ms() - 1
				_peer_of.erase(slot)
	_set_waiting(false)
	started.emit(why)
	poll()


func _check_all_gone(gone: Array[int]) -> void:
	if _all_gone_sent or _seats.is_empty():
		return
	for slot in _seats:
		if not _abandoned.has(slot) and not gone.has(slot):
			return
	_all_gone_sent = true
	all_gone.emit()


func _free_seat(slot: int) -> void:
	_credentials.erase(slot)
	_given_up.erase(slot)
	_admitted.erase(slot)
	_loaded.erase(slot)
	_away_ms.erase(slot)
	_peer_of.erase(slot)


func _set_waiting(on: bool, force_send: bool = false) -> void:
	var changed := on != _waiting
	_waiting = on
	if on and _hold and not _paused_by_me and is_inside_tree() and not get_tree().paused:
		_paused_by_me = true
		get_tree().paused = true
	elif not on and _paused_by_me:
		_paused_by_me = false
		if is_inside_tree():
			get_tree().paused = false
	if changed or force_send:
		waiting_changed.emit(_waiting, _loaded_count(), _target())
		for slot in _present_slots():
			if _loaded.has(slot):
				_send_state_to(int(_peer_of.get(slot, 0)))


func _send_state_to(peer_id: int) -> void:
	if peer_id <= 0 or not _is_networked_server() or not multiplayer.get_peers().has(peer_id):
		return
	rpc_state.rpc_id(peer_id, _waiting, _loaded_count(), _target(), pause_clients)


@rpc("authority", "call_remote", "reliable")
func rpc_state(waiting: bool, loaded_count: int, expected_count: int, pause: bool) -> void:
	phase = Phase.FILLING if waiting else Phase.RUNNING
	_waiting = waiting
	if waiting and pause and not _paused_by_me and not get_tree().paused:
		_paused_by_me = true
		get_tree().paused = true
	elif not waiting and _paused_by_me:
		_paused_by_me = false
		get_tree().paused = false
	waiting_changed.emit(waiting, loaded_count, expected_count)


## The seats the match still waits for (not given up, not abandoned).
func _required() -> Array[int]:
	return _slots_where(func(slot: int) -> bool: return not _given_up.has(slot) and not _abandoned.has(slot))


## How many loaded seats start the match.
func _target() -> int:
	var required := _required().size()
	return mini(_need, required) if _need > 0 else required


func _loaded_count() -> int:
	var count := 0
	for slot in _required():
		if _loaded.has(slot):
			count += 1
	return count


func _present_slots() -> Array[int]:
	return _slots_where(func(slot: int) -> bool:
		return _admitted.has(slot) and not _away_ms.has(slot) and not _abandoned.has(slot))


func _slots_where(keep: Callable) -> Array[int]:
	var out: Array[int] = []
	for slot in _seats:
		if keep.call(slot):
			out.append(slot)
	return out


func _grace_ms() -> int:
	return int(rejoin_grace_s * 1000.0)


func _now() -> int:
	return int(now_ms.call())


func _fresh_credential() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


func _is_server() -> bool:
	return not is_inside_tree() or multiplayer.is_server()


func _is_networked_server() -> bool:
	return is_inside_tree() and multiplayer.multiplayer_peer != null \
		and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) and multiplayer.is_server()
