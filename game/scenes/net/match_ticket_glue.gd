class_name MatchTicketGlue
extends Node

## RFC-034 034e: the Sacrifice side of a dedicated that the room server launched (`--match-ticket-file`).
## SacrificeFlow instances it only in that process. It gives the match agent (kit) its Sacrifice meaning:
## - the ticket becomes what the match needs: the pick of each slot, the options (MatchSetup) and the seed;
## - the result of the match (MatchState) is reported to the agent, which writes result.json and tells the clients;
## - a slot that stays away more than `rejoin_grace_s` loses (`abandon`): the world defeats it and the match goes on until one
##   team is left (RFC-049 049f); with everybody away the match is `empty`. With two seats and no allies this is the old 1v1 rule.
## - RFC-049 049f (ticket v2): `seats` has only the humans (rows with a token); the bots are `ai_seats` [{slot, god}], which
##   SacrificeFlow seats as AI. The match waits for the humans only. `mode` names the game mode.
## The pick channel of the clients is ignored (SacrificeFlow): the pick was closed in the lobby.
## The match does not start until every seat of the ticket has loaded its world: the tree stays paused (so `MatchClock`
## and the whole simulation wait) from the start of the process until each seat sent `world_ready`. A seat that has not
## loaded `load_timeout_s` after the first admission counts as away for good (`abandon`). A slow client never misses the start.
## RFC-034 034g (F184): a seat that drops keeps its slot for `rejoin_grace_s`. The kit lets the same ticket back in (a third
## client with that ticket, or the same one after the grace, is turned away). The world keeps the seat's state meanwhile: the
## wizard stands still where it was, its creatures and altar go on, and the match is not paused for the seat. The log tells it
## (`slot N mago … (al irse)` / `(al volver)`) so a run can compare both.
## Test hook, not a rule: `--force-defeat-slot=N[,M…] --force-defeat-after-ticks=T` defeats those slots T ticks after the
## first player was admitted, so a run ends without playing the match out. `--force-defeat-when-file=PATH` (F350) defeats them as soon
## as that file exists (after the first admission), so a test that must keep the match alive until some other process finishes does not
## depend on how many ticks per second the machine runs.

## The agent of the kit (admission, heartbeat, result.json). Null if the ticket was not usable.
var agent: MpMatchAgent

var _seat_metas: Dictionary = {}
var _setup := MatchSetup.new()
## slot -> ms since the slot is away (a slot never admitted counts from the ticket's expiry).
var _away_since_ms: Dictionary = {}
var _seat_count: int = 0
var _match_state: MatchState
var _first_admit_tick: int = -1
var _force_slots: Array[int] = []
var _force_ticks: int = 0
var _force_file: String = ""
var _forced: bool = false
## True while the simulation waits for the seats to load (the tree is paused by this node).
var _holding: bool = false
var _hold_started_ms: int = 0
var _loaded_slots: Dictionary = {}
## Slots admitted at least once: a second admission is a rejoin.
var _admitted_slots: Dictionary = {}
## RFC-034 034m: slots whose pick the ticket leaves open (the seat chooses its own on admission). The world does not start
## until every one is in; a seat that never sends a valid pick counts as away after `load_timeout_s`.
var _open_picks: Dictionary = {}
## Slots already defeated for staying away past the grace (the world was told once).
var _abandoned: Dictionary = {}
## True while `_check_abandon` defeats a seat: a result that comes out of it is an `abandon`.
var _abandoning: bool = false


