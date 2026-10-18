class_name BurnImpact
extends ShotImpact

## F123 (RFC-030l): a shot that sets bodies ablaze where it bursts (a Burning on each). The scene decides which fire:
##   heat_ray_impact.tscn (Tickferno sfba, updateTickfernoProjectile state.d:23797-23810): a creature or a wizard gets
##     setAblazeWithManaDrain(duration·60 frames, amount, 0.5 · its max mana); a building the same with no drain.
##   rocket_impact.tscn (Pyromaniac lffa, updatePyromaniacRocket 24314-24321): setAblaze(duration·60, ranged, amount,
##     peirceShield), with no direct damage.
##   bombard_impact.tscn (Bombard cfba, bombardProjectileExplosion 24518-24528): a fire of no damage for 60 frames on the
##     body it hit and, through the splash callback, on every body within damageRange (any side; only the look).
## Not here (declared): igniteBuilding (no building catches fire) and DamageMod.ignite (030r).
## F162b: a fire of no damage now reaches a building too (it ends on its first update, as updateFire does).

const _SPLASH := preload("res://scenes/world/spells/splash_damage.gd")

enum Amount { SHOT, NONE }
enum Lifetime { ABILITY_DURATION, FIXED }
enum RadiusSource { NONE, DAMAGE_RANGE, EFFECT_RANGE }

## What the fire deals over its life: the shot's amount (already scaled by the shooter) or nothing (a look).
@export var amount := Amount.SHOT
## How many frames it burns: the SPEL's duration · 60, or `fixed_ticks`.
@export var lifetime := Lifetime.ABILITY_DURATION
@export var fixed_ticks := 60
## The Health kind of its damage (setAblaze `ranged`: direct ranged; else direct spell).
@export var kind: StringName = &"direct_ranged"
## sacengine DamageMod.peirceShield: skips the body's shields and states (Health).
@export var pierce_shield := false
## Mana drained over its life, as a fraction of a creature's or a wizard's max mana (heat ray 0.5). A building: none.
@export_range(0.0, 1.0) var mana_drain_fraction := 0.0
## Also every body (creatures and wizards) within this SPEL range of the burst, but the one it hit (the splash callback).
@export var radius_source := RadiusSource.NONE
@export var splash_groups: Array[StringName] = [&"wizard", &"unit"]
@export_group("Look")
## FxBus type puffed on a burning creature (sacengine spawnFireParticles: 3 particles a frame).
@export var fire_fx := "fire"
@export var fire_every_ticks := 10
## Height over the body's origin the fire puffs from: low enough that the flames stay under the health bar.
@export var fire_height_m := 0.8


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


func _ignite(body: Node3D, damage: float, frames: int, from_slot: int, ability: AbilityType, shooter: Node) -> void:
	var mana := body.get_node_or_null("ManaPool") as ManaPool
	var drain := mana_drain_fraction * mana.maximum if mana and mana_drain_fraction > 0.0 else 0.0
	var fire := Burning.ignite(body, damage, frames, kind, from_slot, drain, pierce_shield, fire_fx, shooter)
	if fire == null:
		return
	fire.fire_every_ticks = fire_every_ticks
	fire.fire_height_m = fire_height_m
	var health := body.get_node("Health") as Health
	print("fuego %s a %s: %.1f en %d cuadros%s%s (vida %d%s)" % [ability.tag if ability else "?", who(body), damage, frames,
			", maná %.2f" % drain if drain > 0.0 else "", ", atraviesa escudos" if pierce_shield else "",
			roundi(health.current), ", maná %.2f" % mana.current if mana and drain > 0.0 else ""])


func _frames(ability: AbilityType) -> int:
	if lifetime == Lifetime.FIXED:
		return fixed_ticks
	return int(ability.duration * MatchClock.TICKS_PER_SECOND) if ability else 0


func _radius(ability: AbilityType) -> float:
	if ability == null:
		return 0.0
	match radius_source:
		RadiusSource.DAMAGE_RANGE:
			return ability.damage_range
		RadiusSource.EFFECT_RANGE:
			return ability.effect_range
	return 0.0
