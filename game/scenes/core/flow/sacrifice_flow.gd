extends MpFlow

signal slot_picks_changed

const PICK_CHANNEL := &"pick"
const SLOT_PICKS_CHANNEL := &"slot_picks"

## The pick the menu starts with (Jadugarr, James). Change it in the inspector of `sacrifice_flow.tscn`.
@export var default_pick: WizardPick
## The seat of «Contra la IA»: slot 2, the god drawn, Normal. Drag another AiSeat to change the rival.
@export var vs_ai_seat: AiSeat

## Local choice. Never null after `_ready`.
var pick: WizardPick
## Server-validated picks by MpKit slot, replicated to clients.
var slot_picks: Dictionary[int, WizardPick] = {}
## RFC-034 034f: the room screens (the menu's «Salas online» and where a match from a room comes back to).
const LOBBY_SCENE := "res://scenes/ui/lobby/lobby_screen.tscn"
## RFC-034 034m: the menu's «Servidor local» (a dedicated on the player's PC, apart from the rooms).
const LOCAL_SERVER_SCENE := "res://scenes/ui/local_server/local_server_screen.tscn"

## RFC-034 034f: true while the match in course came from a room (`join_from_lobby`). Leaving it (the pause menu, the
## end of the match, a lost server) then lands in the room screens instead of the menu. Any other way to play clears it.
var from_lobby: bool = false
## RFC-024 024f: the AI seats of the match this process simulates when the rules bring none (AiRoster reads them):
## «Contra la IA» in solo, or the dedicated started with --ai-slots=2 [--ai-god=pyro]. Empty = only humans.
var solo_ai_seats: Array[AiSeat] = []
## RFC-031 031a2 (F140) / 031d (F143): what the next match overrides of its rules (level, friendly fire, drop soul,
## starting souls). HighNoon applies it on the authority. Solo and «Contra la IA» take the boot's choice (GameplayPrefs
## and %AiLevel) over the flags; the dedicated and the benches never go through the boot: only the flags of this process.
var setup := MatchSetup.new()
## The flags of this process (MatchSetup.from_cli), read once; every reset starts here.
var _cli_setup := MatchSetup.new()
## RFC-034 034e (F182): only in the dedicated a room server launched (`--match-ticket-file`). The ticket brings the picks,
## the options and the seed, so the `pick` channel of the clients is ignored and their picks are not erased when they leave.
var ticket_glue: MatchTicketGlue

func _ready() -> void:
	pick = default_pick.duplicate() as WizardPick
	boot_path = "res://scenes/core/boot.tscn"
	## `--world=res://debug/….tscn` on the dedicated and its clients plays a debug scene online.
	world_path = MpBoot.user_value("world", "res://scenes/match/match.tscn")
	room_name = "High Noon"
	## RFC-034 034f: what the player reads when a join fails or the server goes away (the kit's defaults are English).
	joining_status = tr("UI_FLOW_JOINING")
	join_fail_status = tr("UI_FLOW_JOIN_FAIL")
	bad_ip_status = tr("UI_FLOW_BAD_IP")
	server_lost_status = tr("UI_FLOW_SERVER_LOST")
	## RFC-049 049e (F294): the seats of the mode (`--mode=`, 1v1 by default) are the places of the match. The AI seats narrow it.
	max_players = _mode_seats()
	advertise_lan = false
	start_when = StartWhen.DEDICATED_FIRST_CLIENT
	## Before super._ready(): MpKit.configure takes max_players there, so the one human gets slot 1 and the AI keeps slot 2.
	_read_dedicated_ai()
	_cli_setup = MatchSetup.from_cli()
	setup = _cli_setup.copy()
	## The room server (RFC-034): it never loads a world by itself.
	if MpBoot.role() == "room-server":
		start_when = StartWhen.MANUAL
	if not _arm_ticket_glue():
		return
	MpKit.slot_assigned.connect(_on_slot_assigned)
	MpKit.custom_received.connect(_on_custom_received)
	MpKit.peer_left.connect(_on_peer_left)
	super._ready()
	if MpBoot.is_dedicated_process():
		print("dedicated listo puerto ", MpKit.port)


func set_pick(chosen: WizardPick) -> void:
	if chosen == null or not chosen.is_complete():
		return
	pick = chosen
	print("pick %s %s" % [pick.wizard.model, pick.god.id()])


## The pick of `slot`: the one the server published, or the local one for the local slot; null if none.
func pick_for(slot: int) -> WizardPick:
	if slot_picks.has(slot):
		return slot_picks[slot]
	if slot == MpKit.local_slot():
		return pick
	return null


