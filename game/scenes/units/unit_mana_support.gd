class_name UnitManaSupport
extends Node3D

## Server-authoritative mana support aura for units like Manahoar (hmba).
## Mirrors sacengine addManahoar shape (state.d): aura radius 40 and rate derived from
## allied manalith distance (50..1000) with a triangular ramp peaking at 20 mana/s.
## The aura radius and the ramp distances come from ReachFacts.of_rules(rules), read at every use (rules may be set without setup()).
## Ref: res://scenes/match/reach_facts.gd (manahoar_aura_m, manahoar_peak_m, manahoar_end_m).

@export var rules: MatchRules
@export var owner_slot := 0
@export var enabled := false
## The ability that makes a creature a mana source (data/catalog/abilities/hmba.tres, the Manahoar's).
@export var source: AbilityType
@export var target_groups: PackedStringArray = PackedStringArray(["wizard", "unit"])

var _body: UnitBody


func setup(body: UnitBody, creature: CreatureType, slot: int, match_rules: MatchRules) -> void:
	_body = body
	owner_slot = slot
	rules = match_rules
	enabled = creature != null and creature.has_passive(source)


func _ready() -> void:
	if not is_multiplayer_authority():
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not enabled or _body == null:
		return
	if _body.is_dead():
		return
	if _body.is_summoning():
		return
	var rate := _rate_from_manaliths()
	if rate <= 0.0:
		return
	var radius := ReachFacts.of_rules(rules).manahoar_aura_m
	for group in target_groups:
		for node in get_tree().get_nodes_in_group(group):
			var target := node as Node3D
			if target == null:
				continue
			if int(target.get("owner_slot")) != owner_slot:
				continue
			if target.global_position.distance_to(global_position) > radius:
				continue
			if target.has_method("can_take_mana") and not target.call("can_take_mana"):  # dynamic: a unit or a wizard
				continue
			var pool := target.get_node_or_null("ManaPool") as ManaPool
			if pool:
				pool.add(rate * delta, &"manahoar")


## Particles per second of the Manahoar's flame: sacengine draws one flame particle per mana point per second it gives
## (state.d animateManahoar takes the rate addManahoar returns), so it is 0 when no allied manalith is around. Every peer
## can ask (it only reads the structures); a body that gives no mana (dead, or not a Manahoar) answers 0.
func flame_rate() -> float:
	if not enabled or _body == null or _body.is_dead():
		return 0.0
	return _rate_from_manaliths()


func _rate_from_manaliths() -> float:
	var peak := rules.manahoar_rate if rules else 20.0
	var facts := ReachFacts.of_rules(rules)
	var near := facts.manahoar_peak_m
	var far := facts.manahoar_end_m
	if peak <= 0.0 or near <= 0.0 or far <= near:
		return 0.0
	var total := 0.0
	for node in get_tree().get_nodes_in_group(CastTower.TOWER_GROUP):
		var manalith := node as CastTower
		## Only Manaliths feed a Manahoar, the allies' too; a Shrine does not.
		if manalith == null or manalith.type.role != BuildingType.Role.MANALITH:
			continue
		if manalith.owner_slot != owner_slot and SideRelations.stance(owner_slot, manalith.owner_slot) != SideRelations.Stance.ALLY:
			continue
		var distance := global_position.distance_to(manalith.global_position)
		if distance >= far:
			continue
		if distance <= near:
			total += peak * (distance / near)
		else:
			total += peak * ((far - distance) / (far - near))
	return total
