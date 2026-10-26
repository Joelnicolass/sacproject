class_name VillagerFleeState
extends VillagerState

## FLEE: runs straight away from `threat`, `leg_m` ahead of it each time the Brain thinks.


func run_from(threat: Node3D, leg_m: float) -> void:
	if body.is_cowering():
		body.halt()
	var away := body.global_position - threat.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3(sin(body.rotation.y), 0.0, cos(body.rotation.y))
	body.begin_walk(body.global_position + away.normalized() * leg_m)
