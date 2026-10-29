class_name GuidedFlight
extends RefCounted

## The flight of a guided SpellCarrier (Dragonfire's dragon), with the state it needs and no node of
## its own: it climbs a spiral around the wizard while he casts, flies to its target when the
## casting ends (a body it follows, or a point), turning at a limited rate and never under a height,
## and shrinks away at the end. It moves the carrier it is given; what an arrival does is the
## carrier's CarrierArrive.

var wizard: Node3D
var target: Node3D
var goal := Vector3.ZERO
var direction := Vector3.FORWARD
var cast_ticks := 1
var tick := 0

var _carrier: SpellCarrier


func _init(carrier: SpellCarrier) -> void:
	_carrier = carrier


func begin(caster: Node3D, aimed: Node3D, point: Vector3, ticks: int) -> void:
	wizard = caster
	target = aimed
	goal = point
	cast_ticks = maxi(1, ticks)
	tick = 0
	_carrier.phase = SpellCarrier.Phase.CASTING
	_carrier.set_physics_process(true)


func release(aimed: Node3D) -> void:
	if aimed != null and is_instance_valid(aimed):
		target = aimed
	_carrier.phase = SpellCarrier.Phase.FLYING
	_carrier.scale = Vector3.ONE


## A new goal: a body to follow, or a point on the land.
func retarget(body: Node3D, point: Vector3) -> void:
	target = body
	goal = point


## No more targets: it shrinks away.
func finish() -> void:
	_carrier.phase = SpellCarrier.Phase.SHRINKING


func target_body() -> Node3D:
	return (
		target if target != null and is_instance_valid(target) and target.is_inside_tree() else null
	)


func step() -> void:
	match _carrier.phase:
		SpellCarrier.Phase.CASTING:
			_cast_step()
		SpellCarrier.Phase.FLYING:
			_fly_step()
		SpellCarrier.Phase.SHRINKING:
			_carrier.scale -= Vector3.ONE / (_carrier.shrink_s * MatchClock.TICKS_PER_SECOND_F)
			if _carrier.scale.x <= 0.0:
				_carrier.stop()


## One turn around the wizard, climbing to `cast_height_m` over his head, growing as it goes.
func _cast_step() -> void:
	if wizard == null or not is_instance_valid(wizard):
		_carrier.stop()
		return
	tick += 1
	var p := minf(1.0, float(tick) / float(cast_ticks))
	var at := CarrierPath.spiral(
		wizard,
		float(cast_ticks) / MatchClock.TICKS_PER_SECOND_F,
		_carrier.speed,
		_carrier.cast_height_m,
		p
	)
	_face(at - _carrier.global_position)
	_carrier.global_position = at
	_carrier.scale = Vector3.ONE * maxf(p, 0.01)


## Follow the target, turn at a limited rate, never under `flying_height_m`.
func _fly_step() -> void:
	if _carrier.on_arrive != null:
		_carrier.on_arrive.along(_carrier)
	var body := target_body()
	var center := BodyNudge.center(body) if body != null else goal
	goal = center
	var to := center - _carrier.global_position
	var rate := (
		maxf(_carrier.turn_rate, 1.1 * _carrier.speed / maxf(to.length(), 0.01))
		if to.length_squared() < 16.0
		else _carrier.turn_rate
	)
	direction = CarrierPath.turned(direction, to.normalized(), rate / MatchClock.TICKS_PER_SECOND_F)
	var next := (
		_carrier.global_position + direction * _carrier.speed / MatchClock.TICKS_PER_SECOND_F
	)
	var ground := GroundRay.surface_y(
		_carrier, next, 1, GroundRay.wizard_rids(_carrier.get_tree()), -INF
	)
	var low := is_finite(ground) and next.y < ground + _carrier.flying_height_m
	if low:
		next.y = ground + _carrier.flying_height_m
		direction = (next - _carrier.global_position).normalized()
	_face(direction)
	_carrier.global_position = next
	var flat := Vector2(center.x - next.x, center.z - next.z).length()
	if (
		(center - next).length() < _carrier.arrive_distance_m
		or (low and center.y < next.y and flat < 0.5)
	):
		if _carrier.on_arrive != null:
			_carrier.on_arrive.arrive(_carrier)
		else:
			_carrier.arrive_at(target_body())


## The head (+Z) looks where it goes.
func _face(heading: Vector3) -> void:
	if heading.length_squared() > 0.000001:
		direction = heading.normalized()
		var up := Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT
		_carrier.quaternion = Basis.looking_at(-direction, up).get_rotation_quaternion()