func _ready() -> void:
	agent = MpMatchAgent.new()
	agent.name = "Agent"
	add_child(agent)
	if agent.ticket.is_empty():
		return
	for seat in agent.ticket.get("seats", []):
		var row: Dictionary = seat
		var slot := int(row["slot"])
		_seat_metas[slot] = row.get("meta", {})
		_away_since_ms[slot] = int(agent.ticket.get("expires_ms", 0))
	_seat_count = _seat_metas.size()
	for slot in agent.ticket.get("open_picks", []):
		_open_picks[int(slot)] = true
	_setup = setup_from_ticket(agent.ticket)
	## `--match-args=` splits on commas, so a list of slots there is written `3+4`.
	for part in MpBoot.user_value("force-defeat-slot", "").replace("+", ",").split(",", false):
		if int(part) > 0:
			_force_slots.append(int(part))
	_force_ticks = int(MpBoot.user_value("force-defeat-after-ticks", "0"))
	_force_file = MpBoot.user_value("force-defeat-when-file", "")
	MpKit.peer_joined.connect(_on_peer_joined)
	MpKit.peer_left.connect(_on_peer_left)
	MpKit.client_world_ready.connect(_on_world_ready)
	## ALWAYS: this node and its agent (heartbeat, idle, result) keep working while the simulation waits.
	process_mode = Node.PROCESS_MODE_ALWAYS
	## `--no-load-hold` (tests whose clients never load the world, like run_034e) skips the wait.
	_holding = not MpBoot.user_flag("no-load-hold")
	get_tree().paused = _holding
	get_tree().node_added.connect(_on_node_added)
	print("partida %s: ticket con %d asientos, semilla %d, nivel %d" % [agent.match_id, _seat_count, _setup.match_seed, _setup.level])
	print("partida %s: mapa %s modo %s, %d IA" % [
		agent.match_id, str(agent.ticket.get("world", MapCatalog.DEFAULT_TAG)), str(agent.ticket.get("mode", GameModeCatalog.DEFAULT_TAG)),
		ai_seats().size()])


## slot -> the `meta` (pick) the lobby validated for that seat. Raw: the flow sanitizes it again.
func seat_metas() -> Dictionary:
	return _seat_metas.duplicate(true)


## True while the seat `slot` has not sent its (valid) pick.
func is_pick_open(slot: int) -> bool:
	return _open_picks.has(slot)


## The pick of `slot` arrived and was valid.
func close_pick(slot: int) -> void:
	_open_picks.erase(slot)


func picks_pending() -> bool:
	return not _open_picks.is_empty()


## The options and the seed of the ticket.
func match_setup() -> MatchSetup:
	return _setup.copy()


## The MatchSetup a ticket asks for: its options and its seed (-1 / 0 = what the rules say).
## The ticket comes from JSON: every number is a float there.
static func setup_from_ticket(ticket: Dictionary) -> MatchSetup:
	var setup := MatchSetup.new()
	var options: Dictionary = ticket.get("options", {})
	setup.level = int(options.get("level", 0))
	if options.has("friendly_fire"):
		setup.friendly_fire = 1 if bool(options["friendly_fire"]) else 0
	if options.has("drop_soul"):
		setup.drop_soul = 1 if bool(options["drop_soul"]) else 0
	setup.starting_souls = int(options.get("starting_souls", -1))
	setup.match_seed = int(ticket.get("seed", 0))
	setup.map_tag = StringName(str(ticket.get("world", "")))
	setup.mode_tag = StringName(str(ticket.get("mode", "")))
	return setup


## RFC-049 049a: the dedicated checks the map of the ticket again (the room server already did): a ticket without `world` plays
## the default map; one that names a map the catalog does not have is a `bad_ticket`.
## RFC-049 049f: the same for the `mode` (a ticket without it is a 1v1, a v1 ticket), and the map must fit it.
static func world_is_valid(ticket: Dictionary) -> bool:
	var world := str(ticket.get("world", ""))
	if not world.is_empty() and MapCatalog.shared().find(StringName(world)) == null:
		return false
	var mode := str(ticket.get("mode", ""))
	if not mode.is_empty() and GameModeCatalog.seats_of(StringName(mode)) == 0:
		return false
	return GameModeCatalog.map_fits_mode(StringName(world), StringName(mode))


## RFC-049 049f: the bots of the ticket as [{slot, god}] (a v1 ticket has none).
func ai_seats() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if agent == null:
		return out
	for row in agent.ticket.get("ai_seats", []):
		out.append({"slot": int(row["slot"]), "god": str(row.get("god", ""))})
	return out


## The mode tag of the ticket ("" = 1v1).
func mode_tag() -> StringName:
	return StringName(str(agent.ticket.get("mode", ""))) if agent != null else &""


