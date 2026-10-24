class_name SpellCarrier
extends SpellProjectile

## Something a spell sends flying and that does its work when it arrives (the dragon of Dragonfire). It rises in a spiral around the wizard
## while he casts, flies to its target when the casting ends (a body it follows, or a point), and on arriving asks its `on_arrive` what
## to do: pick another target or go away (it shrinks to nothing). It does not know what an arrival does (its CarrierArrive) nor who comes
## next (the ChainHop). The server (or solo) moves it; `position`, `rotation` and `scale` are replicated and every peer draws the look.
## This is the minimum of the plan's SpellCarrier (only the guided flight); other motions are the next spells' business.
## Ref: sacengine Dragonfire, dragonfireCastingPosition, changeDirectionTowards (state.d:18698-18871).

enum Phase { WAITING, CASTING, FLYING, SHRINKING }

@export var on_arrive: CarrierArrive
## Radians per second it can turn toward its target; it turns faster when it is close.
@export_range(0.1, 12.0, 0.1, "suffix:rad/s") var turn_rate := PI
## It never flies lower than this over the land.
@export_range(0.0, 5.0, 0.1, "suffix:m") var flying_height_m := 1.0
## It has arrived when its center is this close to the target's.
@export_range(0.1, 3.0, 0.05, "suffix:m") var arrive_distance_m := 0.75
## Seconds it takes to shrink to nothing at the end.
@export_range(0.1, 5.0, 0.1, "suffix:s") var shrink_s := 1.0
@export_group("Casting")
## It climbs this far over the top of the wizard's box while he casts, in one turn around him.
@export_range(0.0, 10.0, 0.1, "suffix:m") var cast_height_m := 4.0

var speed := 0.0
var damage := 0.0
var damage_range := 0.0
var slot := 0
var phase := Phase.WAITING

var _wizard: Node3D
var _target: Node3D
var _goal := Vector3.ZERO
var _direction := Vector3.FORWARD
var _cast_ticks := 1
var _tick := 0
var _caster_path := NodePath()


func setup(data: Dictionary) -> void:
	name = str(data["name"])
	position = Vector3(float(data["x"]), float(data["y"]), float(data["z"]))
	speed = float(data["speed"])
	damage = float(data.get("damage", 0.0))
	damage_range = float(data.get("damage_range", 0.0))
	slot = int(data.get("slot", 0))
	_caster_path = NodePath(str(data.get("caster", "")))
	scale = Vector3.ONE * 0.01
	MpAuthority.ensure_sync(self, PackedStringArray([".:position", ".:rotation", ".:scale"]))


func _ready() -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)
		return
	set_physics_process(phase != Phase.WAITING)


## Server (or solo): the cast started; the carrier follows `wizard` for `cast_ticks` ticks.
func begin(wizard: Node3D, spell: SpellType, target: Node3D, point: Vector3, cast_ticks: int) -> void:
	_wizard = wizard
	_target = target
	_goal = point
	_cast_ticks = maxi(1, cast_ticks)
	_tick = 0
	phase = Phase.CASTING
	set_physics_process(true)
	if on_arrive != null:
		on_arrive.begin(self, wizard, spell, target)


## Server (or solo): the casting ended; it flies to `target`.
func release(target: Node3D) -> void:
	if target != null and is_instance_valid(target):
		_target = target
	phase = Phase.FLYING
	scale = Vector3.ONE
	if on_arrive != null:
		on_arrive.released(self, _target)


## Server (or solo): the cast was cut.
func abort() -> void:
	queue_free()


func target_body() -> Node3D:
	return _target if _target != null and is_instance_valid(_target) and _target.is_inside_tree() else null


## Fly to a body (follows it) or to a point on the land.
func retarget(body: Node3D, point: Vector3) -> void:
	_target = body
	_goal = point


func finish_flight() -> void:
	phase = Phase.SHRINKING


func caster() -> Node3D:
	return _wizard if _wizard != null and is_instance_valid(_wizard) else get_node_or_null(_caster_path) as Node3D


func _physics_process(_delta: float) -> void:
	match phase:
		Phase.CASTING:
			_cast_step()
		Phase.FLYING:
			_fly_step()
		Phase.SHRINKING:
			scale -= Vector3.ONE / (shrink_s * MatchClock.TICKS_PER_SECOND_F)
			if scale.x <= 0.0:
				queue_free()


## dragonfireCastingPosition: one turn around the wizard, climbing from his feet to `cast_height_m` over his head, growing as it goes.
func _cast_step() -> void:
	if _wizard == null or not is_instance_valid(_wizard):
		queue_free()
		return
	_tick += 1
	var p := minf(1.0, float(_tick) / float(_cast_ticks))
	var box := BodyNudge.box(_wizard)
	var top := box.end.y - _wizard.global_position.y + cast_height_m
	var radius := 0.5 * float(_cast_ticks) / MatchClock.TICKS_PER_SECOND_F * speed / TAU * (0.5 + 0.5 * p)
	var angle := TAU * p
	var offset := _wizard.global_basis * Vector3(radius * cos(angle), top * p, radius * sin(angle))
	_face(_wizard.global_position + offset - global_position)
	global_position = _wizard.global_position + offset
	scale = Vector3.ONE * maxf(p, 0.01)


## updateDragonfirePosition + changeDirectionTowards: follow the target, turn at a limited rate, never under `flying_height_m`.
func _fly_step() -> void:
	if on_arrive != null:
		on_arrive.along(self)
	var body := target_body()
	var center := BodyNudge.center(body) if body != null else _goal
	if body != null:
		_goal = center
	var to := center - global_position
	var rate := turn_rate
	if to.length_squared() < 16.0:
		rate = maxf(rate, 1.1 * speed / maxf(to.length(), 0.01))
	_direction = _turned(_direction, to.normalized(), rate / MatchClock.TICKS_PER_SECOND_F)
	var next := global_position + _direction * speed / MatchClock.TICKS_PER_SECOND_F
	var ground := GroundRay.surface_y(self, next, 1, GroundRay.wizard_rids(get_tree()), -INF)
	var low := is_finite(ground) and next.y < ground + flying_height_m
	if low:
		next.y = ground + flying_height_m
		_direction = (next - global_position).normalized()
	_face(_direction)
	var flat := Vector2(center.x - next.x, center.z - next.z).length()
	global_position = next
	if (center - next).length() < arrive_distance_m or (low and center.y < next.y and flat < 0.5):
		if on_arrive != null:
			on_arrive.arrive(self)


func _face(direction: Vector3) -> void:
	if direction.length_squared() > 0.000001:
		_direction = direction.normalized()
		var up := Vector3.UP if absf(_direction.y) < 0.99 else Vector3.RIGHT
		quaternion = Basis.looking_at(-_direction, up).get_rotation_quaternion()


static func _turned(from: Vector3, to: Vector3, max_angle: float) -> Vector3:
	var angle := from.angle_to(to)
	if angle <= max_angle:
		return to
	var axis := from.cross(to)
	if axis.length_squared() < 0.000001:
		axis = from.cross(Vector3.UP) if absf(from.y) < 0.99 else from.cross(Vector3.RIGHT)
	return from.rotated(axis.normalized(), max_angle).normalized()
