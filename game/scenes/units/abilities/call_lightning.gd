class_name CallLightning
extends AbilityEffect

## The Storm Giant's Call lightning. It always applies
## (50 mana, no cooldown, no preparation): it throws a lightning with the spell `ntil` (750) from
## center + 100 · normalize(a uniform direction + (0, 0, 6)) (a point of the sky) to the Giant's own center. The bolt bounces on the
## first body it crosses, the Giant excepted (LightningStrike), so with nobody in the way it hurts the Giant: with friendly fire off
## that is 0 and no charge (it is faithful: the damage returns before the passive); on, ally_damage_factor of 750
## and the Lightning Charge takes it.
## The random direction is MatchSeed's stream ["call_lightning", user, tick]: three draws of [-1, 1) read as (x, z, y up).
## Server (or solo) only: AbilitySlot does not call fire() on a client.

## The coordinator's scene (lightning_strike.tscn).
@export var bolt_scene: PackedScene
## The spell whose amount the bolt deals (data/catalog/spells/lightning.tres, lightning).
@export var spell: SpellType
## Meters from the Giant's center to the point of the sky.
@export var sky_distance := 100.0
## Added to the random direction before normalizing: 6 up (Godot's y).
@export var sky_lift := 6.0


func fire(_target_pos: Vector3, _target: Node3D) -> bool:
	if not is_multiplayer_authority() or user == null or not is_instance_valid(user):
		return false
	if spell == null:
		push_warning("CallLightning: the spell is missing (spell).")
		return false
	var center := BodyNudge.center(user)
	var rng := MatchSeed.rng(["call_lightning", AbilityEffect.who(user), MatchClock.now()])
	var sx := rng.randf_range(-1.0, 1.0)
	var sy := rng.randf_range(-1.0, 1.0)
	var sz := rng.randf_range(-1.0, 1.0)
	# The uniform direction is already normalized; the lift is added after, then normalized again.
	var direction := (Vector3(sx, sz, sy).normalized() + Vector3(0.0, sky_lift, 0.0)).normalized()
	var origin := center + sky_distance * direction
	if DebugLog.on(&"effects"):
		print("lightning gsba %s draw (%.4f, %.4f, %.4f) origin %s (tick %d)" % [
			AbilityEffect.who(user), sx, sy, sz, "(%.4f, %.4f, %.4f)" % [origin.x, origin.y, origin.z], MatchClock.now()])
	return LightningStrike.launch(bolt_scene, self, user, origin, user, center, float(spell.damage), ability.tag if ability else "gsba") != null
