class_name ZoneRules
extends RefCounted

## The plain numbers of the ground zones, with no tree: how hard a blast throws a body, which blast point a body answers to, how fast the
## ice grows, where each step of the breaking ring reaches, and where a scattered point lands. It does not hurt, freeze or draw anything.

## The weakest and the strongest throw, in m/s, and how much of the span the distance takes away.
const THROW_FLOOR := 5.0
const THROW_CEILING := 20.0
const THROW_SPAN := 17.5
## A body is thrown away from a spot this far under the blast point, so it always leaves upwards.
const THROW_PIT_M := 5.0


## m/s a body at `distance` from a blast of `blast_range` leaves at: 20 at the most, 5 + 17.5 · (1 − d / range) otherwise.
static func throw_strength(distance: float, blast_range: float) -> float:
	return minf(
		THROW_CEILING, THROW_FLOOR + THROW_SPAN * (1.0 - distance / maxf(blast_range, 0.001))
	)


## Which blast point a body at `at` answers to: the first one when it is in range, else the closest one in range. -1 = none.
static func nearest_blast(points: PackedVector3Array, at: Vector3, blast_range: float) -> int:
	var best := -1
	var best_d := INF
	for i in points.size():
		var d := points[i].distance_to(at)
		if d > blast_range or d >= best_d:
			continue
		best = i
		best_d = d
		if i == 0:
			break
	return best


## The velocity of a thrown body: away from a spot under its blast point, at the strength of its distance.
static func throw_velocity(at: Vector3, point: Vector3, blast_range: float) -> Vector3:
	var away := at - (point - Vector3(0.0, THROW_PIT_M, 0.0))
	return away.normalized() * throw_strength(point.distance_to(at), blast_range)


## The radius of ground that is ice `ticks` after it started: it covers `max_m` in `grow_ticks` on a curve that starts fast.
static func grown_radius(max_m: float, ticks: int, grow_ticks: int) -> float:
	if grow_ticks <= 0 or ticks >= grow_ticks:
		return max_m
	var t := 1.0 - float(maxi(ticks, 0)) / float(grow_ticks)
	return max_m * sqrt(1.0 - t * t)


## How far step `step` of `steps` reaches, counted from the centre outwards (step 6 of 6 is the whole disc).
static func ring_radius(step: int, steps: int, max_m: float) -> float:
	return max_m * clampf(float(step) / float(maxi(steps, 1)), 0.0, 1.0)


## A uniform point of a disc of `radius` around the origin, on the ground plane.
static func disk_point(rng: RandomNumberGenerator, radius: float) -> Vector3:
	var angle := rng.randf() * TAU
	var length := radius * sqrt(rng.randf())
	return Vector3(cos(angle) * length, 0.0, sin(angle) * length)


## `count` points around `center`, one per equal slice of a turn (the first slice starts half a slice in), each at a random angle within
## ±`jitter_rad` of its slice's middle and a random distance between `inner_m` and `outer_m` (the roots of Meanstalks: 9 to 21.6 m).
static func ring_points(
	rng: RandomNumberGenerator,
	center: Vector3,
	count: int,
	inner_m: float,
	outer_m: float,
	jitter_rad: float
) -> PackedVector3Array:
	var points := PackedVector3Array()
	var step := TAU / float(maxi(count, 1))
	for i in count:
		var angle := step * (0.5 + i) + rng.randf_range(-jitter_rad, jitter_rad)
		var length := outer_m - (outer_m - inner_m) * rng.randf()
		points.append(center + Vector3(sin(angle) * length, 0.0, cos(angle) * length))
	return points


## Distance on the ground plane from `point` to the foot of a body's box (0 inside it).
static func flat_gap(box: AABB, point: Vector3) -> float:
	var dx := maxf(0.0, maxf(box.position.x - point.x, point.x - box.end.x))
	var dz := maxf(0.0, maxf(box.position.z - point.z, point.z - box.end.z))
	return sqrt(dx * dx + dz * dz)


## The velocity that takes a drop from `start` to `goal` in `seconds`: the straight line of that time, plus (`lobbed`) what its `gravity`
## takes away over the flight, so it lands on `goal` right on time.
static func launch_velocity(
	start: Vector3, goal: Vector3, seconds: float, gravity: float, lobbed: bool
) -> Vector3:
	var line := (goal - start) / maxf(seconds, 0.001)
	return line + Vector3(0.0, 0.5 * gravity * seconds, 0.0) if lobbed else line


## The velocity of a shot at `speed` m/s from `start` toward `goal` that leans up to make up for `gravity` (a lava ball): the unit
## direction plus half the pull times the distance over the speed squared, not normalised again, as the original shoots.
static func shot_velocity(start: Vector3, goal: Vector3, speed: float, gravity: float) -> Vector3:
	var offset := goal - start
	var direction := offset.normalized() if offset.length() > 0.0 else offset
	direction.y += 0.5 * gravity * offset.length() / maxf(speed * speed, 0.001)
	return direction * speed
