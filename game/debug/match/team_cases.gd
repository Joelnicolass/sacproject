extends RefCounted

## RFC-049 049b/049c (F291, F292) cases of rules_suite: teams in SideRelations, the victory by team and the rules between allies.
## World-less: four sides written by hand (SideRelations.set_rows, no map), four altars and a MatchState with its DefeatRule. The game
## mode is chosen with ActiveMatch.choose on a map with four starts (the same `.tres` of data/modes/). Everything is put back when each case ends.

const ALTAR_SCENE := preload("res://scenes/map/props/altar.tscn")
const MATCH_SCENE := preload("res://scenes/match/match_state.tscn")
const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const RULES := preload("res://data/match_rules.tres")
const SYSTEM_SCENE := preload("res://scenes/sacrifice/sacrifice_system.tscn")
const SOUL_SYSTEM_SCENE := preload("res://scenes/souls/soul_system.tscn")
const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const STRUCTURE_SCENE := preload("res://scenes/structures/buildings/james_manalith.tscn")
const GOD := "james"
const MANA_SUPPORT := preload("res://scenes/units/unit_mana_support.gd")

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
	## 049c: the rules between allies. A floor and the systems the cases need live in `_root`.
	_root = Node3D.new()
	_root.name = "TeamRules"
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(800.0, 2.0, 800.0)
	shape.shape = box
	shape.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(shape)
	_root.add_child(floor_body)
	host.add_child(_root)
	await _frames(2)
	out["team_friendly_fire"] = await _friendly_fire()
	out["team_souls"] = await _souls()
	out["team_sacrifice"] = await _sacrifice()
	out["team_manahoar"] = _manahoar()
	out["team_vision"] = _vision()
	_root.free()
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


## Friendly fire between allies (Health._side_factor asks the stance): off ×0, on ×0.5 between seats 1 and 2 of a 2v2, always ×1
## against seat 3; in 1v1 (no overlay) seat 2 is a foe, ×1.
func _friendly_fire() -> Dictionary:
	_use_mode(&"2v2")
	var checks := {}
	var state := MatchState.new()
	state.world = _root
	state.rules = RULES
	_root.add_child(state)
	state.friendly_fire = false
	var ally := _unit(Vector3(0.0, 0.1, 60.0), 1)
	var health := ally.get_node("Health") as Health
	health.setup(5000.0)
	checks["off_ally_splash"] = health.damage_typed(100.0, Health.SPLASH_SPELL, 2) == 0.0
	var before := health.current
	health.damage(100.0, 2)
	checks["off_ally_melee"] = health.current == before
	checks["off_own_side"] = health.damage_typed(100.0, Health.SPLASH_SPELL, 1) == 0.0
	checks["off_enemy_taken"] = health.damage_typed(100.0, Health.SPLASH_SPELL, 3) > 0.0
	state.friendly_fire = true
	state.ally_damage_factor = 0.5
	var enemy_hit := health.damage_typed(100.0, Health.SPLASH_SPELL, 3)
	var ally_hit := health.damage_typed(100.0, Health.SPLASH_SPELL, 2)
	checks["on_ally_half"] = enemy_hit > 0.0 and absf(ally_hit / enemy_hit - 0.5) <= 0.005
	before = health.current
	health.damage(100.0, 2)
	checks["on_ally_melee_half"] = absf((before - health.current) - 50.0) <= 0.01
	_use_mode(&"1v1")
	state.friendly_fire = false
	checks["1v1_seat2_is_a_foe"] = health.damage_typed(100.0, Health.SPLASH_SPELL, 2) > 0.0
	ally.free()
	state.free()
	return _verdict(checks)


