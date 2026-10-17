class_name DirectImpact
extends ShotImpact

## F121 (RFC-030j): the shot's whole amount as direct ranged damage to the body it hit (dealRangedDamage with
## DamageMod.none: Squall amba state.d:24001-24003, Vortick cita 23869-23873). What RangedShot does with no impact,
## as a child, so an impact scene can push or spin a vortex and still hit. A building takes it too; the ground nothing.

const _HEALTH := preload("res://scenes/world/components/health.gd")
const _ROCK := preload("res://scenes/world/spells/rock_projectile.gd")


func _affect(shot: Node3D, target: Node3D, _point: Vector3, _ability: AbilityType) -> void:
	if target == null or not is_instance_valid(target) or not _ROCK.is_live_body(target):
		return
	var taken := float(target.get_node("Health").call("damage_typed", float(shot.get("damage")), _HEALTH.DIRECT_RANGED, int(shot.get("from_slot"))))
	print("  directo %s %.1f" % [who(target), taken])
