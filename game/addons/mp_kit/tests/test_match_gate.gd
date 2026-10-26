extends "res://addons/mp_kit/tests/mp_test.gd"

## MpMatchGate rules with an injected clock, no network: filling, full, need, the start, a newcomer after the start, a seat back
## within the grace or past it, a seat held by a live peer, identity (ticket) mode, the load timeout, all_gone and reset.

var _clock: Array[int] = [1000]
var _events: Array[String] = []


func _gate(seats: Array[int], need: int = 0, identity: Callable = Callable(), hold: bool = true) -> MpMatchGate:
	var gate := MpMatchGate.new()
	gate.name = "GateUnderTest"
	tree.root.add_child(gate)
	gate.now_ms = func() -> int: return _clock[0]
	gate.rejoin_grace_s = 5.0
	gate.load_timeout_s = 10.0
	gate.seat_admitted.connect(func(slot: int, back: bool) -> void: _events.append("in %d%s" % [slot, " back" if back else ""]))
	gate.seat_loaded.connect(func(slot: int, n: int, of: int) -> void: _events.append("loaded %d %d/%d" % [slot, n, of]))
	gate.started.connect(func(why: String) -> void: _events.append("started %s" % why))
	gate.seat_away.connect(func(slot: int) -> void: _events.append("away %d" % slot))
	gate.seat_abandoned.connect(func(slot: int, why: String) -> void:
		_events.append("abandoned %d %s %s" % [slot, why, gate.is_abandoned(slot)]))
	gate.all_gone.connect(func() -> void: _events.append("all_gone"))
	gate.turned_away.connect(func(_peer: int, reason: String) -> void: _events.append("turned %s" % reason))
	gate.arm(seats, need, identity, hold)
	return gate


func _done(gate: MpMatchGate) -> void:
	gate.reset()
	gate.free()
	_events.clear()


func _advance_s(seconds: float, gate: MpMatchGate) -> void:
	_clock[0] += int(seconds * 1000.0)
	gate.poll()


func test_fills_open_seats_and_turns_away_when_full() -> void:
	var gate := _gate([2, 3])
	check(gate.is_waiting() and tree.paused, "an armed gate holds: the tree is paused while it fills")
	var a := gate.admit(10, "")
	var b := gate.admit(11, "")
	check(a.slot == 2 and b.slot == 3, "the first free seats go in order (2, 3)")
	check(not a.credential.is_empty() and a.credential != b.credential, "each open seat gets its own credential")
	var c := gate.admit(12, "")
	check(c.slot == 0 and c.reason == MpMatchGate.FULL, "a third peer is turned away: full")
	_done(gate)
	check(not tree.paused, "reset unpauses what the gate paused")


func test_starts_when_every_seat_loaded() -> void:
	var gate := _gate([2, 3])
	gate.admit(10, "")
	gate.admit(11, "")
	gate.mark_loaded(2)
	check(gate.phase == MpMatchGate.Phase.FILLING and tree.paused, "one of two loaded: still filling")
	gate.mark_loaded(3)
	check(gate.phase == MpMatchGate.Phase.RUNNING and not gate.is_waiting() and not tree.paused, "both loaded: it runs")
	check(_events.has("loaded 2 1/2") and _events.has("loaded 3 2/2") and _events.back() == "started all_loaded",
		"loaded 1/2, 2/2, then started (all_loaded): %s" % [_events])
	_done(gate)


func test_need_starts_with_fewer() -> void:
	var gate := _gate([1, 2, 3, 4], 1)
	var a := gate.admit(10, "")
	var b := gate.admit(11, "")
	gate.mark_loaded(a.slot)
	check(gate.phase == MpMatchGate.Phase.RUNNING, "need = 1: the first loaded seat starts it")
	check(gate.expected_slots() == [1, 2], "after the start the seats are the admitted ones: %s" % [gate.expected_slots()])
	gate.mark_loaded(b.slot)
	check(not gate.is_abandoned(b.slot) and gate.loaded_slots() == [1, 2], "an admitted seat still loading may load after the start")
	_done(gate)


func test_newcomer_after_start_is_turned_away() -> void:
	var gate := _gate([2], 0)
	gate.admit(10, "")
	gate.mark_loaded(2)
	var late := gate.admit(11, "")
	check(late.slot == 0 and late.reason == MpMatchGate.MATCH_STARTED, "a new peer after the start: match_started")
	var stranger := gate.admit(12, "not-a-credential")
	check(stranger.reason == MpMatchGate.MATCH_STARTED, "an unknown credential after the start: match_started")
	check(_events.has("turned match_started"), "turned_away says why")
	_done(gate)


func test_back_within_grace_keeps_the_seat() -> void:
	var gate := _gate([2, 3])
	var a := gate.admit(10, "")
	gate.admit(11, "")
	gate.mark_loaded(2)
	gate.mark_loaded(3)
	gate.mark_left(2)
	check(gate.away_slots() == [2], "a dropped seat is away")
	_advance_s(3.0, gate)
	var back := gate.admit(20, a.credential)
	check(back.slot == 2 and not gate.is_abandoned(2) and gate.away_slots().is_empty(), "the same credential within the grace: the same seat")
	check(_events.has("in 2 back"), "seat_admitted says it is back")
	_done(gate)


func test_past_grace_is_abandoned() -> void:
	var gate := _gate([2, 3])
	var a := gate.admit(10, "")
	gate.admit(11, "")
	gate.mark_loaded(2)
	gate.mark_loaded(3)
	gate.mark_left(2)
	_advance_s(6.0, gate)
	check(gate.is_abandoned(2) and _events.has("abandoned 2 grace_over true"), "past the grace with somebody in: abandoned, is_abandoned true at the emit")
	var late := gate.admit(20, a.credential)
	check(late.slot == 0 and late.reason == MpMatchGate.GRACE_OVER, "coming back after the grace: grace_over")
	_done(gate)