## Free souls: own > ally > neutral > enemy among the wizards that can take it (CollectStance), and the closest breaks a tie
## inside a stance. A free soul of seat 2 goes to seat 1 (ally) rather than to the closer wizard of seat 3.
func _souls() -> Dictionary:
	_use_mode(&"2v2")
	var checks := {}
	var system := SOUL_SYSTEM_SCENE.instantiate() as SoulSystem
	_root.add_child(system)
	var own := system.spawn_soul({"x": 0.0, "y": 0.0, "z": 0.0, "number": 1, "owner_slot": 1, "dropped": true, "emerging": false})
	var ally := system.spawn_soul({"x": 0.0, "y": 0.0, "z": 0.0, "number": 1, "owner_slot": 2, "dropped": true, "emerging": false})
	var neutral := system.spawn_soul({"x": 0.0, "y": 0.0, "z": 0.0, "number": 1, "owner_slot": 0, "dropped": true, "emerging": false})
	var enemy := system.spawn_soul({"x": 0.0, "y": 0.0, "z": 0.0, "number": 1, "owner_slot": 3, "dropped": true, "emerging": false})
	checks["stance_own"] = system._stance(own, 1) == SoulSystem.Stance.OWN
	checks["stance_ally"] = system._stance(ally, 1) == SoulSystem.Stance.ALLY
	checks["stance_neutral"] = system._stance(neutral, 1) == SoulSystem.Stance.NEUTRAL
	checks["stance_enemy"] = system._stance(enemy, 1) == SoulSystem.Stance.ENEMY
	checks["priority_order"] = SoulSystem.Stance.OWN < SoulSystem.Stance.ALLY and SoulSystem.Stance.ALLY < SoulSystem.Stance.NEUTRAL \
		and SoulSystem.Stance.NEUTRAL < SoulSystem.Stance.ENEMY
	for soul in [own, ally, neutral, enemy]:
		soul.free()
	## Real competition: wizards of seat 3 (2 m away) and seat 1 (4 m away) for a free soul that seat 2 dropped.
	var near_foe := _wizard(Vector3(2.0, 0.0, 200.0), 3)
	var far_friend := _wizard(Vector3(-4.0, 0.0, 200.0), 1)
	await _frames(2)
	var soul := system.spawn_soul({"x": 0.0, "y": 0.0, "z": 200.0, "number": 1, "owner_slot": 2, "dropped": true, "emerging": false})
	await _frames(6)
	checks["ally_wizard_takes_it"] = soul.state != Soul.State.NORMAL and soul.collector_slot == 1
	## In 1v1 the same two wizards are both foes of seat 2: the closer one (seat 3) wins as before.
	_use_mode(&"1v1")
	if is_instance_valid(soul):
		soul.free()
	await _frames(2)
	var soul_b := system.spawn_soul({"x": 0.0, "y": 0.0, "z": 200.0, "number": 1, "owner_slot": 2, "dropped": true, "emerging": false})
	await _frames(6)
	checks["1v1_closest_takes_it"] = soul_b.state != Soul.State.NORMAL and soul_b.collector_slot == 3
	for node in [near_foe, far_friend, system]:
		if is_instance_valid(node):
			node.free()
	if is_instance_valid(soul_b):
		soul_b.free()
	return _verdict(checks)


## Desecrate needs an enemy altar (an allied one is not a target); Convert takes the corpse of an ally too, as the original
## does (its soul is red for the other seat, sacengine color() state.d:1622-1630, and nothing else excludes an ally: P10).
func _sacrifice() -> Dictionary:
	_use_mode(&"2v2")
	var checks := {}
	var system := SYSTEM_SCENE.instantiate() as SacrificeSystem
	system.rules = RULES
	_root.add_child(system)
	var souls := SOUL_SYSTEM_SCENE.instantiate()
	_root.add_child(souls)
	var from := Vector3(0.0, 0.0, -200.0)
	var ally_altar := _altar(2, from + Vector3(0.0, 0.0, 30.0))
	checks["ally_altar_not_a_target"] = system.closest_enemy_altar(1, from) == null
	checks["ally_altar_status"] = system.altar_status(1, from) == SacrificeSystem.NO_ALTAR
	var enemy_altar := _altar(3, from + Vector3(0.0, 0.0, 60.0))
	checks["enemy_altar_is_a_target"] = system.closest_enemy_altar(1, from) == enemy_altar
	checks["closest_skips_ally"] = system.closest_enemy_altar(1, from + Vector3(0.0, 0.0, 28.0)) == enemy_altar
	_use_mode(&"1v1")
	checks["1v1_altar_of_seat2_is_enemy"] = system.closest_enemy_altar(1, from) == ally_altar
	_use_mode(&"2v2")
	ally_altar.free()
	enemy_altar.free()
	var corpse_ally := _unit(Vector3(0.0, 0.1, 12.0), 2)
	var corpse_foe := _unit(Vector3(10.0, 0.1, 12.0), 3)
	var corpse_own := _unit(Vector3(-10.0, 0.1, 12.0), 1)
	await _frames(20)
	for body in [corpse_ally, corpse_foe, corpse_own]:
		body.get_node("Health").damage(99999.0, 4)
	await _frames(120)
	var soul_ally := _soul_of(corpse_ally)
	var soul_foe := _soul_of(corpse_foe)
	var soul_own := _soul_of(corpse_own)
	var found := soul_ally != null and soul_foe != null and soul_own != null
	checks["souls_on_corpses"] = found
	if found:
		await _until(func() -> bool: return soul_ally.state == Soul.State.NORMAL and soul_foe.state == Soul.State.NORMAL and soul_own.state == Soul.State.NORMAL, 400)
		checks["convert_enemy_corpse"] = system.convert_status(1, soul_foe) == ""
		checks["convert_ally_corpse"] = system.convert_status(1, soul_ally) == ""
		checks["convert_own_corpse_refused"] = system.convert_status(1, soul_own) == SacrificeSystem.BAD_TARGET
	for node in [corpse_ally, corpse_foe, corpse_own, souls, system]:
		if is_instance_valid(node):
			node.free()
	return _verdict(checks)


