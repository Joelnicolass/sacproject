extends "res://addons/mp_kit/tests/mp_test.gd"

## Slots vs peer ids (MpIds): listen, dedicated, rejoin and ticket seats.


func test_listen_host_is_slot_one() -> void:
	var ids := MpIds.new()
	ids.max_players = 3
	ids.reset_host()
	check(ids.peer_id_for(1) == 1, "the host is peer 1 in slot 1")
	check(ids.assign_client(50) == 2, "the first client gets slot 2")
	check(ids.assign_client(60) == 3, "the second client gets slot 3")
	check(ids.assign_client(70) == 0, "a client over the cap gets no slot")


func test_dedicated_slots_start_at_one() -> void:
	var ids := MpIds.new()
	ids.max_players = 2
	ids.reset_dedicated()
	check(ids.local_slot == 0, "the dedicated has no player")
	check(ids.assign_client(50) == 1, "the first client of a dedicated is slot 1")
	check(ids.peer_id_for(1) == 50, "slot 1 maps to its peer")


func test_rejoin_takes_the_freed_slot() -> void:
	var ids := MpIds.new()
	ids.max_players = 2
	ids.reset_dedicated()
	ids.assign_client(50)
	ids.assign_client(60)
	check(ids.unbind_peer(50) == 1, "the slot of the peer that left is reported")
	check(ids.occupied_slots() == [2], "only slot 2 stays occupied")
	check(ids.assign_client(77) == 1, "a new peer takes the free slot")


func test_ticket_seat_is_fixed() -> void:
	var ids := MpIds.new()
	ids.max_players = 2
	ids.reset_dedicated()
	check(ids.bind_client(50, 2), "a ticket may seat a peer in slot 2 first")
	check(not ids.bind_client(60, 2), "another peer cannot take a seated slot")
	check(not ids.bind_client(60, 3), "a slot out of range is refused")
	check(not ids.bind_client(50, 1), "a seated peer cannot move to another slot")
