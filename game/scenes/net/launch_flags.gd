class_name LaunchFlags
extends RefCounted

## Reads the command line of this process into a LaunchPlan: the overrides of the rules (`--level`, `--souls`, `--friendly-fire`,
## `--drop-soul`, `--match-seed`, `--biome`) and the AI seats of a dedicated (`--ai-slots`, `--ai-god`). The map and the mode
## (`--map`, `--mode`) are ActiveMatch's. It changes nothing: SacrificeFlow applies the plan it returns.
## Every flag it takes is told in the log. A bad value is a warning and the rules decide.
##


## `ai_seat` is the seat an AI takes in a dedicated; `seats` the seats of the mode.
static func read(ai_seat: AiSeat, seats: int) -> LaunchPlan:
	var plan := LaunchPlan.new()
	plan.max_players = seats
	_read_ai_slots(plan, ai_seat)
	_read_setup(plan.setup)
	return plan


## `--ai-slots=2,3,4 [--ai-god=pyro]` on the dedicated. Several slots, each inside the seats of the mode. The humans take the lowest
## slots, so the AI slots have to be the tail of the seats; `max_players` is the first AI slot - 1 (the seats an AI holds are never
## admitted to a person).
static func _read_ai_slots(plan: LaunchPlan, ai_seat: AiSeat) -> void:
	if not MpBoot.is_dedicated_process():
		return
	var raw := MpBoot.user_value("ai-slots", "")
	if raw.is_empty():
		return
	var slots: Array[int] = []
	for part in raw.split(",", false):
		var slot := int(part)
		if slot >= 2 and slot <= plan.max_players and not slots.has(slot):
			slots.append(slot)
	if slots.is_empty():
		push_warning(
			(
				"--ai-slots=%s: no valid slot (they go from 2 to %d, the seats of the mode)"
				% [raw, plan.max_players]
			)
		)
		return
	slots.sort()
	if slots.size() != plan.max_players - slots[0] + 1:
		push_warning(
			(
				"--ai-slots=%s: the AI slots should be the tail of the %d seats; the humans take the lowest"
				% [raw, plan.max_players]
			)
		)
	var god: GodType = MatchWire.decode_god(MpBoot.user_value("ai-god", ""), true)
	for slot in slots:
		plan.ai_seats.append(ai_seat.for_slot(slot, god))
	plan.max_players = slots[0] - 1
	print("dedicated with ai in slots %s" % str(slots))


static func _read_setup(setup: MatchSetup) -> void:
	var raw := MpBoot.user_value("level", "")
	if not raw.is_empty():
		var wanted := int(raw)
		if wanted >= 1 and wanted <= 9:
			setup.level = wanted
			print("wizard level %d (--level)" % wanted)
		else:
			push_warning("--level=%s: out of 1-9, the rules' is used" % raw)
	if MpBoot.user_flag("no-friendly-fire"):
		setup.friendly_fire = 0
	elif MpBoot.user_flag("friendly-fire"):
		setup.friendly_fire = 1
	if MpBoot.user_flag("no-drop-soul"):
		setup.drop_soul = 0
	elif MpBoot.user_flag("drop-soul"):
		setup.drop_soul = 1
	var souls := MpBoot.user_value("souls", "")
	if not souls.is_empty():
		if souls.is_valid_int() and int(souls) >= 0:
			setup.starting_souls = int(souls)
			print("starting souls %d (--souls)" % setup.starting_souls)
		else:
			push_warning("--souls=%s: not a number ≥ 0, the rules' are used" % souls)
	var wanted_seed := MpBoot.user_value("match-seed", "")
	if not wanted_seed.is_empty():
		if wanted_seed.is_valid_int() and int(wanted_seed) > 0:
			setup.match_seed = int(wanted_seed)
			print("match seed %d (--match-seed)" % setup.match_seed)
		else:
			push_warning("--match-seed=%s: not a number > 0, the rules' is used" % wanted_seed)
	var land := MpBoot.user_value("biome", "")
	if not land.is_empty():
		setup.biome = MatchWire.decode_god(land)
		if setup.biome == null:
			push_warning("--biome=%s: no god has that id, the land is drawn" % land)