## The Manahoar adds the rate of the manaliths of its allies too (state.d:28598-28606), not those of a foe.
func _manahoar() -> Dictionary:
	_use_mode(&"2v2")
	var checks := {}
	var support: Node3D = MANA_SUPPORT.new()
	support.rules = RULES
	support.owner_slot = 1
	support.enabled = true
	support.position = Vector3(0.0, 0.0, 400.0)
	_root.add_child(support)
	checks["no_manalith_no_rate"] = support._rate_from_manaliths() == 0.0
	var foe := _manalith(3, Vector3(0.0, 0.0, 420.0))
	checks["foe_manalith_ignored"] = support._rate_from_manaliths() == 0.0
	var friend := _manalith(2, Vector3(0.0, 0.0, 420.0))
	var with_ally: float = support._rate_from_manaliths()
	checks["ally_manalith_counts"] = with_ally > 0.0
	var own := _manalith(1, Vector3(0.0, 0.0, 420.0))
	checks["own_adds_up"] = absf(support._rate_from_manaliths() - 2.0 * with_ally) <= 0.001
	_use_mode(&"1v1")
	checks["1v1_seat2_manalith_ignored"] = absf(support._rate_from_manaliths() - with_ally) <= 0.001
	for node in [foe, friend, own, support]:
		node.free()
	return _verdict(checks)


## What a side sees is marked for its allies too when the match allows it (MatchRules.allied_vision).
func _vision() -> Dictionary:
	_use_mode(&"2v2")
	var checks := {}
	var rules := RULES.duplicate() as MatchRules
	var seen := _unit(Vector3(0.0, 0.1, -300.0), 3)
	var watcher := _unit(Vector3(0.0, 0.1, -280.0), 1)
	var eyes := watcher.get("vision") as Vision
	eyes.watching = false
	eyes.rules = rules
	rules.allied_vision = true
	eyes.refresh()
	checks["seen_by_marker"] = VisionSides.sees(1, seen)
	checks["shared_with_ally"] = VisionSides.sees(2, seen)
	## Side 3 owns `seen`, so ask what it keeps in mind (known), not sees().
	checks["not_shared_with_foe"] = not VisionSides.known(3).has(seen.get_instance_id()) and not VisionSides.known(4).has(seen.get_instance_id())
	var other := _unit(Vector3(5.0, 0.1, -300.0), 3)
	rules.allied_vision = false
	eyes.refresh()
	checks["off_not_shared"] = VisionSides.sees(1, other) and not VisionSides.sees(2, other)
	_use_mode(&"1v1")
	rules.allied_vision = true
	var third := _unit(Vector3(10.0, 0.1, -300.0), 3)
	eyes.refresh()
	checks["1v1_not_shared"] = not VisionSides.sees(2, third)
	for node in [seen, other, third, watcher]:
		node.free()
	var verdict := _verdict(checks)
	if not bool(verdict["ok"]):
		print("team_vision checks: %s" % str(checks))
	return verdict


# --- Helpers ---

func _unit(at: Vector3, slot: int) -> UnitBody:
	var type := GameData.creature("nmuh")
	var unit := UNIT_SCENE.instantiate() as UnitBody
	unit.owner_slot = slot
	unit.type = GameData.creature("nmuh")
	unit.model = type.model_id() if type else ""
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
	ActiveMatch.choose(MapCatalog.shared().find(&"test_flat4"), GameModeCatalog.shared().find(tag))
	SideRelations.set_rows(_rows(), SEATS)


func _restore() -> void:
	ActiveMatch.forget()
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
