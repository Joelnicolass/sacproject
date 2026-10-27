class_name ImplosionImpact
extends ShotImpact

## The Flurry's shot: after the damage (its SplashImpact
## sibling) an implosion of effectRange that shrinks over the spell's duration starts where the shot burst. It goes to
## the shot's parent, so it outlives the shot.
## Ref: F121 (RFC-030j); Flurry caba (flurryProjectileImplosion, state.d:24577-24598).

@export var implosion_scene: PackedScene


func _affect(shot: Node3D, _target: Node3D, point: Vector3, ability: AbilityType) -> void:
	if implosion_scene == null or shot.get_parent() == null:
		return
	var implosion := implosion_scene.instantiate() as Implosion
	if implosion == null:
		return
	if ability:
		implosion.effect_range = ability.effect_range_m
		implosion.duration_s = ability.duration_s
	implosion.side = int(shot.get("from_slot"))
	shot.get_parent().add_child(implosion)
	implosion.global_position = point
	print("implosión en (%.2f, %.2f, %.2f) %.1f m en %.2f s (cuadro %d)" % [point.x, point.y, point.z, implosion.effect_range,
		implosion.duration_s, MatchClock.now()])
