class_name StalkRules
extends RefCounted

## The plain numbers of a Meanstalk with no tree: the curve its body follows from the root to the tip, how the tip speeds up towards its goal,
## which bodies it may reach and where it wanders. It does not decide when the tip moves, who it grabs nor how it is drawn (Stalk and
## StalkLook do).

## The hold the tip keeps on a body: the horizontal reach of the original's pick, 10 to 45 m from the root, with the height counted half.
const PICK_MIN_M := 10.0
const PICK_MAX_M := 45.0
const PICK_VERTICAL_WEIGHT := 0.5
## A stalk shorter than this bulges sideways (a tip that is close looks like a loop).
const BULGE_BELOW_M := 60.0
## How far the control points of each half stand from the joint along the stalk, m.
const HANDLE_M := 10.0
## Distance to the goal below which the tip slows down, m.
const SLOW_M := 3.0


## Radius of the stalk at `t` (0 root, 1 tip): 2 m, 1.8 m at the middle, 0 at the tip (two cubic Béziers).
static func radius(t: float) -> float:
	if t <= 0.5:
		return _bezier(2.0, 2.0, 2.0, 1.8, 2.0 * t)
	return _bezier(1.8, 1.6, 1.0, 0.0, 2.0 * t - 1.0)


## The eight control points of the two cubic halves of the stalk, from `base` to `tip`, then the frame vector that remembers which way it bulges
## (the ninth value). `frame` is the one the last call returned (start with Vector3.ONE).
static func curve(base: Vector3, tip: Vector3, frame: Vector3) -> PackedVector3Array:
	var delta := tip - base
	var length := delta.length()
	var bulge := 0.0
	if length < BULGE_BELOW_M:
		var t := 900.0 - 0.25 * length * length
		bulge = 0.5 * (sqrt(t) + sqrt(sqrt(t)))
	var direction := Vector3.UP if length == 0.0 else delta / length
	var d := direction.dot(frame)
	var k := 4.0 * (d * d - 0.75) if d * d > 0.75 else 0.0
	var side := frame + k * k * (Vector3(0.0, 0.0, 1.0) - frame)
	var out := direction.cross(side).normalized().cross(direction)
	var bend := 0.5 * delta + bulge * out
	var p1 := bend + HANDLE_M * direction
	var p2 := Vector3(delta.x + 0.3 * (p1.x - delta.x), delta.y + 0.7 * (p1.y - delta.y), delta.z + 0.3 * (p1.z - delta.z))
	return PackedVector3Array([
		base, base + Vector3(0.0, HANDLE_M, 0.0), base + bend - HANDLE_M * direction, base + bend,
		base + bend, base + p1, base + p2, tip,
		out + 0.2 * (Vector3.UP - out)])


## One tick of the tip towards `goal`: the speed grows by `accel` m/s each second up to `rate`, and slows down inside SLOW_M of the goal.
## Returns [new tip, new velocity].
static func step_tip(tip: Vector3, velocity: Vector3, goal: Vector3, rate: float, accel: float) -> PackedVector3Array:
	var delta := goal - tip
	var gap := delta.length()
	var top := rate if gap >= SLOW_M else rate * gap / SLOW_M
	var most := accel / MatchClock.TICKS_PER_SECOND_F
	if gap > most:
		delta *= most / gap
	velocity += MatchClock.TICKS_PER_SECOND_F * delta
	if velocity.length() > top:
		velocity *= top / velocity.length()
	return PackedVector3Array([tip + velocity / MatchClock.TICKS_PER_SECOND_F, velocity])


## True when a body at `at` is inside the band the stalk can take from `base` (10 to 45 m, height counted half).
static func in_pick_band(base: Vector3, at: Vector3) -> bool:
	var delta := base - at
	delta.y *= PICK_VERTICAL_WEIGHT
	var gap := delta.length()
	return PICK_MIN_M <= gap and gap <= PICK_MAX_M


## A point of the cone over `base` that a stalk without a prey drifts to: `lean` (-π/4..π/4) from the vertical, `turn` (0..2π) around it.
static func wander_point(base: Vector3, lean: float, turn: float, radius_m: float, height_m: float) -> Vector3:
	return base + Vector3(radius_m * sin(lean) * sin(turn), height_m * cos(lean), radius_m * sin(lean) * cos(turn))


## True while the body can be taken: still there, alive, not a corpse.
static func is_live(body: Node3D) -> bool:
	if body == null or not is_instance_valid(body) or not Attackable.is_body(body):
		return false
	var health := Health.of(body)
	return health != null and not health.is_dead()


static func _bezier(p0: float, p1: float, p2: float, p3: float, u: float) -> float:
	var v := 1.0 - u
	return v * v * v * p0 + 3.0 * v * v * u * p1 + 3.0 * v * u * u * p2 + u * u * u * p3
