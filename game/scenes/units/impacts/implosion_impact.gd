class_name ImplosionImpact
extends ShotImpact

## F121 (RFC-030j): the Flurry's caba (flurryProjectileImplosion, state.d:24577-24598): after the damage (its SplashImpact
## sibling) an implosion of effectRange that shrinks over the SPEL's duration starts where the shot burst. It goes to
## the shot's parent, so it outlives the shot.

@export var implosion_scene: PackedScene


func _affect(shot: Node3D, _target: Node3D, point: Vector3, ability: AbilityType) -> void:
	if implosion_scene == null or shot.get_parent() == null:
		return
	var implosion := implosion_scene.instantiate() as Implosion
	if implosion == null:
		return
	if ability:
		implosion.effect_range = ability.effect_range
		implosion.duration_s = ability.duration
	implosion.side = int(shot.get("from_slot"))
	shot.get_parent().add_child(implosion)
	implosion.global_position = point
	print("implosión en (%.2f, %.2f, %.2f) %.1f m en %.2f s (cuadro %d)" % [point.x, point.y, point.z, implosion.effect_range,
		implosion.duration_s, MatchClock.now()])