## Solo. `chosen` is what the boot chose (GameplayPrefs, RFC-031 031d): every field it sets wins over the flags of this
## process (boot > flag > rules); null keeps the flags.
func play_solo(chosen: MatchSetup = null) -> void:
	solo_ai_seats = []
	setup = _cli_setup.overlaid_by(chosen)
	_play_alone()


## «Contra la IA»: solo, with the AI in every seat but the player's (slot 2 in a 1v1; with a mode, slots 2..seats: in a 2v2 the
## player has an AI ally and two AI foes). `god` null = drawn when the match starts. `chosen` is the boot's setup
## (GameplayPrefs + the level of %AiLevel, 1-9 for both wizards, 030d); its fields win over the flags.
func play_vs_ai(god: GodType = null, chosen: MatchSetup = null) -> void:
	setup = _cli_setup.overlaid_by(chosen)
	## The map and the mode are decided now (the same call that runs when the world loads, idempotent) to know how many seats there are.
	_apply_match_choice()
	solo_ai_seats = _vs_ai_seats(god, GameModeCatalog.active_seats())
	_play_alone()


func _play_alone() -> void:
	from_lobby = false
	super.play_solo()
	slot_picks.clear()
	slot_picks[MpKit.local_slot()] = pick
	slot_picks_changed.emit()


func host_lan() -> Error:
	from_lobby = false
	solo_ai_seats = []
	setup = _cli_setup.copy()
	return super.host_lan()


func return_to_boot() -> void:
	solo_ai_seats = []
	setup = _cli_setup.copy()
	MapCatalog.reset()
	GameModeCatalog.reset()
	super.return_to_boot()


## RFC-049 049a (F290) / 049b (F291): THE place where a match gets its map and its mode. Nobody else calls `MapCatalog.use` or
## `GameModeCatalog.use` in the product. It runs right
## before the world loads, in the process that simulates (solo, «Contra la IA», the dedicated): the map the setup carries (the boot's
## choice, or the ticket's `world`), else `--map`, else the default. A client does not choose: the dedicated tells it (snapshot).
func _apply_match_choice() -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		return
	var tag := setup.map_tag
	if tag != &"" and MapCatalog.shared().find(tag) == null:
		push_error("SacrificeFlow: no hay mapa '%s'; se usa el de --map o el de siempre." % tag)
		tag = &""
	if tag == &"":
		MapCatalog.reset()
	else:
		MapCatalog.use(tag)
	var mode := setup.mode_tag
	if mode != &"" and GameModeCatalog.shared().find(mode) == null:
		push_error("SacrificeFlow: no hay modo '%s'; se usa el de --mode o el de siempre." % mode)
		mode = &""
	if mode == &"":
		GameModeCatalog.reset()
	else:
		GameModeCatalog.use(mode)
	## RFC-049 049d (F293): a mode needs a start for each of its seats. If the map has fewer, the match plays the default mode.
	var chosen_mode := GameModeCatalog.active()
	if not MapCatalog.active().fits(chosen_mode):
		push_error("SacrificeFlow: el modo '%s' pide %d asientos y el mapa '%s' tiene %d; se juega '%s'." % [
			chosen_mode.tag, chosen_mode.seats(), MapCatalog.current_tag(), MapCatalog.active().player_starts, GameModeCatalog.DEFAULT_TAG])
		GameModeCatalog.use(GameModeCatalog.DEFAULT_TAG)


## The map of the match goes to the clients before the order to load the world (the same reliable channel keeps the order).
func snapshot_for_joiner() -> Dictionary:
	var snap := super.snapshot_for_joiner()
	snap["map"] = String(MapCatalog.current_tag())
	snap["mode"] = String(GameModeCatalog.current_tag())
	return snap


func _on_flow_snapshot(data: Dictionary) -> void:
	super._on_flow_snapshot(data)
	if MpKit.is_networked() and MpKit.is_server():
		return
	var mode_raw := str(data.get("mode", ""))
	if not mode_raw.is_empty():
		if GameModeCatalog.shared().find(StringName(mode_raw)) == null:
			push_error("SacrificeFlow: el servidor mandó el modo '%s' y este cliente no lo tiene." % mode_raw)
		else:
			GameModeCatalog.use(StringName(mode_raw))
			print("modo de la partida %s (del servidor)" % mode_raw)
	var raw := str(data.get("map", ""))
	if raw.is_empty():
		return
	if MapCatalog.shared().find(StringName(raw)) == null:
		push_error("SacrificeFlow: el servidor mandó el mapa '%s' y este cliente no lo tiene." % raw)
		return
	MapCatalog.use(StringName(raw))
	print("mapa de la partida %s (del servidor)" % raw)


func _begin_match() -> void:
	_apply_match_choice()
	super._begin_match()


func goto_world() -> void:
	_apply_match_choice()
	super.goto_world()


