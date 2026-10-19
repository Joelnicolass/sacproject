extends RefCounted

## RFC-049 049b/049c (F291, F292) cases of rules_suite: teams in SideRelations, the victory by team and the rules between allies.
## World-less: four sides written by hand (SideRelations.set_rows, no map), four altars and a MatchState with its DefeatRule. The game
## mode is chosen with GameModeCatalog.use (the same `.tres` of data/modes/). Everything is put back when each case ends.

const ALTAR_SCENE := preload("res://scenes/map/props/altar.tscn")
const MATCH_SCENE := preload("res://scenes/match/match_state.tscn")
const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const RULES := preload("res://data/match_rules.tres")
const SYSTEM_SCENE := preload("res://scenes/sacrifice/sacrifice_system.tscn")
const SOUL_SYSTEM_SCENE := preload("res://scenes/souls/soul_system.tscn")
const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const STRUCTURE_SCENE := preload("res://scenes/structures/structure.tscn")
const GOD := "james"

## 4 player sides (assignment 1-4, each an enemy of the rest) and one NPC side (assignment 0), enemy of all: as the (4) maps of the original.
const SEATS := 4

var _host: Node3D
var _root: Node3D


func run(host: Node3D) -> Dictionary:
	_host = host
	var out := {}
	out["team_stances"] = _stances()
	out["team_victory_2v2"] = _victory_2v2(host)
	out["team_victory_ffa4"] = _victory_ffa4(host)
	out["team_victory_1v1"] = _victory_1v1(host)
	out["team_snapshot"] = _snapshot(host)
	_restore()
	return out


## 2v2: seats 1,2 vs 3,4. 1v1: no overlay, the sides of the map decide as always.
func _stances() -> Dictionary:
	var checks := {}
	_use_mode(&"2v2")
	checks["has_teams"] = SideRelations.has_teams()
	checks["ally_12"] = SideRelations.stance(1, 2) == SideRelations.Stance.ALLY
	checks["ally_21"] = SideRelations.stance(2, 1) == SideRelations.Stance.ALLY
	checks["ally_34"] = SideRelations.stance(3, 4) == SideRelations.Stance.ALLY
	checks["enemy_13"] = SideRelations.stance(1, 3) == SideRelations.Stance.ENEMY
	checks["enemy_42"] = SideRelations.stance(4, 2) == SideRelations.Stance.ENEMY
	checks["self_ally"] = SideRelations.stance(1, 1) == SideRelations.Stance.ALLY
	checks["team_of_seats"] = SideRelations.team_of(1) == 0 and SideRelations.team_of(2) == 0 \
		and SideRelations.team_of(3) == 1 and SideRelations.team_of(4) == 1
	checks["npc_slot"] = SideRelations.is_npc_slot(5) and SideRelations.team_of(5) == -5
	checks["npc_enemy"] = SideRelations.stance(1, 5) == SideRelations.Stance.ENEMY
	_use_mode(&"1v1")
	checks["no_overlay_1v1"] = not SideRelations.has_teams()
	checks["sids_1v1"] = SideRelations.stance(1, 2) == SideRelations.Stance.ENEMY and SideRelations.team_of(1) == -1
	_use_mode(&"ffa4")
	checks["ffa4_overlay"] = SideRelations.has_teams() and SideRelations.stance(1, 2) == SideRelations.Stance.ENEMY \
		and SideRelations.team_of(3) == 2
	return _verdict(checks)


## Derrotar 1 no da resultado (el 2 sigue); derrotar 3 y 4 da winner_slots = [1, 2], también el 1 que cayó antes (P3).
func _victory_2v2(host: Node3D) -> Dictionary:
	_use_mode(&"2v2")
	var world := _world(host, [1, 2, 3, 4])
	var state: MatchState = world[0]
	var rule: DefeatRule = world[1]
	var checks := {}
	checks["sides"] = state.sides() == [1, 2, 3, 4]
	checks["initial"] = not state.has_result() and state.winner_slots.is_empty()
	rule.defeat(1)
	checks["one_down_no_result"] = not state.has_result()
	rule.defeat(3)
	checks["enemy_one_down_no_result"] = not state.has_result()
	rule.defeat(4)
	checks["result"] = state.has_result()
	checks["winner_slots"] = state.winner_slots == [1, 2]
	checks["winner_slot_lowest"] = state.winner_slot == 1
	checks["winner_team"] = state.winner_team == 0
	checks["fallen_ally_won"] = state.is_defeated(1) and state.won(1) and state.won(2)
	checks["enemies_lost"] = not state.won(3) and not state.won(4) and not state.won(0)
	_free(world)
	return _verdict(checks)


func _victory_ffa4(host: Node3D) -> Dictionary:
	_use_mode(&"ffa4")
	var world := _world(host, [1, 2, 3, 4])
	var state: MatchState = world[0]
	var rule: DefeatRule = world[1]
	var checks := {}
	rule.defeat(2)
	rule.defeat(1)
	checks["two_down_no_result"] = not state.has_result()
	rule.defeat(4)
	checks["last_standing"] = state.has_result() and state.winner_slots == [3] and state.winner_slot == 3
	checks["only_3_won"] = state.won(3) and not state.won(4) and not state.won(1)
	_free(world)
	return _verdict(checks)


