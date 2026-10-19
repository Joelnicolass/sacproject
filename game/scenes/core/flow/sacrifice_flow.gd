extends MpFlow

signal slot_picks_changed

const PICK_CHANNEL := &"pick"
const SLOT_PICKS_CHANNEL := &"slot_picks"
## The seat of «Contra la IA» (RFC-024 024f): slot 2, the god drawn, Normal.
const VS_AI_SEAT := "res://data/ai/seat_vs_ai.tres"

## Local choice: {wizard: "cwa1", model: "serx", god: "persephone"}.
var pick: Dictionary = {"wizard": "cwa0", "model": "jnwr", "god": "james"}
## Server-validated picks by MpKit slot, replicated to clients.
var slot_picks: Dictionary = {}
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
	boot_path = "res://scenes/core/boot.tscn"
	## `--world=res://debug/….tscn` on the dedicated and its clients plays a debug scene online.
	world_path = MpBoot.user_value("world", "res://scenes/match/match.tscn")
	room_name = "High Noon"
	## RFC-034 034f: what the player reads when a join fails or the server goes away (the kit's defaults are English).
	joining_status = "Conectando con %s…"
	join_fail_status = "No se pudo entrar a la partida"
	bad_ip_status = "Dirección inválida"
	server_lost_status = "Se terminó la partida"
	max_players = 2
	advertise_lan = false
	start_when = StartWhen.DEDICATED_FIRST_CLIENT
	## Before super._ready(): MpKit.configure takes max_players there, so the one human gets slot 1 and the AI keeps slot 2.
	_read_dedicated_ai()
	_cli_setup = MatchSetup.from_cli()
	setup = _cli_setup.copy()
	## The room server (RFC-034): it never loads a world by itself.
	if MpBoot.role() == "room-server":
		start_when = StartWhen.MANUAL
	_arm_ticket_glue()
	MpKit.slot_assigned.connect(_on_slot_assigned)
	MpKit.custom_received.connect(_on_custom_received)
	MpKit.peer_left.connect(_on_peer_left)
	super._ready()
	if MpBoot.is_dedicated_process():
		print("dedicated listo puerto ", MpKit.port)


func set_pick(wizard_tag: String, god: String) -> void:
	var chosen := sanitize_pick({"wizard": wizard_tag, "god": god})
	if chosen.is_empty():
		return
	pick = chosen
	print("pick %s %s" % [pick["model"], pick["god"]])


func sanitize_pick(raw: Dictionary) -> Dictionary:
	var tag := str(raw.get("wizard", ""))
	var god := str(raw.get("god", ""))
	if not GameData.gods().has(god):
		return {}
	var wizard: WizardType = GameData.wizard(tag)
	if wizard != null:
		return {"wizard": wizard.tag, "model": wizard.model, "god": god}
	if GameData.is_loaded():
		return {}
	var model := str(raw.get("model", "")).validate_filename()
	if tag.is_empty() or model.is_empty():
		return {}
	return {"wizard": tag, "model": model, "god": god}


func pick_for(slot: int) -> Dictionary:
	if slot_picks.has(slot):
		return slot_picks[slot]
	if slot == MpKit.local_slot():
		return pick
	return {}


## Solo. `chosen` is what the boot chose (GameplayPrefs, RFC-031 031d): every field it sets wins over the flags of this
## process (boot > flag > rules); null keeps the flags.
func play_solo(chosen: MatchSetup = null) -> void:
	solo_ai_seats = []
	setup = _cli_setup.overlaid_by(chosen)
	_play_alone()


## «Contra la IA»: solo, with the AI in slot 2. `god` empty = drawn when the match starts. `chosen` is the boot's setup
## (GameplayPrefs + the level of %AiLevel, 1-9 for both wizards, 030d); its fields win over the flags.
func play_vs_ai(god: StringName = &"", chosen: MatchSetup = null) -> void:
	solo_ai_seats = [_vs_ai_seat(god)]
	setup = _cli_setup.overlaid_by(chosen)
	_play_alone()


func _play_alone() -> void:
	from_lobby = false
	super.play_solo()
	slot_picks = {MpKit.local_slot(): pick.duplicate()}
	slot_picks_changed.emit()


func host_lan() -> Error:
	from_lobby = false
	solo_ai_seats = []
	setup = _cli_setup.copy()
	return super.host_lan()


func return_to_boot() -> void:
	solo_ai_seats = []
	setup = _cli_setup.copy()
	super.return_to_boot()


## RFC-034 034e: joins the match process the room server assigned (`MpLobbyClient.match_ready`). The ticket is the token.
func join_from_lobby(host: String, p_port: int, token: String) -> Error:
	slot_picks = {}
	solo_ai_seats = []
	var err := join_endpoint(host, p_port, token)
	from_lobby = err == OK
	return err


## RFC-034 034m: joins a «Servidor local» (the host's own dedicated). The code is the credential of the seat. It is not a room:
## the way out of the match goes to the menu.
func join_local_server(host: String, p_port: int, code: String) -> Error:
	from_lobby = false
	slot_picks = {}
	solo_ai_seats = []
	return join_endpoint(host, p_port, code)


