class_name TicketPlan
extends RefCounted

## Reads the ticket a room server gave to a dedicated into a LaunchPlan: the seats of its mode, the bots as AI seats, the picks
## of the humans that are already chosen, the options and the seed. It changes nothing: SacrificeFlow applies the plan.
## It does not check the ticket (`MatchTicketGlue.world_is_valid` does, before this runs).


## `ai_seat` is the seat an AI takes; `fallback` the pick of a seat whose pick the ticket cannot read; `seats` the seats to keep when
## the ticket does not name a mode.
static func read(glue: MatchTicketGlue, ai_seat: AiSeat, fallback: WizardPick, seats: int) -> LaunchPlan:
	var plan := LaunchPlan.new()
	## The seats are those of the ticket's mode (the humans take the slots of their tokens, so the transport has room for all of
	## them), and the bots of the ticket are the AI seats of this match.
	var ticket_seats := GameModeCatalog.seats_of(glue.mode_tag())
	plan.max_players = ticket_seats if ticket_seats > 0 else seats
	var match_id := glue.agent.match_id
	for row in glue.ai_seats():
		var bot := ai_seat.for_slot(int(row["slot"]), MatchWire.decode_god(str(row["god"]), true))
		## The difficulty the host chose in the room (empty = the seat's own, Normal).
		var difficulty := AiSeat.difficulty_of(str(row.get("difficulty", "")))
		if difficulty != null:
			bot.difficulty = difficulty
		plan.ai_seats.append(bot)
	if not plan.ai_seats.is_empty():
		var slots: Array[int] = []
		for bot in plan.ai_seats:
			slots.append(bot.slot)
		print("partida %s: ia en slots %s (del ticket)" % [match_id, str(slots)])
	var metas := glue.seat_metas()
	for slot: int in metas.keys():
		## A seat whose pick the ticket leaves open (Servidor local) sends it on admission.
		if glue.is_pick_open(slot):
			continue
		var chosen: WizardPick = MatchWire.decode_pick(metas[slot], true)
		var kept: WizardPick = chosen if chosen != null else fallback
		plan.picks[slot] = kept
		print("partida %s: slot %d pick %s %s" % [match_id, slot, kept.wizard.model_id(), kept.god.id()])
	plan.setup = glue.match_setup()
	plan.wait_for_picks = glue.picks_pending()
	return plan
