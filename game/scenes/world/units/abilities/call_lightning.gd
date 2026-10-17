class_name CallLightning
extends AbilityEffect

## F130 (RFC-030 030s-a): the Storm Giant's Call lightning (gsba). sacengine callLightning (state.d:13121-13129) always applies
## (50 mana, no cooldown, no preparation): it throws `lightning()` (10474-10491) with the SPEL `ntil` (750) from
## center + 100 · normalize(uniformDirection + (0, 0, 6)) (a point of the sky) to the Giant's own center. The bolt bounces on the
## first body it crosses, the Giant excepted (LightningStrike), so with nobody in the way it hurts the Giant: with friendly fire off
## that is 0 and no charge (it is faithful: dealDamage returns before the passive, state.d:8961); on, ally_damage_factor of 750
## and the Lightning Charge takes it.
## The random direction is MatchSeed's stream ["call_lightning", user, tick]: three draws of [-1, 1) in sacengine's axes
## (x, y, z up), which the port reads as (x, z, y up).
## Server (or solo) only: ActiveAbility does not call fire() on a client.

## The coordinator's scene (lightning_strike.tscn).
@export var bolt_scene: PackedScene
## The SPEL whose amount the bolt deals (SpellTag.lightning, `ntil`).
@export var spell_tag := "ntil"
## Meters from the Giant's center to the point of the sky.
@export var sky_distance := 100.0
## sacengine adds (0, 0, 6) to the random direction before normalizing: 6 up (the port's y).
@export var sky_lift := 6.0


func fire(_target_pos: Vector3, _target: Node3D) -> bool:
	if not _has_authority() or user == null or not is_instance_valid(user):
		return false
	var spell := GameData.spell(spell_tag)
	if spell == null:
		push_warning("CallLightning: no hay SPEL %s." % spell_tag)
		return false
	var center := BodyNudge.center(user)
	var rng := MatchSeed.rng(["call_lightning", AbilityEffect.who(user), MatchClock.now()])
	var sx := rng.randf_range(-1.0, 1.0)
	var sy := rng.randf_range(-1.0, 1.0)
	var sz := rng.randf_range(-1.0, 1.0)
	## uniformDirection() is already normalized (state.d:29106-29110); the lift is added after, then normalized again (13123).
	var direction := (Vector3(sx, sz, sy).normalized() + Vector3(0.0, sky_lift, 0.0)).normalized()
	var origin := center + sky_distance * direction
	if log_effects:
		print("rayo gsba %s sorteo (%.4f, %.4f, %.4f) origen %s (tick %d)" % [
			AbilityEffect.who(user), sx, sy, sz, "(%.4f, %.4f, %.4f)" % [origin.x, origin.y, origin.z], MatchClock.now()])
	return LightningStrike.launch(bolt_scene, self, user, origin, user, center, float(spell.damage), ability.tag if ability else "gsba") != null
