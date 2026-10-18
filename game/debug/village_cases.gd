extends RefCounted

## RFC-024 addendum 1 (024b2) cases of rules_suite: the sides of the SIDS, who may attack whom, a house with
## its health and its shelter, the peasant's choice (cower, stand, flee), the grudge of the herd and the avoidance agent of
## a body (its box and its priority). `run(host)` puts its bodies under `host` and removes them at the end.
## The bodies do not simulate (physics off); the cases call the same functions the physics tick does.

const UNIT_SCENE := preload("res://scenes/world/units/unit.tscn")
const WIZARD_SCENE := preload("res://scenes/world/wizard/wizard_body.tscn")
const PEASANT_SCENE := preload("res://scenes/world/units/peasant.tscn")
const BUILDING_SCENE := preload("res://scenes/world/map/map_building.tscn")
const RULES := preload("res://data/match_rules.tres")
const GROUP := "village_cases"

var _root: Node3D


func run(host: Node3D) -> Dictionary:
	_root = Node3D.new()
	_root.name = "VillageCases"
	host.add_child(_root)
	var out := {}
	out["village_sides"] = _sides()
	out["village_sides_fallback"] = _fallback()
	out["village_foe_rules"] = _foe_rules()
	out["village_building"] = _building()
	out["village_cower_flee"] = _cower_flee()
	out["village_grudge_herd"] = _grudge()
	out["village_separation_grid"] = _separation()
	_root.free()
	return out