func _process(_delta: float) -> void:
	if agent == null or agent.finished:
		return
	if _holding and _hold_started_ms > 0 and MpMatchFiles.now_ms() - _hold_started_ms > int(agent.config.load_timeout_s * 1000.0):
		_end_hold("tiempo de carga vencido")
		for slot in _seat_metas.keys():
			if not _loaded_slots.has(slot):
				_away_since_ms[slot] = 0
				print("partida %s: slot %d no cargó a tiempo, cuenta como abandono" % [agent.match_id, int(slot)])
	if picks_pending() and _hold_started_ms > 0 and MpMatchFiles.now_ms() - _hold_started_ms > int(agent.config.load_timeout_s * 1000.0):
		for slot in _open_picks.keys():
			_away_since_ms[slot] = 0
			print("partida %s: slot %d no mandó su pick a tiempo, cuenta como abandono" % [agent.match_id, int(slot)])
		_open_picks.clear()
	if _away_since_ms.is_empty():
		return
	_check_abandon()


func _physics_process(_delta: float) -> void:
	if _forced or _force_slots.is_empty() or (_force_ticks <= 0 and _force_file.is_empty()) or _first_admit_tick < 0 or _match_state == null:
		return
	if _force_file.is_empty():
		if MatchClock.now() - _first_admit_tick < _force_ticks:
			return
	elif not FileAccess.file_exists(_force_file):
		return
	var rule := _defeat_rule()
	if rule == null:
		return
	_forced = true
	for slot in _force_slots:
		print("partida %s: derrota forzada del slot %d (prueba)" % [agent.match_id, slot])
		rule.defeat(slot)


func _defeat_rule() -> DefeatRule:
	if _match_state == null:
		return null
	for child in _match_state.get_children():
		if child is DefeatRule:
			return child as DefeatRule
	return null


func _on_peer_joined(_peer_id: int, slot: int) -> void:
	if not _seat_metas.has(slot):
		return
	_away_since_ms.erase(slot)
	if _admitted_slots.has(slot):
		print("partida %s: slot %d volvió" % [agent.match_id, slot])
		print(_slot_state(slot, "al volver"))
		return
	_admitted_slots[slot] = true
	if _hold_started_ms == 0:
		_hold_started_ms = MpMatchFiles.now_ms()
	## Without the wait (`--no-load-hold`) the count of the forced defeat starts at the first admission, as before.
	if not _holding and _first_admit_tick < 0:
		_first_admit_tick = MatchClock.now()
	print("partida %s: slot %d adentro" % [agent.match_id, slot])


## A client finished loading its world. With every seat loaded the simulation starts, for all at the same tick 0.
func _on_world_ready(peer_id: int) -> void:
	var slot := MpKit.slot_for_peer(peer_id)
	if not _seat_metas.has(slot) or _loaded_slots.has(slot):
		return
	_loaded_slots[slot] = true
	print("partida %s: slot %d cargó el mundo (%d/%d)" % [agent.match_id, slot, _loaded_slots.size(), _seat_count])
	if _loaded_slots.size() == _seat_count:
		_end_hold("todos cargaron")


func _end_hold(why: String) -> void:
	if not _holding:
		return
	_holding = false
	get_tree().paused = false
	_first_admit_tick = MatchClock.now()
	print("partida %s: la simulación arranca (%s)" % [agent.match_id, why])


func _on_peer_left(_peer_id: int, slot: int) -> void:
	if not _seat_metas.has(slot) or agent.finished:
		return
	_away_since_ms[slot] = MpMatchFiles.now_ms()
	print("partida %s: slot %d se fue" % [agent.match_id, slot])
	print(_slot_state(slot, "al irse"))


## One log line with what the world holds for `slot`: its wizard (where it stands) and its living creatures.
func _slot_state(slot: int, when: String) -> String:
	var wizard := "sin mago"
	for node in get_tree().get_nodes_in_group("wizard"):
		if int(node.get("owner_slot")) == slot and node is Node3D:
			var at := (node as Node3D).global_position
			wizard = "mago en %.1f %.1f" % [at.x, at.z]
			break
	var creatures := 0
	for node in get_tree().get_nodes_in_group("unit"):
		if int(node.get("owner_slot")) == slot and not node.is_queued_for_deletion():
			creatures += 1
	return "partida %s: slot %d %s, %d criaturas (%s)" % [agent.match_id, slot, wizard, creatures, when]


