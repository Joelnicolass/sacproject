class_name OnlineTicket
extends RefCounted

## The Sacrifice part of the ticket of an online room this player hosts, built like a «Servidor local»'s: the map, the mode,
## the options and the seed, the host's pick in seat 1 and every other seat of the mode left open (each friend sends his own pick
## when he is admitted, PickBoard checks it). The kit adds the tokens of the seats and the relay. Only people: no AI seats online.
## Not: the room (MpOnline), the check of a pick on admission (PickBoard), the reading of the ticket in the match (TicketPlan).

const HOST_SLOT := 1


## Empty when the rules refuse `options` (a map without a start for each seat of the mode, an unknown key).
static func build(host_pick: WizardPick, options: Dictionary) -> Dictionary:
	var rules := SacrificeRoomRules.new()
	# Not in the tree, so its _ready does not run: the test maps follow the same flag here.
	rules.include_test_maps = MpBoot.user_flag("room-test-maps")
	var ticket := _build_with(rules, host_pick, options)
	rules.free()
	return ticket


## The players of the room this ticket opens (the host counts).
static func players_of(ticket: Dictionary) -> int:
	return (ticket.get("seats", []) as Array).size()


static func _build_with(
	rules: SacrificeRoomRules, host_pick: WizardPick, options: Dictionary
) -> Dictionary:
	if host_pick == null or not rules.are_options_valid(options):
		return {}
	var seats: Array = [{"slot": HOST_SLOT, "token": "", "meta": MatchWire.encode_pick(host_pick)}]
	var open_picks: Array = []
	for slot in range(HOST_SLOT + 1, rules.seat_count_for(options) + 1):
		seats.append({"slot": slot, "token": "", "meta": {}})
		open_picks.append(slot)
	var ticket := rules.build_ticket(seats, options)
	# The kit writes the token of each seat; the rows here carry only the slot and the pick.
	for row: Dictionary in ticket["seats"]:
		row.erase("token")
	ticket["open_picks"] = open_picks
	# The rules' own generator is seeded in their _ready, which a node outside the tree never runs.
	ticket["seed"] = MatchSeed.draw()
	return ticket
