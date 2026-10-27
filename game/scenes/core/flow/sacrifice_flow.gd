extends MpFlow

## How a Sacrifice match starts, ends and comes back (solo, «Contra la IA», LAN, a room's dedicated, a «Servidor local»). It holds
## the local pick and the AI seats; PickBoard the picks by slot, ActiveMatch the map and the mode. It does not decide who may pick.

signal slot_picks_changed

## The room screens (the menu's «Salas online», and where a match from a room comes back to) and the «Servidor local» screen.
const LOBBY_SCENE := "res://scenes/ui/lobby/lobby_screen.tscn"
const LOCAL_SERVER_SCENE := "res://scenes/ui/local_server/local_server_screen.tscn"

## The pick the menu starts with (Jadugarr, James). Change it in the inspector of `sacrifice_flow.tscn`.
@export var default_pick: WizardPick
## The seat of «Contra la IA»: slot 2, the god drawn, Normal. Drag another AiSeat to change the rival.
@export var vs_ai_seat: AiSeat
## The picks by slot (a child of this scene).
@export var board: PickBoard
## The story of each seat in the server's log, and the defeat of a seat that abandoned (a child of this scene).
@export var presence: SeatPresence
## The black screen while a match loads (a child of this scene). Empty = no screen; the load is the same.
@export var loading_screen: LoadingScreen

## Local choice. Never null after `_ready`.
var pick: WizardPick
## True while the match in course came from a room: leaving it lands in the room screens, not the menu.
var from_lobby := false
## The AI seats of the match this process simulates (AiRoster reads them): «Contra la IA», or a dedicated with bots. Empty = humans only.
var solo_ai_seats: Array[AiSeat] = []
## What the next match overrides of its rules (level, souls, friendly fire, seed, land, map, mode): the menu's choice over the flags.
var setup := MatchSetup.new()
## The picks by MpKit slot, replicated to clients (they live in `board`).
var slot_picks: Dictionary[int, WizardPick]:
	get:
		return board.picks
## The flags of this process, read once; every reset starts here.
var _cli_setup := MatchSetup.new()


func _ready() -> void:
	pick = default_pick.duplicate() as WizardPick
	boot_path = "res://scenes/core/boot.tscn"
	## `--world=res://<scene>.tscn` on the dedicated and its clients plays another world scene online.
	world_path = MpBoot.user_value("world", "res://scenes/match/match.tscn")
	joining_status = tr("UI_FLOW_JOINING")
	join_fail_status = tr("UI_FLOW_JOIN_FAIL")
	bad_ip_status = tr("UI_FLOW_BAD_IP")
	server_lost_status = tr("UI_FLOW_SERVER_LOST")
	advertise_lan = false
	start_when = StartWhen.DEDICATED_FIRST_CLIENT
	## Before super._ready(): MpKit.configure takes max_players there, so the one human gets slot 1 and the AI keeps slot 2.
	var plan := LaunchFlags.read(vs_ai_seat, ActiveMatch.seats())
	max_players = plan.max_players
	solo_ai_seats = plan.ai_seats
	_cli_setup = plan.setup
	setup = _cli_setup.copy()
	## The room server never loads a world by itself.
	if MpBoot.role() == "room-server":
		start_when = StartWhen.MANUAL
	if not _arm_ticket_glue():
		return
	if loading_screen != null:
		world_load_progressed.connect(loading_screen.show_progress)
	board.changed.connect(slot_picks_changed.emit)
	board.complete.connect(start_match)
	MpKit.slot_assigned.connect(func(_slot: int) -> void: board.announce(pick))
	super._ready()
	if MpBoot.is_dedicated_process():
		print("dedicated listo puerto ", MpKit.port)


func set_pick(chosen: WizardPick) -> void:
	if chosen == null or not chosen.is_complete():
		return
	pick = chosen
	print("pick %s %s" % [pick.wizard.model_id(), pick.god.id()])


## The pick of `slot`: the one the server published, or the local one for the local slot; null if none.
func pick_for(slot: int) -> WizardPick:
	if slot_picks.has(slot):
		return slot_picks[slot]
	return pick if slot == MpKit.local_slot() else null


