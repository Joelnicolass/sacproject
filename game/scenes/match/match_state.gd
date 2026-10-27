@tool
class_name MatchState
extends Node

## The state of the match: the state of every altar, the defeated sides and the winner. Single source
## for everyone (DefeatRule decides, the banner and the world read). The server (or solo) changes it
## and says so (`snapshot_changed`, `finished`); MatchStateNet carries it to the clients, which apply the snapshot.
## It knows nothing of the network.

## An altar changed state in this peer (the server's decision or an applied snapshot).
signal altar_state_changed(altar: Altar, state: Altar.State)
signal side_defeated(slot: int)
## The match has a result (a winner, or nobody left).
signal result_changed
## The rules of this match shown to the players changed: taken from the world (server, solo) or from a snapshot (client).
signal rules_changed
## The server (or solo) changed the state: whoever carries it (MatchStateNet) sends `to_snapshot()` to the clients.
signal snapshot_changed
## The match ended in this peer and `result()` is final; emitted after the last `snapshot_changed`.
signal finished

## The group the match state joins; whoever needs it reads it from here.
const GROUP := &"match_state"
const FALLBACK_COLLAPSE_S := 11.0

@export var rules: MatchRules
## Node whose subtree holds the altars of this match (the world).
@export var world: Node
## The node the wizards are spawned under (match.tscn: Wizards). On the authority every wizard that is or comes in there seats
## its slot; empty (a bench with no wizards) = every owner of an altar counts.
@export var wizards: Node

## 0 while the match has no winner. With teams (RFC-049 049b) it is the lowest slot of the winning team, kept for the room
## and the banner; `winner_slots` is the whole team and `won(slot)` the question to ask.
var winner_slot := 0
## RFC-049 049b (F291): every slot of the team that won (even an ally that fell before: P3), empty while there is no winner.
var winner_slots: Array[int] = []
## The team (SideRelations.team_of) of the winners; 0 with no winner.
var winner_team := 0
## RFC-049 049b: the slots with a wizard seated (human or AI), derived on the authority from the children of `wizards`. Only they count for the
## victory (sacengine altarSides, state.d:31493); the altar of an empty seat stays in the map and does not count (P4).
var seated_slots: Array[int] = []
var defeated_slots: Array[int] = []
## True once the match has a result, with or without a winner.
var ended := false
## F139 (RFC-031): the friendly fire of this match, as the server took it from the world's rules (take_rules) and the
## clients from the snapshot. Health reads it (Health._side_factor). Not `rules` of this node: a bench (ai_match) or the
## match setup changes only the world's rules, and this node keeps the product's.
var friendly_fire := false
var ally_damage_factor := 0.5
## RFC-031 031d (F143): the other two rules the player sees in Options → Jugabilidad, same channel as friendly_fire.
## The simulation reads world.rules (SoulPurse through WizardSpawner, SoulSystem); these are the copy the clients show.
var drop_soul := true
var starting_souls := 12

var _collapsing: Dictionary = {}
## A client printed the rule of the first snapshot.
var _rules_known := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	if is_authority():
		take_rules()
		_seat_wizards()
	for altar in altars():
		altar.state_changed.connect(_on_altar_state_changed.bind(altar))
	set_physics_process(is_authority())


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if world == null:
		warnings.append("Asigná en `world` el nodo que contiene los altares.")
	if rules == null:
		warnings.append("Asigná en `rules` las MatchRules.")
	return warnings


## The server decides; so does a game with no network (solo).
func is_authority() -> bool:
	return is_multiplayer_authority()


## Every altar under `world`, destroyed ones too, in the same order on every peer.
func altars() -> Array[Altar]:
	var found: Array[Altar] = []
	if world == null:
		return found
	for node in world.find_children("*", "Altar", true, false):
		found.append(node as Altar)
	found.sort_custom(_before)
	return found


func altars_of(slot: int) -> Array[Altar]:
	var found: Array[Altar] = []
	for altar in altars():
		if altar.owner_slot == slot:
			found.append(altar)
	return found


## An altar of that slot that stands, or is still falling (it is not defeated yet).
func has_live_altar(slot: int) -> bool:
	for altar in altars_of(slot):
		if not altar.is_destroyed():
			return true
	return false


## An altar of that slot in play: the wizard of that side can come back as a ghost.
func has_standing_altar(slot: int) -> bool:
	for altar in altars_of(slot):
		if altar.is_standing():
			return true
	return false


