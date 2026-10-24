class_name CarrierPath
extends RefCounted

## The geometry of a carrier's flight, with no state: the spiral it climbs around the wizard while he casts, and the limited turn toward its
## target. It moves nothing (SpellCarrier does).
## Ref: sacengine dragonfireCastingPosition, changeDirectionTowards (state.d:18698-18706, 18776-18799).


## Where the carrier is `progress` (0 to 1) of the way through the casting: one turn around the wizard, climbing from his feet to
## `height_m` over his head, in a circle that opens as it goes (it needs `speed` and the casting time to size the circle).
static func spiral(wizard: Node3D, cast_s: float, speed: float, height_m: float, progress: float) -> Vector3:
	var top := BodyNudge.box(wizard).end.y - wizard.global_position.y + height_m
	var radius := 0.5 * cast_s * speed / TAU * (0.5 + 0.5 * progress)
	var angle := TAU * progress
	return wizard.global_position + wizard.global_basis * Vector3(radius * cos(angle), top * progress, radius * sin(angle))


## `from` turned toward `to` by at most `max_angle` radians (both unit vectors).
static func turned(from: Vector3, to: Vector3, max_angle: float) -> Vector3:
	if from.angle_to(to) <= max_angle:
		return to
	var axis := from.cross(to)
	if axis.length_squared() < 0.000001:
		axis = from.cross(Vector3.UP) if absf(from.y) < 0.99 else from.cross(Vector3.RIGHT)
	return from.rotated(axis.normalized(), max_angle).normalized()
