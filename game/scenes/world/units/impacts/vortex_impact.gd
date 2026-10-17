class_name VortexImpact
extends ShotImpact

## F121 (RFC-030j): the Vortick's cita (updateVortickProjectile, state.d:23840-23879): wherever it ends (a creature, a
## building, the ground or the end of its range) it spawns a vortex (spawnVortex, 11663-11667) at the position of the
## tick before (oldPosition). The vortex goes to the shot's parent, so it outlives the shot.

@export var vortex_scene: PackedScene


func _affect(shot: Node3D, _target: Node3D, point: Vector3, ability: AbilityType) -> void:
	if vortex_scene == null or shot.get_parent() == null:
		return
	var vortex := vortex_scene.instantiate() as Vortex
	if vortex == null:
		return
	if ability:
		vortex.radius = ability.effect_range
	vortex.side = int(shot.get("from_slot"))
	var before := point - (shot.get("velocity") as Vector3) / float(MatchClock.TICKS_PER_SECOND)
	shot.get_parent().add_child(vortex)
	vortex.global_position = before
	print("vórtice en (%.2f, %.2f, %.2f) radio %.1f m (cuadro %d)" % [before.x, before.y, before.z, vortex.radius, MatchClock.now()])
