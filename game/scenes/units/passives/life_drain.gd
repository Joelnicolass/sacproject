class_name LifeDrain
extends RefCounted

## Life drain, called with the damage the
## target really took: a live creature heals `taken · its CRE8 drain` at once, capped at its maximum.
## The one owner of the rule: the melee blow, the direct shot, the DirectImpact, the splash per body (SplashDamage.hurt) and
## the poison (PoisonImpact's burst, each tick of a Poisoned dose) only call feed() with what Health reported; none of
## them knows the drain. A building never feeds it (the target must be a unit or a wizard) ...
## ... unless its guardians stood in for it: the hit goes to each guardian and the attacker drains from
## what the guardians took, not from the building (Health.deflected_last tells the two apart).
## And the fire (Burning, a DamageOverTime with the attacker's path), each update, with what it took.


## The groups a body must be in (one of them) to feed a drain: a mobile body, never a structure.
const FEEDING_GROUPS: Array[StringName] = [UnitBody.GROUP, WizardBody.GROUP]


## `attacker`: the body that dealt the blow or the shot (null or freed: nothing). `target`: the body that was hit.
## `taken`: the damage its Health took. Server (or solo) only: Health.heal has the authority check. Returns the health gained.
static func feed(attacker: Node, target: Node, taken: float) -> float:
	if taken <= 0.0 or attacker == null or target == null or attacker == target:
		return 0.0
	if not is_instance_valid(attacker) or not is_instance_valid(target) or not attacker is UnitBody:
		return 0.0
	var creature := (attacker as UnitBody).type
	var health := attacker.get_node_or_null("Health") as Health
	if creature == null or creature.drain <= 0.0 or health == null or health.is_dead() or not _feeds(target):
		return 0.0
	var before := health.current
	health.heal(taken * creature.drain)
	var gained := health.current - before
	if DebugLog.on(&"drain") and gained > 0.0:
		print("drain %s from %s %.4f (scale %.3f) -> health %.4f gained %.4f (tick %d)" % [attacker.name, target.name, taken, creature.drain, health.current, gained, MatchClock.now()])
	return gained


static func _feeds(target: Node) -> bool:
	if target.is_in_group(MapBuilding.STRUCTURE_GROUP):
		var health := target.get_node_or_null("Health") as Health
		return health != null and health.deflected_last
	for group in FEEDING_GROUPS:
		if target.is_in_group(group):
			return true
	return false