func _on_node_added(node: Node) -> void:
	if node is MatchState and _match_state == null:
		_match_state = node as MatchState
		_match_state.result_changed.connect(_on_result_changed)
		get_tree().node_added.disconnect(_on_node_added)


func _on_result_changed() -> void:
	if _match_state == null or not _match_state.ended:
		return
	var defeated: Array = []
	for slot in _match_state.defeated_slots:
		defeated.append(slot)
	var winners: Array = []
	for slot in _match_state.winner_slots:
		winners.append(slot)
	## The abandon of a seat defeated the last team standing against the winners: the room reads it as an abandon.
	_report({
		"winner_slot": _match_state.winner_slot, "winner_slots": winners, "defeated_slots": defeated,
		"reason": "abandon" if _abandoning else "result",
	})


## A slot away for more than `rejoin_grace_s` loses (RFC-049 049f): the world defeats it and the match goes on until one team is
## left (the rule of the mode decides, as for any defeat). The result of that is an `abandon`. With every human gone the match is
## `empty` and has no winner. A slot that is away but still inside the grace keeps the match open; with nobody present the match
## waits for the first of them. Before the world exists (a seat that never loaded) the teams of the mode are counted here.
func _check_abandon() -> void:
	var now := MpMatchFiles.now_ms()
	var grace_ms := int(agent.config.rejoin_grace_s * 1000.0)
	var gone: Array[int] = []
	for slot in _away_since_ms.keys():
		if now - int(_away_since_ms[slot]) > grace_ms:
			gone.append(int(slot))
	if gone.is_empty():
		return
	gone.sort()
	if gone.size() == _seat_count:
		_report({"winner_slot": 0, "winner_slots": [], "defeated_slots": gone, "reason": "empty"})
		return
	if _away_since_ms.size() == _seat_count:
		return
	var fresh: Array[int] = []
	for slot in gone:
		if not _abandoned.has(slot):
			fresh.append(slot)
	if fresh.is_empty():
		return
	var rule := _defeat_rule()
	if rule == null:
		for slot in fresh:
			_abandoned[slot] = true
		_report_abandon_without_world()
		return
	_abandoning = true
	for slot in fresh:
		_abandoned[slot] = true
		print("partida %s: slot %d abandonó y pierde" % [agent.match_id, slot])
		rule.defeat(slot)
	_abandoning = false


## No world yet: the seats that did not abandon (humans and AI) decide by the teams of the mode.
func _report_abandon_without_world() -> void:
	var tag := mode_tag()
	var total := maxi(GameModeCatalog.seats_of(tag), _seat_count + ai_seats().size())
	var teams: Dictionary = {}
	for slot in range(1, total + 1):
		if not _abandoned.has(slot):
			teams[GameModeCatalog.team_of_slot(tag, slot)] = true
	if teams.size() != 1:
		return
	var team: int = teams.keys()[0]
	var winners: Array = []
	for slot in range(1, total + 1):
		if GameModeCatalog.team_of_slot(tag, slot) == team:
			winners.append(slot)
	var defeated: Array = _abandoned.keys()
	defeated.sort()
	_report({"winner_slot": winners[0], "winner_slots": winners, "defeated_slots": defeated, "reason": "abandon"})


func _report(data: Dictionary) -> void:
	var out := data.duplicate(true)
	## What each seat played with (JSON keys are strings): lets the clients and the tests see the picks the dedicated applied.
	var played := {}
	for slot in SacrificeFlow.slot_picks.keys():
		played[str(slot)] = SacrificeFlow.slot_picks[slot]
	out["picks"] = played
	out["seed"] = MatchSeed.current
	out["ticks"] = MatchClock.now()
	print("partida %s: resultado %s" % [agent.match_id, JSON.stringify(out)])
	agent.report_result(out)