static func _verdict(checks: Dictionary, details: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		if not bool(checks[key]):
			ok = false
	var out := details.duplicate()
	out["ok"] = ok
	out["checks"] = checks
	return out


## The SIDS of High Noon: players 1 and 2, Farmers 3, Taurocks 4, the houses' side 0 (neutral).
func _sides() -> Dictionary:
	SideRelations.refresh()
	var checks := {
		"p1_p2": SideRelations.is_enemy(1, 2) and SideRelations.is_enemy(2, 1),
		"players_vs_farmers": SideRelations.is_enemy(1, 3) and SideRelations.is_enemy(2, 3) and SideRelations.is_enemy(3, 1),
		"players_vs_taurocks": SideRelations.is_enemy(1, 4) and SideRelations.is_enemy(4, 2),
		"farmers_vs_taurocks": SideRelations.is_enemy(3, 4) and SideRelations.is_enemy(4, 3),
		"own_side": not SideRelations.is_enemy(3, 3) and SideRelations.stance(1, 1) == SideRelations.Stance.ALLY,
		"houses_neutral": not SideRelations.is_enemy(1, 0) and not SideRelations.is_enemy(0, 1) and not SideRelations.is_enemy(3, 0),
		"npc_slots": SideRelations.is_npc_slot(3) and SideRelations.is_npc_slot(4) and not SideRelations.is_npc_slot(1) \
			and not SideRelations.is_npc_slot(2) and not SideRelations.is_npc_slot(0),
		"no_player_color": SideColors.side_color(3) == SideColors.NPC_COLOR and SideColors.side_color(1) != SideColors.NPC_COLOR,
	}
	return _verdict(checks, {})


## Without the map's rows «another slot is an enemy» (what the port did before), even for slot 0.
func _fallback() -> Dictionary:
	SideRelations.set_rows([])
	var checks := {
		"other_is_enemy": SideRelations.is_enemy(1, 3) and SideRelations.is_enemy(1, 0),
		"same_is_not": not SideRelations.is_enemy(2, 2),
		"no_npc": not SideRelations.is_npc_slot(3),
	}
	SideRelations.refresh()
	checks["restored"] = SideRelations.is_enemy(1, 3) and not SideRelations.is_enemy(1, 0)
	return _verdict(checks, {})


func _foe_rules() -> Dictionary:
	var trogg := _unit(UNIT_SCENE, 1, Vector3.ZERO, "ycro")
	var farmer := _unit(PEASANT_SCENE, 3, Vector3(10.0, 0.0, 0.0), "zepe")
	var house := _house("jhut", Vector3(0.0, 0.0, 30.0))
	var checks := {
		"farmer_is_foe": UnitBody.is_valid_foe_of(1, farmer, trogg),
		"house_not_by_stance": not UnitBody.is_valid_foe_of(1, house, trogg),
		"house_by_order": UnitBody.is_valid_foe_of(1, house, trogg, false),
		"not_own_side": not UnitBody.is_valid_foe_of(3, farmer, farmer),
		"picks_farmer": trogg.closest_foe(Vector3.ZERO) == farmer or trogg.closest_foe(Vector3.ZERO) == null,
		"farmer_picks_none": farmer.closest_foe(farmer.global_position) == null,
	}
	trogg.free()
	farmer.free()
	house.free()
	return _verdict(checks, {})


## A jhut: 5000 health and a shelter in its BLDG; it goes away with no souls; a bld1 has no health at all.
func _building() -> Dictionary:
	var hut := _house("jhut", Vector3.ZERO)
	var wall := _house("bld1", Vector3(40.0, 0.0, 0.0))
	var health := hut.get_node("Health") as Health
	var destroyed := [0]
	hut.destroyed.connect(func(_building: MapBuilding) -> void: destroyed[0] += 1)
	var souls_before := _root.get_tree().get_nodes_in_group("soul").size()
	var checks := {
		"hut_health": health.maximum == 5000.0 and health.current == 5000.0,
		"hut_shelter": hut.is_sheltering() and hut.is_in_group(MapBuilding.SHELTER_GROUP),
		"hut_neutral": hut.owner_slot == 0 and hut.is_in_group("structure"),
		"wall_indestructible": wall.is_indestructible() and not wall.is_in_group(MapBuilding.SHELTER_GROUP),
	}
	health.damage(5000.0, 1)
	checks["hut_destroyed"] = hut.is_destroyed() and destroyed[0] == 1 and not hut.is_sheltering() and not hut.is_in_group(MapBuilding.SHELTER_GROUP)
	checks["no_souls"] = _root.get_tree().get_nodes_in_group("soul").size() == souls_before
	var wall_health := wall.get_node("Health") as Health
	wall_health.damage_typed(100000.0, Health.MELEE, 1)
	checks["wall_unscratched"] = not wall.is_destroyed()
	hut.free()
	wall.free()
	return _verdict(checks, {})


## No shelter within 50 m: it crouches. A shelter within 50 m: it stands up and, with a foe within 50 m, runs
## away from it; the foe at 51 m does not scare it; a foe of a grudge side does, even a friend of the stance.
func _cower_flee() -> Dictionary:
	var farmer := _unit(PEASANT_SCENE, 3, Vector3.ZERO, "zepe")
	var behavior := farmer.get_node("PeasantBehavior") as PeasantBehavior
	var checks := {}
	behavior.think()
	checks["cowers_alone"] = farmer.is_cowering() and behavior.state == &"cower"
	var hut := _house("jhut", Vector3(0.0, 0.0, 49.0))
	behavior.think()
	checks["stands_with_shelter"] = not farmer.is_cowering() and behavior.state == &"stand"
	var far_hut_ok := not (behavior.closest_shelter() == null)
	hut.position = Vector3(0.0, 0.0, 51.0)
	checks["shelter_at_51_is_none"] = behavior.closest_shelter() == null and far_hut_ok
	hut.position = Vector3(0.0, 0.0, 30.0)
	var hunter := _unit(UNIT_SCENE, 1, Vector3(-30.0, 0.0, 0.0), "nmuh")
	behavior.think()
	var goal: Vector3 = farmer.get("_goal")
	checks["flees_from_30"] = behavior.state == &"flee" and farmer.mode == UnitBody.Mode.MOVE and goal.x > 20.0 and absf(goal.z) < 1.0
	hunter.position = Vector3(-51.0, 0.0, 0.0)
	farmer.halt()
	behavior.think()
	checks["no_flee_from_51"] = behavior.state == &"stand" and farmer.mode == UnitBody.Mode.IDLE
	var altar_like := _house("jwg1", Vector3(500.0, 0.0, 0.0))
	checks["far_shelter_ignored"] = behavior.closest_shelter() == hut
	altar_like.free()
	hunter.free()
	hut.free()
	farmer.free()
	return _verdict(checks, {})


## The first hit on a full bar notes the attacker's side; the herd within 80 m shares it, the others do not;
## a second hit from another side with the bar already down notes nothing.
func _grudge() -> Dictionary:
	var hit := _unit(PEASANT_SCENE, 3, Vector3.ZERO, "zepe")
	var near := _unit(PEASANT_SCENE, 3, Vector3(60.0, 0.0, 0.0), "zepe")
	var far := _unit(PEASANT_SCENE, 3, Vector3(200.0, 0.0, 0.0), "zepe")
	var other_side := _unit(PEASANT_SCENE, 4, Vector3(10.0, 0.0, 0.0), "zepe")
	var grudge := hit.get_node("GrudgeMemory") as GrudgeMemory
	var near_grudge := near.get_node("GrudgeMemory") as GrudgeMemory
	var far_grudge := far.get_node("GrudgeMemory") as GrudgeMemory
	var other_grudge := other_side.get_node("GrudgeMemory") as GrudgeMemory
	var checks := {}
	(hit.get_node("Health") as Health).damage(50.0, 1)
	checks["hit_notes_slot1"] = grudge.has_grudge(1) and not grudge.has_grudge(2)
	(hit.get_node("Health") as Health).damage(50.0, 2)
	checks["second_hit_no_grudge"] = not grudge.has_grudge(2)
	near_grudge.absorb_herd()
	far_grudge.absorb_herd()
	other_grudge.absorb_herd()
	checks["near_shares"] = near_grudge.has_grudge(1)
	checks["far_does_not"] = not far_grudge.has_grudge(1)
	checks["other_side_does_not"] = not other_grudge.has_grudge(1)
	hit.free()
	near.free()
	far.free()
	other_side.free()
	return _verdict(checks, {})


## The avoidance agent of a body is its box: a ycro and an nmuh (different radii) each give the agent their BodyBox half
## size and height, a body that walks gets the moving priority, one that stands the idle priority and a fixed one the top,
## and a wizard is above a creature.
func _separation() -> Dictionary:
	var small := _unit(UNIT_SCENE, 1, Vector3(0.0, 0.0, 0.0), "ycro")
	var big := _unit(UNIT_SCENE, 1, Vector3(10.0, 0.0, 0.0), "nmuh")
	var checks := {}
	var radii := []
	for body in [small, big]:
		var agent := body.get_node("Avoidance") as BodyAvoidance
		checks["steers_%s" % body.creature_tag] = agent.steer(Vector3(1.0, 0.0, 0.0))
		checks["radius_%s" % body.creature_tag] = is_equal_approx(agent.radius, BodyBox.half_size(body)) \
				and is_equal_approx(agent.height, BodyBox.body_height(body))
		checks["moving_%s" % body.creature_tag] = is_equal_approx(agent.avoidance_priority, agent.moving_priority) \
				and is_equal_approx(agent.max_speed, 1.0)
		radii.append(agent.radius)
	checks["radii_differ"] = not is_equal_approx(float(radii[0]), float(radii[1]))
	var agent_small := small.get_node("Avoidance") as BodyAvoidance
	agent_small.steer(Vector3.ZERO)
	checks["idle_yields"] = is_equal_approx(agent_small.avoidance_priority, agent_small.idle_priority) \
			and is_equal_approx(agent_small.max_speed, agent_small.yield_speed) and agent_small.idle_priority < agent_small.moving_priority
	agent_small.steer(Vector3(1.0, 0.0, 0.0), true)
	checks["fixed_on_top"] = is_equal_approx(agent_small.avoidance_priority, 1.0)
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = 1
	wizard.position = Vector3(20.0, 0.0, 0.0)
	wizard.set_physics_process(false)
	_root.add_child(wizard)
	var wizard_agent := wizard.get_node("Avoidance") as BodyAvoidance
	checks["wizard_above_creature"] = wizard_agent.moving_priority > agent_small.moving_priority \
			and wizard_agent.idle_priority > agent_small.idle_priority
	wizard.free()
	small.free()
	big.free()
	return _verdict(checks, {"radii": radii})


func _unit(scene: PackedScene, slot: int, at: Vector3, tag: String) -> UnitBody:
	var unit: UnitBody = scene.instantiate()
	unit.name = "%s_%d_%d" % [tag, slot, _root.get_child_count()]
	unit.creature_tag = tag
	unit.owner_slot = slot
	unit.rules = RULES
	unit.idle_aggro = false
	unit.position = at
	unit.target_groups = PackedStringArray([GROUP])
	_root.add_child(unit)
	unit.add_to_group(GROUP)
	unit.set_physics_process(false)
	for child in unit.get_children():
		if child is PeasantBehavior or child is GrudgeMemory:
			child.set_physics_process(false)
	return unit


func _house(tag: String, at: Vector3) -> MapBuilding:
	var building: MapBuilding = BUILDING_SCENE.instantiate()
	building.name = "House_%s_%d" % [tag, _root.get_child_count()]
	building.tag = tag
	building.position = at
	_root.add_child(building)
	return building
