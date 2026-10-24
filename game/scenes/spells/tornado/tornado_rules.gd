class_name TornadoRules
extends RefCounted

## The plain numbers of a Tornado with no tree: the seven points of its axis and their radii (the funnel is 500 m tall, its top fixed and
## its foot wandering), the winds that bend it, which point of the axis a body at some height answers to, and the pull on a body that is
## inside. It does not lift anybody (TornadoLift does), move the tornado (TornadoDrift does) or draw it (TornadoLook does).
## Ref: sacengine Tornado.updateCurve and getCentre, tornadoLift (state.d:4465-4505, 22760-22801).

## How tall the column is above its point, m.
const COLUMN_M := 500.0
## Radius at the top, at the wide part and at the foot, m (the six points below the top lie between the last two).
const TOP_RADIUS_M := 300.0
const WIDE_M := 100.0
const FOOT_M := 1.5
## A body is pulled when it stands within this of the funnel's wall; it is moved to a spiral this far outside the axis, m.
const WALL_RANGE_M := 30.0
const SPIRAL_M := 15.0
## The most a body is moved in a tick, m, and its top speed, m/s.
const STEP_M := 3.0
const TOP_SPEED := 30.0
## How high above itself the pull aims, m.
const RISE_M := 2.0
## Turns of the winds that bend the funnel, rad/s, and the turn the spiral target is rotated by (5 «radians», as the original wrote them).
const WIND_RATES: Array[float] = [0.6, -0.48, -0.78, 0.36]
const SPIRAL_TURN := 5.0 * 360.0 / TAU


## The radius of each of the seven points of the axis.
static func radii() -> PackedFloat32Array:
	var span := FOOT_M - WIDE_M
	return PackedFloat32Array([
		TOP_RADIUS_M, WIDE_M + span * 0.6, WIDE_M + span * 0.6, WIDE_M + span * 0.675,
		WIDE_M + span * 0.75, WIDE_M + span * 0.95, FOOT_M])


## The seven points of the axis: the top, the foot (`size` of the way from the top to `foot`), and between them points that the winds
## (`phases`, four angles) push sideways by up to 0.3 of the height.
static func axis(top: Vector3, foot: Vector3, size: float, phases: PackedFloat32Array) -> PackedVector3Array:
	var bottom := top + size * (foot - top)
	var step := (bottom - top) / 6.0
	var p2 := top + 1.5 * step
	var p4 := top + 4.5 * step
	var sway := (bottom.y - top.y) * 0.3
	p2.x += sway * sin(phases[0])
	p2.z += sway * sin(phases[1])
	p4.x += sway * sin(phases[2])
	p4.z += sway * sin(phases[3])
	return PackedVector3Array([top, top + step, p2, 0.5 * (p2 + p4), p4, top + 5.0 * step, bottom])


## The phase of wind `i` after `ticks` ticks, from the angle it started at.
static func wind_phase(start: float, i: int, ticks: int) -> float:
	return start + WIND_RATES[i] * float(ticks) / MatchClock.TICKS_PER_SECOND_F


## The point of the axis at the height of `at` and the radius of the funnel there, as (x, y, z, radius).
static func centre(points: PackedVector3Array, radii_m: PackedFloat32Array, at: Vector3) -> Vector4:
	var span := points[0].y - points[6].y
	var t := 1.0 if absf(span) < 0.001 else clampf((points[0].y - at.y) / span, 0.0, 1.0)
	var i := 0 if t <= 0.5 else 3
	var u := 2.0 * t if t <= 0.5 else 2.0 * (t - 0.5)
	var v := 1.0 - u
	var point := v * v * v * points[i] + 3.0 * v * v * u * points[i + 1] + 3.0 * v * u * u * points[i + 2] + u * u * u * points[i + 3]
	var radius := v * v * v * radii_m[i] + 3.0 * v * v * u * radii_m[i + 1] + 3.0 * v * u * u * radii_m[i + 2] + u * u * u * radii_m[i + 3]
	return Vector4(point.x, point.y, point.z, radius)


## The velocity to add to a body at `at` for a funnel whose axis there is `centre`: toward a point of a spiral SPIRAL_M outside the wall,
## 2 m above the body, at most STEP_M per tick. `Vector3.INF` when the body is out of reach (farther than WALL_RANGE_M from the wall).
static func pull(at: Vector3, centre_at: Vector4) -> Vector3:
	var dx := centre_at.x - at.x
	var dz := centre_at.z - at.z
	var gap := sqrt(dx * dx + dz * dz)
	if gap > centre_at.w + WALL_RANGE_M:
		return Vector3.INF
	if gap != 0.0:
		var scale := (centre_at.w + SPIRAL_M) / gap
		dx *= scale
		dz *= scale
	var c := cos(SPIRAL_TURN)
	var s := sin(SPIRAL_TURN)
	var target := Vector3(centre_at.x + c * dx - s * dz, at.y + RISE_M, centre_at.z + s * dx + c * dz)
	var delta := target - at
	var most := STEP_M / MatchClock.TICKS_PER_SECOND_F
	if delta.length() > most:
		delta *= most / delta.length()
	return delta * MatchClock.TICKS_PER_SECOND_F


## A random offset of the wander: the square of a draw in 0..1 times `range_m`, to either side (`left` picks the side).
static func wander_offset(range_m: float, draw: float, left: bool) -> float:
	var offset := draw * draw * range_m
	return -offset if left else offset