## The slots that own an altar and have a wizard seated (sacengine altarSides, state.d:30494-30500, 31493-31514), in order. A world
## where nobody was ever marked (a bench with no WizardSpawner) keeps every owner of an altar, as before 049b.
func sides() -> Array[int]:
	var found: Array[int] = []
	for altar in altars():
		if altar.owner_slot > 0 and not found.has(altar.owner_slot):
			if seated_slots.is_empty() or seated_slots.has(altar.owner_slot):
				found.append(altar.owner_slot)
	found.sort()
	return found


## Authority: a wizard sat in `slot` (a wizard under `wizards`; a bench may call it). Idempotent.
func mark_seated(slot: int) -> void:
	if slot <= 0 or seated_slots.has(slot):
		return
	seated_slots.append(slot)
	seated_slots.sort()
	publish()


## Authority: the wizards already under `wizards` (the listen host and solo spawn theirs before this node is ready) and every
## one that comes in later seat their slot. Derived from the tree, so the order of `_ready` does not matter.
func _seat_wizards() -> void:
	if wizards == null:
		return
	wizards.child_entered_tree.connect(_on_wizard_entered)
	for child in wizards.get_children():
		_on_wizard_entered(child)


func _on_wizard_entered(node: Node) -> void:
	if node is WizardBody:
		mark_seated((node as WizardBody).owner_slot)


func is_seated(slot: int) -> bool:
	return seated_slots.has(slot)


func is_defeated(slot: int) -> bool:
	return defeated_slots.has(slot)


func has_result() -> bool:
	return ended


## The slot is on the winning team (with or without having fallen earlier). False while there is no result.
func won(slot: int) -> bool:
	return ended and slot > 0 and winner_slots.has(slot)


## Server (or solo): the friendly fire of this match from the world's rules (never from `rules` of this node, RFC-031
## §2.2). A world with no MatchRules keeps the script defaults (off). Prints the rule once per call.
func take_rules() -> void:
	var source: Variant = world.get("rules") if world != null and "rules" in world else null
	var defaults := MatchRules.new()
	var from: MatchRules = source if source is MatchRules else defaults
	friendly_fire = from.friendly_fire
	ally_damage_factor = from.ally_damage_factor
	drop_soul = from.enable_drop_soul
	starting_souls = from.starting_souls
	_print_rules()
	rules_changed.emit()


func _print_rules() -> void:
	print("fuego amigo: %s" % ("sí (×%.2f)" % ally_damage_factor if friendly_fire else "no"))
	print("almas iniciales: %d · soltar almas: %s" % [starting_souls, "sí" if drop_soul else "no"])


func collapse_seconds() -> float:
	return rules.altar_collapse_s if rules else FALLBACK_COLLAPSE_S


## Server: the standing altars of `slot` start to fall; `by_slot` is who brought it down (0 = nobody:
## the wizard vanished). In collapse_seconds() they are DESTROYED. False if none was standing.
func begin_altar_collapse(slot: int, by_slot := 0) -> bool:
	if not is_authority():
		return false
	var started := false
	for altar in altars_of(slot):
		if not altar.is_standing():
			continue
		_collapsing[altar] = collapse_seconds()
		altar.start_collapse(collapse_seconds())
		started = true
		print("altar del slot %d se derrumba (por slot %d, %.1f s)" % [slot, by_slot, collapse_seconds()])
	if started:
		publish()
	return started


## Server: the side lost. Idempotent.
func defeat_side(slot: int) -> void:
	if not is_authority() or defeated_slots.has(slot):
		return
	defeated_slots.append(slot)
	print("bando %d derrotado" % slot)
	side_defeated.emit(slot)
	publish()


## Server: the match is over. `winner` 0 = nobody is left.
func end_match(winner: int) -> void:
	if not is_authority() or ended:
		return
	ended = true
	winner_slot = winner
	winner_slots.assign([winner] if winner > 0 else [])
	winner_team = SideRelations.team_of(winner) if winner > 0 else 0
	print("partida terminada, gana el slot %d" % winner)
	result_changed.emit()
	publish()
	_tell_kit_ended()


## Server (or solo): the match is over and the team of `slots` (the living ones that were left, plus the allies that fell before) won.
## `winner_slot` is the lowest of them. With one slot it is the same as end_match(slot).
func end_match_team(slots: Array[int]) -> void:
	if not is_authority() or ended:
		return
	if slots.size() <= 1:
		end_match(slots[0] if slots.size() == 1 else 0)
		return
	var team: Array[int] = slots.duplicate()
	team.sort()
	ended = true
	winner_slots.assign(team)
	winner_slot = team[0]
	winner_team = SideRelations.team_of(team[0])
	print("partida terminada, gana el equipo %d: slots %s" % [winner_team, str(team)])
	result_changed.emit()
	publish()
	_tell_kit_ended()