## 1v1 with the altars of seats 3 and 4 in the map and nobody seated there: they do not count (P4), 2 down gives slot 1.
func _victory_1v1(host: Node3D) -> Dictionary:
	_use_mode(&"1v1")
	var world := _world(host, [1, 2])
	var state: MatchState = world[0]
	var rule: DefeatRule = world[1]
	var checks := {}
	checks["sides_seated_only"] = state.sides() == [1, 2]
	rule.defeat(2)
	checks["result"] = state.has_result() and state.winner_slot == 1 and state.winner_slots == [1]
	checks["won"] = state.won(1) and not state.won(2)
	_free(world)
	## A world where nobody was ever seated (a bench with no WizardSpawner) keeps every owner of an altar.
	var bare := _world(host, [])
	checks["bare_sides"] = (bare[0] as MatchState).sides() == [1, 2, 3, 4]
	_free(bare)
	return _verdict(checks)


## winners, winner_team and seated go through the snapshot, also over var_to_bytes (as MpKit sends it).
func _snapshot(host: Node3D) -> Dictionary:
	_use_mode(&"2v2")
	var server := _world(host, [1, 2, 3, 4])
	var client := _world(host, [], false)
	(server[1] as DefeatRule).defeat(3)
	(server[1] as DefeatRule).defeat(4)
	var wire: Variant = bytes_to_var(var_to_bytes((server[0] as MatchState).to_snapshot()))
	(client[0] as MatchState).apply_snapshot(wire as Dictionary)
	var checks := {}
	checks["ended"] = (client[0] as MatchState).ended
	checks["winners"] = (client[0] as MatchState).winner_slots == [1, 2]
	checks["won_on_client"] = (client[0] as MatchState).won(2) and not (client[0] as MatchState).won(3)
	checks["seated"] = (client[0] as MatchState).seated_slots == [1, 2, 3, 4]
	_free(server)
	_free(client)
	return _verdict(checks)


# --- Helpers ---

func _unit(at: Vector3, slot: int) -> UnitBody:
	var type := GameData.creature("nmuh")
	var unit := UNIT_SCENE.instantiate() as UnitBody
	unit.owner_slot = slot
	unit.creature_tag = "nmuh"
	unit.model = str(type.model) if type else ""
	unit.rules = RULES
	unit.idle_aggro = false
	unit.target_groups = PackedStringArray()
	unit.position = at
	_root.add_child(unit)
	return unit


func _wizard(at: Vector3, slot: int) -> WizardBody:
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = slot
	wizard.god = GOD
	_root.add_child(wizard)
	wizard.global_position = at
	return wizard


func _altar(slot: int, at: Vector3) -> Altar:
	var altar := ALTAR_SCENE.instantiate() as Altar
	altar.owner_slot = slot
	altar.position = at
	_root.add_child(altar)
	return altar


func _manalith(slot: int, at: Vector3) -> Node3D:
	var structure: Node3D = STRUCTURE_SCENE.instantiate()
	structure.position = at
	structure.set("owner_slot", slot)
	structure.set("spell_tag", "htlm")
	structure.set("model", "mana")
	structure.set("rules", RULES)
	_root.add_child(structure)
	return structure


func _soul_of(unit: Node) -> Soul:
	for node in _host.get_tree().get_nodes_in_group("soul"):
		var soul := node as Soul
		if soul != null and is_instance_valid(soul) and not soul.is_queued_for_deletion() and soul.corpse == unit:
			return soul
	return null


func _frames(count: int) -> void:
	for _i in count:
		await _host.get_tree().physics_frame


## Waits until `condition` holds or `limit` frames pass.
func _until(condition: Callable, limit: int) -> void:
	for _frame in limit:
		if condition.call():
			return
		await _host.get_tree().physics_frame


func _use_mode(tag: StringName) -> void:
	GameModeCatalog.use(tag)
	SideRelations.set_rows(_rows(), SEATS)


func _restore() -> void:
	GameModeCatalog.reset()
	SideRelations.refresh()


## Four player sides, each an enemy of the other three and of the NPC side 4; the NPC side is enemy of all.
func _rows() -> Array:
	var rows: Array = []
	for side in SEATS:
		var enemies := 0
		for other in SEATS + 1:
			if other != side:
				enemies |= 1 << other
		rows.append({"id": side, "allies": 1 << side, "enemies": enemies, "assignment": side + 1})
	rows.append({"id": SEATS, "allies": 1 << SEATS, "enemies": (1 << SEATS) - 1, "assignment": 0})
	return rows


## [MatchState, DefeatRule, root]: four altars (slots 1-4) and a Match; `seated` are the slots with a wizard.
func _world(host: Node3D, seated: Array, with_rule := true) -> Array:
	var root := Node3D.new()
	root.name = "TeamCase"
	host.add_child(root)
	for slot in range(1, SEATS + 1):
		var altar := ALTAR_SCENE.instantiate() as Altar
		altar.name = "Altar%d" % slot
		altar.owner_slot = slot
		altar.position = Vector3(slot * 500.0, 0.0, 0.0)
		root.add_child(altar)
	var state: MatchState
	if with_rule:
		state = MATCH_SCENE.instantiate() as MatchState
	else:
		state = MatchState.new()
	state.name = "Match"
	state.world = root
	state.rules = RULES
	root.add_child(state)
	for slot in seated:
		state.mark_seated(int(slot))
	var rule: DefeatRule = state.get_node_or_null("Defeat") as DefeatRule
	return [state, rule, root]


func _free(world: Array) -> void:
	(world[2] as Node).free()


func _verdict(checks: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		if checks[key] is bool and not checks[key]:
			ok = false
	checks["ok"] = ok
	return checks