## RFC-034 034e: joins the match process the room server assigned (`MpLobbyClient.match_ready`). The ticket is the token.
func join_from_lobby(host: String, p_port: int, token: String) -> Error:
	slot_picks.clear()
	solo_ai_seats = []
	var err := join_endpoint(host, p_port, token)
	from_lobby = err == OK
	return err


## RFC-034 034m: joins a «Servidor local» (the host's own dedicated). The code is the credential of the seat. It is not a room:
## the way out of the match goes to the menu.
func join_local_server(host: String, p_port: int, code: String) -> Error:
	from_lobby = false
	slot_picks.clear()
	solo_ai_seats = []
	return join_endpoint(host, p_port, code)


func join_lan(ip: String) -> Error:
	from_lobby = false
	slot_picks.clear()
	solo_ai_seats = []
	return super.join_lan(ip)


## RFC-034 034f: the way out of a match (pause menu, end of the match, lost server) goes to the room screens when the match
## came from a room; the room is still there, with the result. Any other match goes to the menu.
func _go_boot() -> void:
	MapCatalog.reset()
	GameModeCatalog.reset()
	print("flujo: salida de la partida, desde sala: %s" % from_lobby)
	if from_lobby:
		from_lobby = false
		get_tree().change_scene_to_file(LOBBY_SCENE)
		return
	super._go_boot()


## Solo or server: the pick of an AI slot (AiRoster), published like a human's.
func set_ai_pick(slot: int, chosen: WizardPick) -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		return
	slot_picks[slot] = chosen
	if MpKit.is_networked():
		_publish_picks()
	else:
		slot_picks_changed.emit()


func _vs_ai_seat(god: GodType, slot := 2) -> AiSeat:
	var seat := vs_ai_seat.duplicate() as AiSeat
	## No god (an empty or unknown id) is drawn by AiRoster.
	if god != null:
		seat.god = god
	seat.slot = slot
	return seat


## One AI seat for each slot from 2 to `seats`.
func _vs_ai_seats(god: GodType, seats: int) -> Array[AiSeat]:
	var found: Array[AiSeat] = []
	for slot in range(2, maxi(seats, 2) + 1):
		found.append(_vs_ai_seat(god, slot))
	return found


## The seats of the mode of this process (`--mode=`, else 1v1).
func _mode_seats() -> int:
	return GameModeCatalog.active_seats()


## --ai-slots=2,3,4 [--ai-god=pyro] on the dedicated (RFC-024 §4, 049e). Several slots, each inside the seats of the mode. The humans
## take the lowest slots, so the AI slots have to be the tail of the seats; `max_players` is the first AI slot - 1 (the seats an AI
## holds are never admitted to a person).
func _read_dedicated_ai() -> void:
	if not MpBoot.is_dedicated_process():
		return
	var raw := MpBoot.user_value("ai-slots", "")
	if raw.is_empty():
		return
	var slots: Array[int] = []
	for part in raw.split(",", false):
		var slot := int(part)
		if slot >= 2 and slot <= max_players and not slots.has(slot):
			slots.append(slot)
	if slots.is_empty():
		push_warning("--ai-slots=%s: ningún slot válido (van de 2 a %d, los asientos del modo)" % [raw, max_players])
		return
	slots.sort()
	var tail := slots.size() == max_players - slots[0] + 1
	if not tail:
		push_warning("--ai-slots=%s: los slots IA tendrían que ser la cola de los %d asientos; los humanos toman los más bajos" % [raw, max_players])
	var seats: Array[AiSeat] = []
	for slot in slots:
		seats.append(_vs_ai_seat(MatchWire.decode_god(MpBoot.user_value("ai-god", ""), true), slot))
	solo_ai_seats = seats
	max_players = slots[0] - 1
	print("dedicado con ia en slots %s" % str(slots))


