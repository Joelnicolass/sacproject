class_name VillagerFleeState
extends VillagerState

## FLEE: runs straight away from the threat, `leg_m` ahead of it each time the Brain thinks. The
## Brain sends both as the transition payload ({"threat": Node3D, "leg_m": float}); a repeat of Flee
## with a new payload runs again without exit / enter.


func enter() -> void:
	super.enter()
	_run(machine.payload)


func apply_payload(next_payload: Variant) -> void:
	_run(next_payload)


func _run(run: Variant) -> void:
	if not run is Dictionary:
		return
	var threat := run.get("threat") as Node3D
	if threat == null:
		return
	if body.is_cowering():
		body.halt()
	var away := body.global_position - threat.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3(sin(body.rotation.y), 0.0, cos(body.rotation.y))
	body.begin_walk(body.global_position + away.normalized() * float(run.get("leg_m", 0.0)))
