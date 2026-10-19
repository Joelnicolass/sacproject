class_name OilImpact
extends ShotImpact

## F155 (RFC-030 030r-b): where the Pyrodactyl's Viscous oil (kcfa) bursts, sacengine oilExplosion (state.d:25588-25612). No
## damage: dealDamageAt(0, 0.0, effectRange) with a callback that smears every body in the SPEL's effect_range (15 m) that is not
## already oiled and canBeOiled, of ANY side (the shooter's own too). Each body keeps its own Oiled (the body's component), which owns
## the oil: this node only asks it to start. The shot itself bursts on any creature but its shooter or on the ground (ShotLook.hits_every_side).
## Look: the shot's impact_fx (oil_splash). Not here (declared): the scar on the ground (25604 TODO).

const _SPLASH := preload("res://scenes/spells/splash_damage.gd")

## The groups of bodies that can be oiled (canBeOiled: creatures and wizards; a building cannot).
@export var groups: Array[StringName] = [&"wizard", &"unit"]


func _affect(shot: Node3D, target: Node3D, point: Vector3, ability: AbilityType) -> void:
	var from_slot := int(shot.get("from_slot"))
	var radius := ability.effect_range if ability != null else 0.0
	var ticks := int(ability.duration * MatchClock.TICKS_PER_SECOND) if ability != null else 0
	if DebugLog.on(&"oil"):
		print("bola aceite %s toca %s en (%.3f, %.3f, %.3f) radio %.1f (tick %d)" % [
			shot.name, ("a " + who(target)) if target != null and is_instance_valid(target) else "suelo",
			point.x, point.y, point.z, radius, MatchClock.now()])
	for body in _SPLASH.bodies_within(get_tree(), point, radius, null, groups):
		var oiled := Oiled.of(body)
		if oiled == null or not oiled.start(ticks, from_slot, ability):
			if DebugLog.on(&"oil"):
				print("aceite %s no se unta (tick %d)" % [who(body), MatchClock.now()])
