class_name PoisonImpact
extends ShotImpact

## F122 (RFC-030k-a): a poison shot (Necryl cena, Deadeye lfda, Hellmouth mhba). updateNecrylProjectile
## (state.d:23515-23527), the Deadeye's (24332-24372) and the Hellmouth's (24838-24900) do, where the shot bursts:
##   a creature or a wizard: healFromDrain(shooter, amount) (the shooter heals amount · its CRE8 drain, 8834-8840: LifeDrain, F164b) and then
##     poison(target, ability, infectious, DamageMod.ranged): amount / duration / poisonNerfFactor per second for
##     duration·60 frames with the SPEL's `ires` / `freg` (11610-11614). No direct damage.
##   a building: the amount as direct ranged damage (dealRangedDamage).
##   the ground, or the end of the range: nothing.
## The dose goes through the target's Poisoning, which carries the shooter: each tick drains it too (dealPoisonDamage -> dealDamage
## with the attacker, 23585, 9415-9419, 8933-8947). Not here: the guardian's ×1.5 of dealPoisonDamage and `iacc` (declared).

const _HEALTH := preload("res://scenes/components/health.gd")

## sacengine poisonNerfFactor (state.d:11610).
@export var nerf_factor := 1.3
## The dose spreads to the bodies around the target (Poison.infectuous): only the Necryl's Disease (disease_impact.tscn).
@export var infectious := false
## The Health kind of the dose: DamageMod.ranged of a direct shot.
@export var kind: StringName = &"direct_ranged"
## A target in one of these groups takes the plain direct ranged hit (sacengine TargetType.building).
@export var building_groups: Array[StringName] = [&"structure"]


func _affect(shot: Node3D, target: Node3D, _point: Vector3, ability: AbilityType) -> void:
	if target == null or not is_instance_valid(target):
		return
	var from_slot := int(shot.get("from_slot"))
	if _is_building(target):
		var health := target.get_node_or_null("Health") as Health
		if health:
			## A building with guardians sends the hit to them (dealRangedDamage, 9369): the shooter drains from what they took.
			LifeDrain.feed(shooter_of(shot), target, health.damage_typed(float(shot.get("damage")), _HEALTH.DIRECT_RANGED, from_slot))
		return
	if ability == null or ability.duration <= 0.0:
		return
	var shooter := shooter_of(shot)
	## healFromDrain(shooter, amount) (23523, 24360, 24879): the whole SPEL amount, whatever the target takes; LifeDrain owns the rule.
	LifeDrain.feed(shooter, target, float(ability.damage))
	var per_second := float(ability.damage) / ability.duration / nerf_factor
	var frames := int(ability.duration * MatchClock.TICKS_PER_SECOND)
	var ires := ability.arg_int("ires", 0)
	var freg := ability.arg_float("freg", 1.0)
	if Poisoning.dose_body(target, per_second, frames, kind, from_slot, infectious, ires, freg, shooter.get_path() if shooter != null else NodePath()):
		print("veneno %s a %s: %.3f/s, %d cuadros%s (vida %d)" % [ability.tag, target.name, per_second, frames,
				", contagia" if infectious else "", roundi(float(target.get_node("Health").get("current")))])


func _is_building(target: Node) -> bool:
	for group in building_groups:
		if target.is_in_group(group):
			return true
	return false
