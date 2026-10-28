extends ErrandStep

## The doctor walks to what it came for, through its `motor`.
## Desecrate: if the creature is no longer a valid target (dead, changed owner, taken) or the site
## fell, the doctor dies; closer than `pickup_m` of SacrificeFacts (on the plane) it takes the
## creature and goes on to Haul.
## Convert: if the soul is not there to convert any more (somebody took it, its corpse is gone) or
## the site fell, the doctor dies; closer than `pump_reach_m` (on the plane) it goes on to Pump.
## Nothing to undo if the doctor dies here, but a Convert soul becomes convertible again.


func physics_update(_delta: float) -> void:
	var body := errand.body
	if body.is_dead():
		return
	if errand.kind == Ritual.Kind.CONVERT:
		_convert(body)
	else:
		_desecrate(body)


func _desecrate(body: DoctorBody) -> void:
	if not errand.creature_is_free() or not errand.site_standing():
		body.kill()
		return
	var creature := errand.creature
	if (
		_flat_distance(body, creature.global_position)
		>= SacrificeFacts.of_rules(body.rules).pickup_m
	):
		body.motor.walk_to(creature.global_position)
		return
	var captive := Captive.of(creature)
	if captive == null or not captive.take(body):
		body.kill()
		return
	errand.captive = captive
	transition(&"Haul")


func _convert(body: DoctorBody) -> void:
	if not errand.soul_is_waiting() or not errand.site_standing():
		body.kill()
		return
	var soul_at := errand.soul.global_position
	if _flat_distance(body, soul_at) >= SacrificeFacts.of_rules(body.rules).pump_reach_m:
		body.motor.walk_to(soul_at)
		return
	transition(&"Pump")


func _flat_distance(body: DoctorBody, point: Vector3) -> float:
	return Vector2(point.x - body.global_position.x, point.z - body.global_position.z).length()
