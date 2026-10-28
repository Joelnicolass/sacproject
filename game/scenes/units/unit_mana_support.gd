class_name UnitManaSupport
extends UnitPassive

## The Manahoar's mana aura: the body gives mana to its own side's wizards and creatures within the aura, at a rate that grows with
## the allied Manaliths around it (a triangular ramp peaking at `MatchRules.manahoar_rate`). The aura radius and the ramp distances
## come from ReachFacts.of_rules(body.rules), read at every use. A node of `manahoar_passives.tscn`; attach() hands it to the
## creature's CreatureFx (its flame follows the rate). Server (or solo) only for the giving.

@export var target_groups: PackedStringArray = PackedStringArray(["wizard", "unit"])


func attach(mount: PassiveMount) -> void:
	super(mount)
	if mount.creature_fx != null:
		mount.creature_fx.mana_support = self


func _ready() -> void:
	if not is_multiplayer_authority():
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if body == null or body.is_dead() or body.is_summoning():
		return
	var rate := _rate_from_manaliths()
	if rate <= 0.0:
		return
	var radius := ReachFacts.of_rules(body.rules).manahoar_aura_m
	var at := body.global_position
	for group in target_groups:
		for node in get_tree().get_nodes_in_group(group):
			var target := node as Node3D
			if target == null:
				continue
			if int(target.get("owner_slot")) != body.owner_slot:
				continue
			if target.global_position.distance_to(at) > radius:
				continue
			if target is GameBody and not (target as GameBody).can_take_mana():
				continue
			var pool := target.get_node_or_null("ManaPool") as ManaPool
			if pool:
				pool.add(rate * delta)


## Particles per second of the Manahoar's flame: the original draws one flame particle per mana point per second it gives
## (animateManahoar takes the rate addManahoar returns), so it is 0 when no allied manalith is around. Every peer
## can ask (it only reads the structures); a body that gives no mana (dead, or not a Manahoar) answers 0.
## Ref: sacengine animateManahoar, addManahoar (state.d).
func flame_rate() -> float:
	if body == null or body.is_dead():
		return 0.0
	return _rate_from_manaliths()


func _rate_from_manaliths() -> float:
	var rules := body.rules
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
		if manalith.owner_slot != body.owner_slot and SideRelations.stance(body.owner_slot, manalith.owner_slot) != SideRelations.Stance.ALLY:
			continue
		var distance := body.global_position.distance_to(manalith.global_position)
		if distance >= far:
			continue
		if distance <= near:
			total += peak * (distance / near)
		else:
			total += peak * ((far - distance) / (far - near))
	return total