func test_live_seat_cannot_be_taken() -> void:
	var gate := _gate([2, 3])
	var a := gate.admit(10, "")
	var copy := gate.admit(11, a.credential)
	check(copy.slot == 0 and copy.reason == MpMatchGate.SEAT_TAKEN, "a credential whose seat is still connected: slot_taken")
	gate.mark_left(2)
	var again := gate.admit(12, a.credential)
	check(again.slot == 2, "while filling, a dropped seat keeps its credential within the grace")
	_done(gate)


func test_filling_seat_past_grace_frees() -> void:
	var gate := _gate([2])
	gate.admit(10, "")
	gate.mark_left(2)
	_advance_s(6.0, gate)
	var other := gate.admit(11, "")
	check(other.slot == 2 and not gate.is_abandoned(2), "before the start, an open seat past the grace is free again")
	_done(gate)


func test_identity_mode() -> void:
	var tickets := {"t2": 2, "t3": 3}
	var identity := func(_peer: int, ticket: String) -> int: return int(tickets.get(ticket, 0))
	var gate := _gate([2, 3], 0, identity)
	check(gate.admit(10, "bogus").reason == MpMatchGate.UNKNOWN, "an unknown ticket: rejected")
	var b := gate.admit(11, "t3")
	check(b.slot == 3 and b.credential.is_empty(), "the ticket names the seat; no credential is handed out")
	check(not gate.can_start_now(), "a ticket match never starts by hand")
	gate.mark_loaded(3)
	gate.admit(12, "t2")
	gate.mark_loaded(2)
	check(gate.phase == MpMatchGate.Phase.RUNNING, "every ticket seat loaded: it runs")
	_done(gate)


func test_identity_without_hold_admits_first_comers() -> void:
	var identity := func(_peer: int, ticket: String) -> int: return 2 if ticket == "t2" else (3 if ticket == "t3" else 0)
	var gate := _gate([2, 3], 0, identity, false)
	check(gate.phase == MpMatchGate.Phase.RUNNING and not tree.paused and _events.has("started no_hold"), "no hold: it runs at once, unpaused")
	check(gate.admit(10, "t2").slot == 2 and gate.admit(11, "t3").slot == 3, "ticket seats still come in the first time")
	_done(gate)


func test_load_timeout_starts_without_the_slow_seat() -> void:
	var identity := func(_peer: int, ticket: String) -> int: return 2 if ticket == "t2" else (3 if ticket == "t3" else 0)
	var gate := _gate([2, 3], 0, identity)
	gate.admit(10, "t2")
	gate.mark_loaded(2)
	gate.admit(11, "t3")
	_advance_s(11.0, gate)
	check(gate.phase == MpMatchGate.Phase.RUNNING and _events.has("started load_timeout"), "the load timeout starts the match")
	check(gate.is_abandoned(3) and _events.has("abandoned 3 not_loaded true"), "the seat that did not load is out: not_loaded")
	_done(gate)


func test_give_up() -> void:
	var identity := func(_peer: int, ticket: String) -> int: return 2 if ticket == "t2" else (3 if ticket == "t3" else 0)
	var gate := _gate([2, 3], 0, identity)
	gate.admit(10, "t2")
	gate.admit(11, "t3")
	gate.mark_loaded(2)
	gate.give_up(3, "no_pick")
	check(gate.is_abandoned(3) and _events.has("abandoned 3 no_pick true"), "give_up abandons with its own reason")
	check(gate.phase == MpMatchGate.Phase.RUNNING, "and the match stops waiting for it")
	_done(gate)


func test_all_gone() -> void:
	var gate := _gate([2, 3])
	gate.admit(10, "")
	gate.admit(11, "")
	gate.mark_loaded(2)
	gate.mark_loaded(3)
	gate.mark_left(2)
	gate.mark_left(3)
	_advance_s(3.0, gate)
	check(not _events.has("all_gone") and not gate.is_abandoned(2), "everybody away within the grace: it waits")
	_advance_s(3.0, gate)
	check(_events.has("all_gone") and not gate.is_abandoned(2) and not gate.is_abandoned(3), "everybody past the grace: all_gone, nobody abandoned")
	_done(gate)


func test_listen_host_abandons_when_every_client_is_gone() -> void:
	var gate := _gate([2, 3])
	gate.host_present = true
	gate.admit(10, "")
	gate.admit(11, "")
	gate.mark_loaded(2)
	gate.mark_loaded(3)
	gate.mark_left(2)
	gate.mark_left(3)
	_advance_s(6.0, gate)
	check(not _events.has("all_gone") and _events.has("abandoned 2 grace_over true") and _events.has("abandoned 3 grace_over true"),
		"a listen host still plays: every client past the grace is abandoned, no all_gone")
	_done(gate)


func test_host_starts_now() -> void:
	var gate := MpMatchGate.new()
	tree.root.add_child(gate)
	gate.host_present = true
	gate.arm([2, 3] as Array[int])
	check(not gate.can_start_now(), "no client loaded: the host cannot start yet")
	gate.admit(10, "")
	gate.mark_loaded(2)
	check(gate.can_start_now() and gate.start_now(), "one client loaded: the host starts with it")
	check(gate.phase == MpMatchGate.Phase.RUNNING and gate.expected_slots() == [2], "the free seat closed at the start")
	_done(gate)
