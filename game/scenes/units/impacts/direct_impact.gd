class_name DirectImpact
extends ShotImpact

## The shot's whole amount as direct ranged damage to the body it hit. What RangedShot does with no impact,
## as a child, so an impact scene can push or spin a vortex and still hit. A building takes it too; the ground nothing.
## Ref: F121 (RFC-030j); dealRangedDamage with DamageMod.none: Squall amba state.d:24001-24003, Vortick cita 23869-23873.

const _HEALTH := preload("res://scenes/components/health.gd")


func _affect(shot: Node3D, target: Node3D, _point: Vector3, _ability: AbilityType) -> void:
	if target == null or not is_instance_valid(target) or not ProjectileTargets.is_live_body(target):
		return
	var taken := (target.get_node("Health") as Health).damage_typed(float(shot.get("damage")), _HEALTH.DIRECT_RANGED, int(shot.get("from_slot")), false, false, mods_of(shot))
	print("  directo %s %.1f" % [GameBody.name_of(target), taken])
	LifeDrain.feed(shooter_of(shot), target, taken)  ## F164
