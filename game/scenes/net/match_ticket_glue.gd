class_name MatchTicketGlue
extends Node

## RFC-034 034e: the Sacrifice side of a dedicated that the room server launched (`--match-ticket-file`).
## SacrificeFlow instances it only in that process. It gives the match agent (kit) its Sacrifice meaning:
## - the ticket becomes what the match needs: the pick of each slot, the options (MatchSetup) and the seed;
## - the result of the match (MatchState) is reported to the agent, which writes result.json and tells the clients;
## - a slot that stays away more than `rejoin_grace_s` loses (`abandon`); with everybody away the match is `empty`.
## The pick channel of the clients is ignored (SacrificeFlow): the pick was closed in the lobby.
## The match does not start until every seat of the ticket has loaded its world: the tree stays paused (so `MatchClock`
## and the whole simulation wait) from the start of the process until each seat sent `world_ready`. A seat that has not
## loaded `load_timeout_s` after the first admission counts as away for good (`abandon`). A slow client never misses the start.
## RFC-034 034g (F184): a seat that drops keeps its slot for `rejoin_grace_s`. The kit lets the same ticket back in (a third
## client with that ticket, or the same one after the grace, is turned away). The world keeps the seat's state meanwhile: the
## wizard stands still where it was, its creatures and altar go on, and the match is not paused for the seat. The log tells it
## (`slot N mago … (al irse)` / `(al volver)`) so a run can compare both.
## Test hook, not a rule: `--force-defeat-slot=N --force-defeat-after-ticks=T` defeats slot N T ticks after the
## first player was admitted, so a run ends without playing the match out.

## The agent of the kit (admission, heartbeat, result.json). Null if the ticket was not usable.
var agent: MpMatchAgent

var _seat_metas: Dictionary = {}
var _setup := MatchSetup.new()
## slot -> ms since the slot is away (a slot never admitted counts from the ticket's expiry).
var _away_since_ms: Dictionary = {}
var _seat_count: int = 0
var _match_state: MatchState
var _first_admit_tick: int = -1
var _force_slot: int = 0
var _force_ticks: int = 0
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
	_force_slot = int(MpBoot.user_value("force-defeat-slot", "0"))
	_force_ticks = int(MpBoot.user_value("force-defeat-after-ticks", "0"))
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
	return setup


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
	if _forced or _force_slot <= 0 or _force_ticks <= 0 or _first_admit_tick < 0 or _match_state == null:
		return
	if MatchClock.now() - _first_admit_tick < _force_ticks:
		return
	_forced = true
	for child in _match_state.get_children():
		if child is DefeatRule:
			print("partida %s: derrota forzada del slot %d (prueba)" % [agent.match_id, _force_slot])
			(child as DefeatRule).defeat(_force_slot)
			return


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
	_report({
		"winner_slot": _match_state.winner_slot, "defeated_slots": defeated, "reason": "result",
	})


## A slot away for more than `rejoin_grace_s` is defeated. The one left standing wins; with all of them gone,
## the match is `empty` and has no winner. A slot that is away but still inside the grace keeps the match open.
func _check_abandon() -> void:
	var now := MpMatchFiles.now_ms()
	var grace_ms := int(agent.config.rejoin_grace_s * 1000.0)
	var gone: Array = []
	for slot in _away_since_ms.keys():
		if now - int(_away_since_ms[slot]) > grace_ms:
			gone.append(int(slot))
	if gone.is_empty() or gone.size() < _away_since_ms.size():
		return
	gone.sort()
	var present := _seat_count - _away_since_ms.size()
	if present == 1:
		var winner := 0
		for slot in _seat_metas.keys():
			if not _away_since_ms.has(slot):
				winner = int(slot)
		_report({"winner_slot": winner, "defeated_slots": gone, "reason": "abandon"})
	elif present == 0:
		_report({"winner_slot": 0, "defeated_slots": gone, "reason": "empty"})


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
