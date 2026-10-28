class_name BurnImpact
extends ShotImpact

## A shot that sets bodies ablaze where it bursts (a Burning on each). The scene decides which fire:
##   heat_ray_impact.tscn (Tickferno): a creature or a wizard gets
##     a fire for duration·60 frames that drains 0.5 · its max mana; a building the same with no
##     drain.
##   rocket_impact.tscn (Pyromaniac): a fire for duration·60 frames that deals the shot's amount
##     and pierces shields, with no direct damage.
##   bombard_impact.tscn (Bombard): a fire of no damage for 60 frames on the
##     body it hit and, through the splash callback, on every body within the damage range (any
##     side; only the look).
## Not here: no building catches fire, and no DamageMod.ignite.
## A fire of no damage reaches a building too (it ends on its first update).

const _SPLASH := preload("res://scenes/spells/splash_damage.gd")

enum Amount { SHOT, NONE }
enum Lifetime { ABILITY_DURATION, FIXED }
enum RadiusSource { NONE, DAMAGE_RANGE, EFFECT_RANGE }

## What the fire deals over its life: the shot's amount (already scaled by the shooter) or nothing
## (a look).
@export var amount := Amount.SHOT
## How long it burns: the SPEL's duration, or `fixed_s`.
@export var lifetime := Lifetime.ABILITY_DURATION
@export_range(0.0, 60.0, 0.0001, "suffix:s") var fixed_s := 1.0
## The Health kind of its damage (`ranged`: direct ranged; else direct spell).
@export var kind: StringName = &"direct_ranged"
## Skips the body's shields and states (Health).
@export var pierce_shield := false
## Mana drained over its life, as a fraction of a creature's or a wizard's max mana (heat ray 0.5).
## A building: none.
@export_range(0.0, 1.0) var mana_drain_fraction := 0.0
## Also every body (creatures and wizards) within this SPEL range of the burst, but the one it hit
## (the splash callback).
@export var radius_source := RadiusSource.NONE
@export var splash_groups: Array[StringName] = [&"wizard", &"unit"]
@export_group("Look")
## The fire puffed on a burning creature (3 particles a frame). Empty = none.
@export var fire_fx: ParticleType = preload("res://data/fx/fire.tres")
@export_range(0.0, 2.0, 0.0001, "suffix:s") var fire_every_s := 0.1666
## The socket of the body the fire puffs from (inside its box, under the health bar).
@export var fire_socket: BodyFacts.Socket = BodyFacts.Socket.CENTER


func _affect(shot: Node3D, target: Node3D, point: Vector3, ability: AbilityType) -> void:
	var from_slot := int(shot.get("from_slot"))
	var damage := float(shot.get("damage")) if amount == Amount.SHOT else 0.0
	var frames := _frames(ability)
	if frames <= 0:
		return
	var direct := target if target and is_instance_valid(target) else null
	var shooter := shooter_of(shot)
	if direct:
		_ignite(direct, damage, frames, from_slot, ability, shooter)
	var radius := _radius(ability)
	if radius > 0.0:
		for body in _SPLASH.bodies_within(get_tree(), point, radius, direct, splash_groups):
			_ignite(body, damage, frames, from_slot, ability, shooter)


func _ignite(
	body: Node3D, damage: float, frames: int, from_slot: int, ability: AbilityType, shooter: Node
) -> void:
	var mana := body.get_node_or_null("ManaPool") as ManaPool
	var drain := mana_drain_fraction * mana.maximum if mana and mana_drain_fraction > 0.0 else 0.0
	var fire := Burning.ignite(
		body, damage, frames, kind, from_slot, drain, pierce_shield, fire_fx, shooter
	)
	if fire == null:
		return
	fire.fire_every_ticks = MatchClock.ticks_for(fire_every_s)
	fire.fire_socket = fire_socket
	var health := body.get_node("Health") as Health
	print(
		(
			"fire %s on %s: %.1f over %d frames%s%s (health %d%s)"
			% [
				ability.tag if ability else "?",
				GameBody.name_of(body),
				damage,
				frames,
				", mana %.2f" % drain if drain > 0.0 else "",
				", atraviesa escudos" if pierce_shield else "",
				roundi(health.current),
				", mana %.2f" % mana.current if mana and drain > 0.0 else ""
			]
		)
	)


func _frames(ability: AbilityType) -> int:
	if lifetime == Lifetime.FIXED:
		return MatchClock.ticks_for(fixed_s)
	return int(ability.duration_s * MatchClock.TICKS_PER_SECOND) if ability else 0


func _radius(ability: AbilityType) -> float:
	if ability == null:
		return 0.0
	match radius_source:
		RadiusSource.DAMAGE_RANGE:
			return ability.damage_range_m
		RadiusSource.EFFECT_RANGE:
			return ability.effect_range_m
	return 0.0