## The dedicated of a room-server match: the picks, the options and the seed come from the ticket.
## Returns false when the ticket is not usable (a map the catalog does not have): the result `bad_ticket` is reported and the
## process quits, so `_ready` must stop there.
func _arm_ticket_glue() -> bool:
	if MpBoot.user_value("match-ticket-file", "").is_empty():
		return true
	var glue := MatchTicketGlue.new()
	glue.name = "MatchTicketGlue"
	add_child(glue)
	if glue.agent == null or glue.agent.ticket.is_empty():
		glue.queue_free()
		return true
	if not MatchTicketGlue.world_is_valid(glue.agent.ticket):
		push_error("partida %s: bad_ticket, el ticket pide el mapa '%s' y no existe" % [glue.agent.match_id, str(glue.agent.ticket.get("world", ""))])
		glue.agent.report_result({"winner_slot": 0, "defeated_slots": [], "reason": "bad_ticket"})
		get_tree().quit(1)
		return false
	ticket_glue = glue
	## RFC-049 049f (ticket v2): the seats are those of the ticket's mode (the humans take the slots of their tokens, so the
	## transport has room for all of them), and the bots of the ticket are the AI seats of this match.
	var ticket_seats := GameModeCatalog.seats_of(glue.mode_tag())
	if ticket_seats > 0:
		max_players = ticket_seats
	var ai_found: Array[AiSeat] = []
	for row in glue.ai_seats():
		var bot := _vs_ai_seat(MatchWire.decode_god(str(row["god"]), true), int(row["slot"]))
		## RFC-049 049h: the difficulty the host chose in the room (empty = the seat's own, Normal).
		var difficulty := AiSeat.difficulty_of(str(row.get("difficulty", "")))
		if difficulty != null:
			bot.difficulty = difficulty
		ai_found.append(bot)
	if not ai_found.is_empty():
		solo_ai_seats = ai_found
		var slots: Array[int] = []
		for seat in ai_found:
			slots.append(seat.slot)
		print("partida %s: ia en slots %s (del ticket)" % [glue.agent.match_id, str(slots)])
	var metas := glue.seat_metas()
	for slot in metas.keys():
		## RFC-034 034m: a seat whose pick the ticket leaves open (Servidor local) sends it on admission.
		if glue.is_pick_open(int(slot)):
			continue
		var chosen: WizardPick = MatchWire.decode_pick(metas[slot], true)
		slot_picks[int(slot)] = chosen if chosen != null else pick
		print("partida %s: slot %d pick %s %s" % [glue.agent.match_id, int(slot), slot_picks[int(slot)].wizard.model, slot_picks[int(slot)].god.id()])
	setup = _cli_setup.overlaid_by(glue.match_setup())
	## The world waits for the open picks: the first admission does not start it (see `_accept_open_pick`).
	if glue.picks_pending():
		start_when = StartWhen.MANUAL
	return true


func _on_slot_assigned(_slot: int) -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		MpKit.send_custom(PICK_CHANNEL, MatchWire.encode_pick(pick))


func _on_custom_received(channel: StringName, data: Dictionary, from_peer: int) -> void:
	if channel == PICK_CHANNEL:
		_store_pick(data, from_peer)
	elif channel == SLOT_PICKS_CHANNEL and not MpKit.is_server():
		var picks: Variant = data.get("picks")
		if picks is Dictionary:
			slot_picks = MatchWire.decode_picks(picks)
			slot_picks_changed.emit()


func _store_pick(data: Dictionary, from_peer: int) -> void:
	if not MpKit.is_server():
		return
	## The ticket closed the picks: the client that just got its slot only needs to hear them.
	if ticket_glue != null:
		var open_slot := MpKit.slot_for_peer(from_peer)
		if ticket_glue.is_pick_open(open_slot):
			_accept_open_pick(from_peer, open_slot, data)
			return
		_publish_picks()
		return
	var slot := MpKit.slot_for_peer(from_peer)
	if slot <= 0:
		return
	var chosen: WizardPick = MatchWire.decode_pick(data, true)
	if chosen == null:
		return
	slot_picks[slot] = chosen
	print("slot %d pick %s %s" % [slot, chosen.wizard.model, chosen.god.id()])
	_publish_picks()


## RFC-034 034m: the pick of a seat the ticket left open, checked by the same rules as a room's. An invalid one is rejected (the
## player is told `bad_pick` and may come back with the same credential and choose again). With every pick in, the world starts.
func _accept_open_pick(from_peer: int, slot: int, data: Dictionary) -> void:
	var chosen: WizardPick = MatchWire.decode_pick(data, true)
	if chosen == null:
		print("partida %s: slot %d pick inválido, rechazado" % [ticket_glue.agent.match_id, slot])
		MpKit.reject_peer(from_peer, "bad_pick")
		return
	slot_picks[slot] = chosen
	ticket_glue.close_pick(slot)
	print("partida %s: slot %d pick %s %s (elegido al entrar)" % [ticket_glue.agent.match_id, slot, chosen.wizard.model, chosen.god.id()])
	_publish_picks()
	if not ticket_glue.picks_pending():
		start_match()


func _on_peer_left(peer_id: int, slot: int) -> void:
	print("peer_left peer %d slot %d" % [peer_id, slot])
	if ticket_glue != null or not slot_picks.has(slot):
		return
	slot_picks.erase(slot)
	_publish_picks()


func _publish_picks() -> void:
	MpKit.broadcast_custom(SLOT_PICKS_CHANNEL, {"picks": MatchWire.encode_picks(slot_picks)})
	slot_picks_changed.emit()