## The result as the room and the kit read it: who won (the whole team) and who was defeated. Empty-ish while there is none.
func result() -> Dictionary:
	var winners: Array = []
	winners.assign(winner_slots)
	var defeated: Array = []
	defeated.assign(defeated_slots)
	return {"winner_slot": winner_slot, "winner_slots": winners, "defeated_slots": defeated, "reason": "result"}


## Says the match is over (MatchStateNet tells the kit when this is a dedicated started by hand).
func _tell_kit_ended() -> void:
	finished.emit()


## Advances the altar clocks by `delta` seconds (the server's physics step; a test may call it).
func tick(delta: float) -> void:
	if not is_authority() or _collapsing.is_empty():
		return
	var done: Array[Altar] = []
	for altar: Altar in _collapsing:
		_collapsing[altar] = float(_collapsing[altar]) - delta
		if float(_collapsing[altar]) <= 0.0:
			done.append(altar)
	for altar in done:
		_collapsing.erase(altar)
		if is_instance_valid(altar):
			altar.state = Altar.State.DESTROYED
			print("altar del slot %d destruido" % altar.owner_slot)
	if not done.is_empty():
		publish()


## Everything a peer needs to show the match as it is.
func to_snapshot() -> Dictionary:
	var entries: Array = []
	var seen: Dictionary = {}
	for altar in altars():
		var index := int(seen.get(altar.owner_slot, 0))
		seen[altar.owner_slot] = index + 1
		entries.append({
			"slot": altar.owner_slot,
			"index": index,
			"state": int(altar.state),
			"left": float(_collapsing.get(altar, 0.0)),
		})
	return {
		"altars": entries, "defeated": defeated_slots.duplicate(), "winner": winner_slot, "ended": ended,
		"winners": winner_slots.duplicate(), "winner_team": winner_team, "seated": seated_slots.duplicate(),
		"friendly_fire": friendly_fire, "ally_damage_factor": ally_damage_factor,
		"drop_soul": drop_soul, "starting_souls": starting_souls,
	}


func apply_snapshot(data: Dictionary) -> void:
	if data.has("friendly_fire"):
		var fire := bool(data["friendly_fire"])
		var factor := float(data.get("ally_damage_factor", ally_damage_factor))
		var drop := bool(data.get("drop_soul", drop_soul))
		var souls := int(data.get("starting_souls", starting_souls))
		if not _rules_known or fire != friendly_fire or factor != ally_damage_factor or drop != drop_soul \
				or souls != starting_souls:
			friendly_fire = fire
			ally_damage_factor = factor
			drop_soul = drop
			starting_souls = souls
			_rules_known = true
			_print_rules()
			rules_changed.emit()
	for entry: Dictionary in data.get("altars", []):
		var altar := _altar_at(int(entry.get("slot", 0)), int(entry.get("index", 0)))
		if altar == null:
			continue
		var next := int(entry.get("state", Altar.State.STANDING)) as Altar.State
		if next == altar.state:
			continue
		if next == Altar.State.COLLAPSING:
			var total := collapse_seconds()
			altar.start_collapse(total, clampf(total - float(entry.get("left", 0.0)), 0.0, total))
		else:
			altar.state = next
	for slot in data.get("defeated", []):
		if not defeated_slots.has(int(slot)):
			defeated_slots.append(int(slot))
			side_defeated.emit(int(slot))
	for slot in data.get("seated", []):
		if not seated_slots.has(int(slot)):
			seated_slots.append(int(slot))
	seated_slots.sort()
	var now_ended := bool(data.get("ended", false))
	var now_winner := int(data.get("winner", 0))
	var now_winners: Array[int] = []
	for slot in data.get("winners", [now_winner] if now_winner > 0 else []):
		now_winners.append(int(slot))
	if now_ended != ended or now_winner != winner_slot or now_winners != winner_slots:
		ended = now_ended
		winner_slot = now_winner
		winner_slots.assign(now_winners)
		winner_team = int(data.get("winner_team", 0))
		result_changed.emit()


## Server: asks the carrier to tell every client the match as it is now.
func publish() -> void:
	snapshot_changed.emit()


func _physics_process(delta: float) -> void:
	## No match runs in the editor.
	if Engine.is_editor_hint():
		return
	tick(delta)


func _altar_at(slot: int, index: int) -> Altar:
	var seen := 0
	for altar in altars():
		if altar.owner_slot != slot:
			continue
		if seen == index:
			return altar
		seen += 1
	return null


func _before(a: Altar, b: Altar) -> bool:
	if a.owner_slot != b.owner_slot:
		return a.owner_slot < b.owner_slot
	return str(world.get_path_to(a)) < str(world.get_path_to(b))


func _on_altar_state_changed(state: Altar.State, altar: Altar) -> void:
	altar_state_changed.emit(altar, state)
