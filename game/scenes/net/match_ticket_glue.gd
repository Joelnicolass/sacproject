class_name MatchTicketGlue
extends Node

## RFC-034 034e: the Sacrifice side of a dedicated that the room server launched (`--match-ticket-file`).
## SacrificeFlow instances it only in that process. It gives the match agent (kit) its Sacrifice meaning:
## - the ticket becomes what the match needs: the pick of each slot, the options (MatchSetup) and the seed;
## - the result of the match (MatchState) is reported to the agent, which writes result.json and tells the clients;
## - a slot that stays away more than `rejoin_grace_s` loses (`abandon`); with everybody away the match is `empty`.
## The pick channel of the clients is ignored (SacrificeFlow): the pick was closed in the lobby.
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
	_setup = setup_from_ticket(agent.ticket)
	_force_slot = int(MpBoot.user_value("force-defeat-slot", "0"))
	_force_ticks = int(MpBoot.user_value("force-defeat-after-ticks", "0"))
	MpKit.peer_joined.connect(_on_peer_joined)
	MpKit.peer_left.connect(_on_peer_left)
	get_tree().node_added.connect(_on_node_added)
	print("partida %s: ticket con %d asientos, semilla %d, nivel %d" % [agent.match_id, _seat_count, _setup.match_seed, _setup.level])


## slot -> the `meta` (pick) the lobby validated for that seat. Raw: the flow sanitizes it again.
func seat_metas() -> Dictionary:
	return _seat_metas.duplicate(true)


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
	if agent == null or agent.finished or _away_since_ms.is_empty():
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
	if _first_admit_tick < 0:
		_first_admit_tick = MatchClock.now()
	print("partida %s: slot %d adentro" % [agent.match_id, slot])


func _on_peer_left(_peer_id: int, slot: int) -> void:
	if not _seat_metas.has(slot) or agent.finished:
		return
	_away_since_ms[slot] = MpMatchFiles.now_ms()
	print("partida %s: slot %d se fue" % [agent.match_id, slot])


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
	out["seed"] = MatchSeed.current
	out["ticks"] = MatchClock.now()
	print("partida %s: resultado %s" % [agent.match_id, JSON.stringify(out)])
	agent.report_result(out)
