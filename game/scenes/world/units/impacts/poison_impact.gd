class_name PoisonImpact
extends ShotImpact

## F122 (RFC-030k-a): a poison shot (Necryl cena, Deadeye lfda, Hellmouth mhba). updateNecrylProjectile
## (state.d:23515-23527), the Deadeye's (24332-24372) and the Hellmouth's (24838-24900) do, where the shot bursts:
##   a creature or a wizard: healFromDrain(shooter, amount) (the shooter heals amount · its CRE8 drain, 8834-8840) and then
##     poison(target, ability, infectious, DamageMod.ranged): amount / duration / poisonNerfFactor per second for
##     duration·60 frames with the SPEL's `ires` / `freg` (11610-11614). No direct damage.
##   a building: the amount as direct ranged damage (dealRangedDamage).
##   the ground, or the end of the range: nothing.
## The dose goes through the target's Poisoning. Not here: the guardian's ×1.5 of dealPoisonDamage and `iacc` (declared).

const _HEALTH := preload("res://scenes/world/components/health.gd")

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
		var health := target.get_node_or_null("Health")
		if health:
			health.call("damage_typed", float(shot.get("damage")), _HEALTH.DIRECT_RANGED, from_slot)
		return
	if ability == null or ability.duration <= 0.0:
		return
	_drain(shot, float(ability.damage))
	var per_second := float(ability.damage) / ability.duration / nerf_factor
	var frames := int(ability.duration * MatchClock.TICKS_PER_SECOND)
	var ires := ability.arg_int("ires", 0)
	var freg := ability.arg_float("freg", 1.0)
	if Poisoning.dose_body(target, per_second, frames, kind, from_slot, infectious, ires, freg):
		print("veneno %s a %s: %.3f/s, %d cuadros%s (vida %d)" % [ability.tag, target.name, per_second, frames,
				", contagia" if infectious else "", roundi(float(target.get_node("Health").get("current")))])


func _is_building(target: Node) -> bool:
	for group in building_groups:
		if target.is_in_group(group):
			return true
	return false


## sacengine healFromDrain (state.d:8834-8840): a live shooter heals amount · drain (its CRE8 `drain`; a wizard has none).
func _drain(shot: Node3D, amount: float) -> void:
	var path: Variant = shot.get("shooter_path")
	if not path is NodePath or (path as NodePath).is_empty():
		return
	var shooter := shot.get_node_or_null(path as NodePath)
	if not shooter is UnitBody:
		return
	var type := (shooter as UnitBody).type
	var health := shooter.get_node_or_null("Health") as Health
	if type == null or health == null or health.is_dead() or type.drain <= 0.0 or amount == 0.0:
		return
	var before := health.current
	health.heal(amount * type.drain)
	print("drenaje %s +%.1f (vida %d -> %d)" % [shooter.name, health.current - before, roundi(before), roundi(health.current)])