## Solo. `chosen` is what the menu chose: every field it sets wins over the flags of this process; null keeps the flags.
func play_solo(chosen: MatchSetup = null) -> void:
	solo_ai_seats = []
	setup = _cli_setup.overlaid_by(chosen)
	_play_alone()


## «Contra la IA»: solo, with the AI in every seat but the player's. `god` null = drawn when the match starts.
func play_vs_ai(god: GodType = null, chosen: MatchSetup = null) -> void:
	setup = _cli_setup.overlaid_by(chosen)
	## Decided now (idempotent) to know how many seats the mode has.
	_apply_match_choice()
	solo_ai_seats = vs_ai_seat.for_seats(ActiveMatch.seats(), god)
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
	super.return_to_boot()


## The place where a match gets its map, its mode and its seed: right before the world loads, in the process that simulates. A
## client does not choose: the dedicated tells it (snapshot). Online the seed is drawn here once per match (`setup` keeps it until
## the next reset), so the snapshot carries the same one to every peer.
func _apply_match_choice() -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		return
	ActiveMatch.choose(setup.map, setup.mode)
	if MpKit.is_networked() and setup.match_seed <= 0:
		setup.match_seed = MatchSeed.draw()
	ActiveMatch.choose_seed(setup.match_seed)


## The map and the mode reach the clients before the order to load the world.
func snapshot_for_joiner() -> Dictionary:
	return super.snapshot_for_joiner().merged(MatchWire.encode_choice(), true)


func _on_flow_snapshot(data: Dictionary) -> void:
	super._on_flow_snapshot(data)
	if not MpKit.is_networked() or not MpKit.is_server():
		MatchWire.decode_choice(data)


func _begin_match() -> void:
	_apply_match_choice()
	super._begin_match()


func _before_world_load() -> void:
	_apply_match_choice()


## Read on the loading thread beside the world: what the match will spawn (the gods and wizards of its seats).
func _extra_world_loads() -> PackedStringArray:
	return ActiveMatch.load_paths()


## Joins the match process the room server assigned (`MpLobbyClient.match_ready`). The ticket is the token.
func join_from_lobby(host: String, p_port: int, token: String) -> Error:
	_forget_local_match()
	var err := join_endpoint(host, p_port, token)
	from_lobby = err == OK
	return err


## Joins a «Servidor local» (the host's own dedicated; the code is the seat's credential). It is not a room: out goes to the menu.
func join_local_server(host: String, p_port: int, code: String) -> Error:
	_forget_local_match()
	return join_endpoint(host, p_port, code)


func join_lan(ip: String) -> Error:
	_forget_local_match()
	return super.join_lan(ip)


## Joining somebody else's match: nothing of a local one stays (picks, AI seats, the room mark).
func _forget_local_match() -> void:
	from_lobby = false
	slot_picks.clear()
	solo_ai_seats = []


## What a client turned away by the door of the match reads in the status line (the «Servidor local» texts).
func rejection_text(reason: String) -> String:
	return LocalServerText.rejection_text(reason)


## The way out of a match (pause menu, end, lost server): the room screens if it came from a room, else the menu.
func _go_boot() -> void:
	ActiveMatch.forget()
	print("flujo: salida de la partida, desde sala: %s" % from_lobby)
	if from_lobby:
		from_lobby = false
		get_tree().change_scene_to_file(LOBBY_SCENE)
		return
	super._go_boot()


## The dedicated of a room-server match takes its picks, options and seed from the ticket. False = unplayable ticket (it quits).
func _arm_ticket_glue() -> bool:
	var glue := MatchTicketGlue.attach(self)
	if glue == null:
		return true
	if glue.rejected:
		return false
	board.ticket_glue = glue
	glue.presence = presence
	presence.log_prefix = "partida %s: " % glue.agent.match_id
	var plan := TicketPlan.read(glue, vs_ai_seat, pick, max_players)
	max_players = plan.max_players
	if not plan.ai_seats.is_empty():
		solo_ai_seats = plan.ai_seats
	slot_picks.merge(plan.picks)
	setup = _cli_setup.overlaid_by(plan.setup)
	## The world waits for the open picks: the first admission does not start it (see PickBoard).
	if plan.wait_for_picks:
		start_when = StartWhen.MANUAL
	return true
