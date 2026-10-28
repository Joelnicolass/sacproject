class_name PoisonImpact
extends ShotImpact

## A poison shot (Necryl, Deadeye, Hellmouth). Where the shot bursts:
##   a creature or a wizard: the shooter heals amount · its drain (LifeDrain) and then
##     the target is poisoned: amount / duration / poison nerf factor per second for
##     duration·60 frames with the spell's `ires` / `freg`. No direct damage.
##   a building: the amount as direct ranged damage.
##   the ground, or the end of the range: nothing.
## The dose goes through the target's Poisoning, which carries the shooter: each tick drains it too.
## Not here: the guardian's ×1.5 of the poison damage and `iacc`.

const _HEALTH := preload("res://scenes/components/health.gd")

## The factor that softens the poison.
@export var nerf_factor := 1.3
## The dose spreads to the bodies around the target (Poison.infectuous): only the Necryl's Disease (disease_impact.tscn).
@export var infectious := false
## The Health kind of the dose: DamageMod.ranged of a direct shot.
@export var kind: StringName = &"direct_ranged"
## A target in one of these groups takes the plain direct ranged hit.
@export var building_groups: Array[StringName] = [&"structure"]


func _affect(shot: Node3D, target: Node3D, _point: Vector3, ability: AbilityType) -> void:
	if target == null or not is_instance_valid(target):
		return
	var from_slot := int(shot.get("from_slot"))
	if _is_building(target):
		var health := target.get_node_or_null("Health") as Health
		if health:
			# A building with guardians sends the hit to them: the shooter drains from what they took.
			LifeDrain.feed(shooter_of(shot), target, health.damage_typed(float(shot.get("damage")), _HEALTH.DIRECT_RANGED, from_slot))
		return
	if ability == null or ability.duration_s <= 0.0:
		return
	var shooter := shooter_of(shot)
	# The shooter drains the whole SPEL amount, whatever the target takes; LifeDrain owns the rule.
	LifeDrain.feed(shooter, target, float(ability.damage))
	var per_second := float(ability.damage) / ability.duration_s / nerf_factor
	var frames := int(ability.duration_s * MatchClock.TICKS_PER_SECOND)
	var ires := ability.poison_resistance_debuff
	var freg := ability.poison_regen_factor
	if Poisoning.dose_body(target, per_second, frames, kind, from_slot, infectious, ires, freg, shooter.get_path() if shooter != null else NodePath()):
		print("poison %s on %s: %.3f/s, %d frames%s (health %d)" % [ability.tag, target.name, per_second, frames,
				", contagia" if infectious else "", roundi(float(target.get_node("Health").get("current")))])


func _is_building(target: Node) -> bool:
	for group in building_groups:
		if target.is_in_group(group):
			return true
	return false