func join_lan(ip: String) -> Error:
	from_lobby = false
	slot_picks = {}
	solo_ai_seats = []
	return super.join_lan(ip)


## RFC-034 034f: the way out of a match (pause menu, end of the match, lost server) goes to the room screens when the match
## came from a room; the room is still there, with the result. Any other match goes to the menu.
func _go_boot() -> void:
	print("flujo: salida de la partida, desde sala: %s" % from_lobby)
	if from_lobby:
		from_lobby = false
		get_tree().change_scene_to_file(LOBBY_SCENE)
		return
	super._go_boot()


## Solo or server: the pick of an AI slot (AiRoster), published like a human's.
func set_ai_pick(slot: int, chosen: Dictionary) -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		return
	slot_picks[slot] = chosen
	if MpKit.is_networked():
		_publish_picks()
	else:
		slot_picks_changed.emit()


func _vs_ai_seat(god: StringName) -> AiSeat:
	var seat := (load(VS_AI_SEAT) as AiSeat).duplicate() as AiSeat
	## An unknown god is drawn by AiRoster (GameData is not ready yet when the dedicated reads its flags).
	if god != &"":
		seat.god = god
	return seat


## --ai-slots=2 [--ai-god=pyro] on the dedicated (RFC-024 §4). Only slot 2 for now (High Noon has two starts).
func _read_dedicated_ai() -> void:
	if not MpBoot.is_dedicated_process():
		return
	var raw := MpBoot.user_value("ai-slots", "")
	if raw.is_empty():
		return
	var seats: Array[AiSeat] = []
	for part in raw.split(",", false):
		var seat := _vs_ai_seat(StringName(MpBoot.user_value("ai-god", "")))
		seat.slot = int(part)
		if seat.slot >= 2 and seat.slot <= max_players:
			seats.append(seat)
	if seats.is_empty():
		push_warning("--ai-slots=%s: ningún slot válido" % raw)
		return
	solo_ai_seats = seats
	max_players = seats[0].slot - 1
	print("dedicado con ia en slots %s" % raw)


## The dedicated of a room-server match: the picks, the options and the seed come from the ticket.
func _arm_ticket_glue() -> void:
	if MpBoot.user_value("match-ticket-file", "").is_empty():
		return
	var glue := MatchTicketGlue.new()
	glue.name = "MatchTicketGlue"
	add_child(glue)
	if glue.agent == null or glue.agent.ticket.is_empty():
		glue.queue_free()
		return
	ticket_glue = glue
	var metas := glue.seat_metas()
	for slot in metas.keys():
		## RFC-034 034m: a seat whose pick the ticket leaves open (Servidor local) sends it on admission.
		if glue.is_pick_open(int(slot)):
			continue
		var chosen := sanitize_pick(metas[slot])
		slot_picks[int(slot)] = chosen if not chosen.is_empty() else pick.duplicate()
		print("partida %s: slot %d pick %s %s" % [glue.agent.match_id, int(slot), slot_picks[int(slot)]["model"], slot_picks[int(slot)]["god"]])
	setup = _cli_setup.overlaid_by(glue.match_setup())
	## The world waits for the open picks: the first admission does not start it (see `_accept_open_pick`).
	if glue.picks_pending():
		start_when = StartWhen.MANUAL


func _on_slot_assigned(_slot: int) -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		MpKit.send_custom(PICK_CHANNEL, pick)


func _on_custom_received(channel: StringName, data: Dictionary, from_peer: int) -> void:
	if channel == PICK_CHANNEL:
		_store_pick(data, from_peer)
	elif channel == SLOT_PICKS_CHANNEL and not MpKit.is_server():
		var picks: Variant = data.get("picks")
		if picks is Dictionary:
			slot_picks = picks
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
	var chosen := sanitize_pick(data)
	if chosen.is_empty():
		return
	slot_picks[slot] = chosen
	print("slot %d pick %s %s" % [slot, chosen["model"], chosen["god"]])
	_publish_picks()


## RFC-034 034m: the pick of a seat the ticket left open, checked by the same rules as a room's. An invalid one is rejected (the
## player is told `bad_pick` and may come back with the same credential and choose again). With every pick in, the world starts.
func _accept_open_pick(from_peer: int, slot: int, data: Dictionary) -> void:
	var chosen := sanitize_pick(data)
	if chosen.is_empty():
		print("partida %s: slot %d pick inválido, rechazado" % [ticket_glue.agent.match_id, slot])
		MpKit.reject_peer(from_peer, "bad_pick")
		return
	slot_picks[slot] = chosen
	ticket_glue.close_pick(slot)
	print("partida %s: slot %d pick %s %s (elegido al entrar)" % [ticket_glue.agent.match_id, slot, chosen["model"], chosen["god"]])
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
	MpKit.broadcast_custom(SLOT_PICKS_CHANNEL, {"picks": slot_picks})
	slot_picks_changed.emit()
