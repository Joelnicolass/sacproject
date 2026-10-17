class_name PushImpact
extends ShotImpact

## F121 (RFC-030j): Squall amba (updateSquallProjectile, state.d:23996-24003): a creature or a wizard it hits is pushed
## (pushback, 11677-11685) before the damage; a building and the ground are not. The push is a Pushback child of the
## body, along the shot. If the body is already thrown, its thrower becomes this side (tumbleAttackerSide).

@export var pushback_scene: PackedScene
## sacengine movingObjects (creatures and wizards).
@export var groups: Array[StringName] = [&"wizard", &"unit"]


func _affect(shot: Node3D, target: Node3D, _point: Vector3, _ability: AbilityType) -> void:
	if target == null or not is_instance_valid(target) or pushback_scene == null or not _moves(target):
		return
	var tumbling := BodyNudge.tumbling_of(target)
	if tumbling and tumbling.is_on():
		tumbling.attacker_slot = int(shot.get("from_slot"))
	var push := pushback_scene.instantiate() as Pushback
	if push == null:
		return
	push.direction = (shot.get("velocity") as Vector3).normalized()
	target.add_child(push)
	print("empuje a %s dir (%.3f, %.3f, %.3f)" % [who(target), push.direction.x, push.direction.y, push.direction.z])


func _moves(body: Node3D) -> bool:
	for group in groups:
		if body.is_in_group(group):
			return true
	return false
