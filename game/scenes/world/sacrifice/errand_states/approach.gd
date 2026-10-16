extends ErrandStep

## The doctor walks to what it came for.
## Desecrate (sacengine SacDocCarry `walk`, state.d:15700-15722): if the creature is no longer a valid
## target (dead, changed owner, taken) or the site fell, the doctor dies; closer than
## rules.desecrate_pickup_distance on the plane it takes the creature and goes on to Haul.
## Convert (state.d:15676-15699): if the soul is not there to convert any more (somebody took it, its
## corpse is gone) or the site fell, the doctor dies; closer than rules.convert_reach on the plane it goes
## on to Pump. Nothing to undo if the doctor dies here, but a Convert soul becomes convertible again.


func physics_update(_delta: float) -> void:
	var body := errand.body
	if body.is_dead():
		return
	if errand.kind == Ritual.Kind.CONVERT:
		_convert(body)
	else:
		_desecrate(body)


func doctor_died() -> void:
	errand.release_soul()


func _desecrate(body: DoctorBody) -> void:
	if not errand.creature_is_free() or not errand.site_standing():
		body.kill()
		return
	var creature := errand.creature
	var pickup := body.rules.desecrate_pickup_distance if body.rules else 10.0
	if _flat_distance(body, creature.global_position) >= pickup:
		body.walk_to(creature.global_position)
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
	var reach := body.rules.convert_reach if body.rules else 2.0
	if _flat_distance(body, soul_at) >= reach:
		body.walk_to(soul_at)
		return
	transition(&"Pump")


func _flat_distance(body: DoctorBody, point: Vector3) -> float:
	return Vector2(point.x - body.global_position.x, point.z - body.global_position.z).length()
