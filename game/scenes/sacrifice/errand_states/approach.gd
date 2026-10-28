extends ErrandStep

## The doctor walks to what it came for, through its `motor`.
## Desecrate: if the creature is no longer a valid target (dead, changed owner, taken) or the site
## fell, the doctor dies; closer than `pickup_m` of SacrificeFacts (on the plane) it takes the
## creature and goes on to Haul.
## Convert: if the soul is not there to convert any more (somebody took it, its corpse is gone) or
## the site fell, the doctor dies; closer than `pump_reach_m` (on the plane) it goes on to Pump. It
## walks to the free land closest to the soul: a soul that fell against a building (inside what the
## navmesh leaves around it) is pumped from as close as the land lets it stand, up to
## `max_blocked_reach_m`; farther than that it cannot be reached and the doctor gives up (dies).
## Nothing to undo if the doctor dies here, but a Convert soul becomes convertible again.

## What a Convert approach does this tick.
enum Next { WALK, PUMP, GIVE_UP }

## The farthest (m, on the plane) the doctor pumps from when the land does not let it stand within
## `pump_reach_m` of the soul.
@export_range(0.0, 30.0, 0.1, "suffix:m") var max_blocked_reach_m := 8.0
## How close (m) to its standing point counts as standing there (the path ends within its own
## arrive distance).
@export_range(0.0, 5.0, 0.05, "suffix:m") var stand_tolerance_m := 1.5


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
	var stand_at := _stand_point(soul_at)
	var reach := SacrificeFacts.of_rules(body.rules).pump_reach_m
	match next_step(
		body.global_position, soul_at, stand_at, reach, max_blocked_reach_m, stand_tolerance_m
	):
		Next.PUMP:
			transition(&"Pump")
		Next.GIVE_UP:
			body.kill()
		_:
			body.motor.walk_to(stand_at)


## The Convert decision. The doctor at `body_at` comes for the soul at `soul_at`; `stand_at` is the
## free land closest to the soul (the soul itself without a navmesh). Within `reach` of the soul it
## pumps. Standing as close as the land lets it (within `tolerance` of `stand_at`) while that is
## farther than `reach`: it pumps from there up to `max_reach`, else it gives up. Else it walks.
static func next_step(
	body_at: Vector3,
	soul_at: Vector3,
	stand_at: Vector3,
	reach: float,
	max_reach: float,
	tolerance: float
) -> Next:
	if _flat(body_at, soul_at) < reach:
		return Next.PUMP
	var gap := _flat(stand_at, soul_at)
	if gap >= reach and _flat(body_at, stand_at) <= tolerance:
		return Next.PUMP if gap <= max_reach else Next.GIVE_UP
	return Next.WALK


func _flat_distance(body: DoctorBody, point: Vector3) -> float:
	return _flat(body.global_position, point)


# The free land closest to `soul_at`, or the soul's own place without a navmesh (or with none near).
func _stand_point(soul_at: Vector3) -> Vector3:
	var nav := get_tree().get_first_node_in_group(NavService.GROUP) as NavService
	if nav == null:
		return soul_at
	var land := nav.nearest_free(soul_at)
	return soul_at if is_nan(land.x) else Vector3(land.x, soul_at.y, land.z)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
