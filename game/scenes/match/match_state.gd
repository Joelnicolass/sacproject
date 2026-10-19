@tool
class_name MatchState
extends Node

## The state of the match: the state of every altar, the defeated sides and the winner. Single source
## for everyone (DefeatRule decides, the banner and the world read). The server (or solo) changes it
## and pushes it as a snapshot; a client applies it. A peer that enters later gets it when its world is
## ready (MpKit.client_world_ready), since the altars are fixed nodes of the map and do not go through
## a spawner.

## An altar changed state in this peer (the server's decision or an applied snapshot).
signal altar_state_changed(altar: Altar, state: Altar.State)
signal side_defeated(slot: int)
## The match has a result (a winner, or nobody left).
signal result_changed
## The rules of this match shown to the players changed: taken from the world (server, solo) or from a snapshot (client).
signal rules_changed

## Key of the dict in MpKit.push_snapshot (MpFlow ignores a snapshot with no world_id).
const SNAPSHOT_KEY := "match"
const FALLBACK_COLLAPSE_S := 11.0

@export var rules: MatchRules
## Node whose subtree holds the altars of this match (the world).
@export var world: Node

## 0 while the match has no winner.
var winner_slot := 0
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
	add_to_group(&"match_state")
	if is_authority():
		take_rules()
	for altar in altars():
		altar.state_changed.connect(_on_altar_state_changed.bind(altar))
	if not MpKit.is_networked():
		return
	if MpKit.is_server():
		MpKit.client_world_ready.connect(_on_client_world_ready)
	else:
		MpKit.snapshot_received.connect(_on_snapshot_received)
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
	return not MpKit.is_networked() or MpKit.is_server()


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


## The slots that own an altar (sacengine altarSides, state.d:30494-30500), in order.
func sides() -> Array[int]:
	var found: Array[int] = []
	for altar in altars():
		if altar.owner_slot > 0 and not found.has(altar.owner_slot):
			found.append(altar.owner_slot)
	found.sort()
	return found


func is_defeated(slot: int) -> bool:
	return defeated_slots.has(slot)


func has_result() -> bool:
	return ended


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
	print("partida terminada, gana el slot %d" % winner)
	result_changed.emit()
	publish()


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
	var now_ended := bool(data.get("ended", false))
	var now_winner := int(data.get("winner", 0))
	if now_ended != ended or now_winner != winner_slot:
		ended = now_ended
		winner_slot = now_winner
		result_changed.emit()


## Server: tells every client the match as it is now.
func publish() -> void:
	if MpKit.is_networked() and MpKit.is_server():
		MpKit.push_snapshot({SNAPSHOT_KEY: to_snapshot()})


func _physics_process(delta: float) -> void:
	## No match runs in the editor, and the MpKit autoload does not exist there.
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


func _on_client_world_ready(peer_id: int) -> void:
	MpKit.push_snapshot_to(peer_id, {SNAPSHOT_KEY: to_snapshot()})


func _on_snapshot_received(data: Dictionary) -> void:
	var mine: Variant = data.get(SNAPSHOT_KEY)
	if mine is Dictionary:
		apply_snapshot(mine)
