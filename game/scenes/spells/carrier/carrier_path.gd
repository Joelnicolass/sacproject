class_name CarrierPath
extends RefCounted

## The route of a carrier: for the one that walks to a soul and brings it back, two curves that bend to one side, so it never goes in a
## straight line. It only does the arithmetic (no tree, no ground): the SpellCarrier asks where to be at tick `f` and puts the
## result on the ground. Out and back take the same number of ticks.
## Ref: sacengine cintp2 and updateSoulMolePosition (util.d:554, state.d:17938-18028).


## Hermite curve through `p0` (leaving with `m0`) and `p1` (arriving with `m1`), at `t` in [0, 1].
static func hermite(p0: Vector3, m0: Vector3, p1: Vector3, m1: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * p0 + (t3 - 2.0 * t2 + t) * m0 + (-2.0 * t3 + 3.0 * t2) * p1 + (t3 - t2) * m1


## The sideways push of the trip: flat, at right angles to the line `from` -> `to`, `bend` times as long as that line.
static func side_velocity(from: Vector3, to: Vector3, bend: float) -> Vector3:
	var line := to - from
	return bend * line.length() * Vector3.UP.cross(line).normalized()


## Tick `f` (1..leg_ticks) of the way from `start` to the soul: leaves straight, arrives with the sideways push.
static func out_at(start: Vector3, soul: Vector3, side: Vector3, f: int, leg_ticks: int) -> Vector3:
	return hermite(start, Vector3.ZERO, soul, side, clampf(float(f) / float(leg_ticks), 0.0, 1.0))


## Tick `f` (1..leg_ticks, counted from the turn) of the way from `turn` back to the wizard: leaves with the sideways push, arrives
## slowing down.
static func back_at(turn: Vector3, wizard: Vector3, side: Vector3, f: int, leg_ticks: int) -> Vector3:
	return hermite(turn, side, wizard, 0.75 * (wizard - turn), clampf(float(f) / float(leg_ticks), 0.0, 1.0))


## Where a guided carrier is `progress` (0 to 1) of the way through the casting: one turn around the wizard, climbing from his feet to
## `height_m` over his head, in a circle that opens as it goes (`cast_s` and `speed` size the circle). Dragonfire's dragon.
## Ref: sacengine dragonfireCastingPosition (state.d:18698-18706).
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
