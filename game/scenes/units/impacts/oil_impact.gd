class_name OilImpact
extends ShotImpact

## Where the Pyrodactyl's Viscous oil bursts. No
## damage: it smears every body in the spell's effect_range (15 m) that is not
## already oiled and can be oiled, of ANY side (the shooter's own too). Each body keeps its own Oiled (the body's component), which owns
## the oil: this node only asks it to start. The shot itself bursts on any creature but its shooter or on the ground (ShotLook.hits_every_side).
## Look: the shot's impact_fx (oil_splash). Not here: the scar on the ground.

const _SPLASH := preload("res://scenes/spells/splash_damage.gd")

## The groups of bodies that can be oiled (creatures and wizards; a building cannot).
@export var groups: Array[StringName] = [&"wizard", &"unit"]


func _affect(shot: Node3D, target: Node3D, point: Vector3, ability: AbilityType) -> void:
	var from_slot := int(shot.get("from_slot"))
	var radius := ability.effect_range_m if ability != null else 0.0
	var ticks := int(ability.duration_s * MatchClock.TICKS_PER_SECOND) if ability != null else 0
	if DebugLog.on(&"oil"):
		print("oil ball %s touches %s at (%.3f, %.3f, %.3f) radius %.1f (tick %d)" % [
			shot.name, ("a " + GameBody.name_of(target)) if target != null and is_instance_valid(target) else "ground",
			point.x, point.y, point.z, radius, MatchClock.now()])
	for body in _SPLASH.bodies_within(get_tree(), point, radius, null, groups):
		var oiled := Oiled.of(body)
		if oiled == null or not oiled.start(ticks, from_slot, ability):
			if DebugLog.on(&"oil"):
				print("oil %s does not stick (tick %d)" % [GameBody.name_of(body), MatchClock.now()])
