class_name RockProjectile
extends SpellProjectile

## James' Rock. While the wizard casts it rises
## out of the ground ahead of him (buried 1 m). Then it flies at its
## target, homing on the target's center: each frame the velocity gains `acceleration` toward
## it, capped at `speed`, floating up to 7 m over the ground. It bursts on the first body it
## touches (enemies first), on the ground, or at the target, and deals its damage to the body
## it hit as direct spell damage.
## The server (or solo) moves it; clients get the position and play the trail locally.

const _HEALTH := preload("res://scenes/components/health.gd")

## Warm-up time = a quarter of a second.
const WARMUP_FRAMES := 15
const FLOAT_HEIGHT := 7.0
const ARRIVE_DISTANCE := 0.25
## Depth the rock starts buried.
const BURY_DEPTH := 1.0
## 1.5 m past the front of the caster's hit box.
const CAST_AHEAD := 1.5
## Spins 2π·[0.2, 0.8] rad/s around a random axis.
const SPIN_MIN := 0.2
const SPIN_MAX := 0.8
## Trail puffs on every peer, by time (FxTrail): one per 2/60 s.
const TRAIL_INTERVAL_S := 2.0 / 60.0

## Puffed behind it while it flies (FxTrail, one per TRAIL_INTERVAL_S). Empty = no trail.
@export var trail: ParticleType
## Bursts where it leaves the ground, on every peer.
@export var emerge: Array[ParticleType] = []
## Bursts where it breaks, on every peer.
@export var explosion: Array[ParticleType] = []
## The crack it leaves where it bursts (spells/marks/rock_mark.tscn), played on every peer.
@export var ground_mark: PackedScene
## The box that touches the bodies it bursts on (±1 m), centered on the rock.
@export var hit_box: Shape3D

var speed := 0.0
var acceleration := 0.0
var damage := 0.0
var from_slot := 0
var cast_frames := 0
var velocity := Vector3.ZERO
var target_point := Vector3.ZERO
var target_path := NodePath()
var caster_path := NodePath()
## False while the wizard is still casting it.
var flying := false
var _frame := 0
var _cast_frame := 0
var _spin_axis := Vector3.UP
var _spin_rate := 0.0
var _trail: FxTrail
var _query: PhysicsShapeQueryParameters3D

## The rock, drawn at scale 1 (the mesh of the `Mesh` node, scenes/props/meshes/rock.res).
@onready var _mesh: MeshInstance3D = %Mesh


func setup(data: Dictionary) -> void:
	var launch := ProjectileLaunch.from_dict(data)
	name = launch.name
	position = launch.from
	target_point = launch.aim
	target_path = launch.target
	caster_path = launch.caster
	speed = launch.speed_m_s
	acceleration = launch.acceleration_m_s2
	damage = launch.damage
	from_slot = launch.slot
	cast_frames = launch.cast_ticks
	if hit_box == null:
		push_error("%s: `hit_box` is empty, it hits no body." % scene_file_path)
	_query = ProjectileTargets.query_for(hit_box)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	_spin_axis = (
		Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		. normalized()
	)
	_spin_rate = TAU * rng.randf_range(SPIN_MIN, SPIN_MAX)
	_attach_net()
	_trail = FxTrail.attach(self, trail, TRAIL_INTERVAL_S)


func _ready() -> void:
	if not is_multiplayer_authority():
		set_physics_process(false)


## Before entering the tree: the spawn packet lists the synchronizers that exist when it is sent,
## and a late joiner's copy must already have them.
func _attach_net() -> void:
	if get_node_or_null("Net"):
		return
	var net := MpReplicate.new()
	net.name = "Net"
	net.sync_properties = PackedStringArray([".:position", ".:flying"])
	MpAuthority.ensure_sync(self, net.sync_properties)
	add_child(net)


func _process(delta: float) -> void:
	if _trail:
		_trail.emitting = flying
	if not flying:
		return
	_mesh.rotate(_spin_axis, _spin_rate * delta)


func _physics_process(_delta: float) -> void:
	if not flying:
		_cast_step()
		return
	_fly_step()


## Glued ahead of the caster, rising out of the ground.
func _cast_step() -> void:
	var caster := _caster()
	if caster:
		var at := cast_position(caster)
		at.y = _ground_height(at) - BURY_DEPTH
		at.y += BURY_DEPTH * minf(1.0, float(_cast_frame) / float(maxi(cast_frames, 1)))
		global_position = at
	_cast_frame += 1
	if _cast_frame < cast_frames:
		return
	global_position.y = maxf(global_position.y, _ground_height(global_position))
	flying = true
	for type in emerge:
		FxBus.broadcast(type, global_position)


## Ahead of the caster, past the front of its hit box.
static func cast_position(caster: Node3D) -> Vector3:
	var ahead := Vector3(0.0, 0.0, 1.0)
	if caster is GameBody:
		ahead = (caster as GameBody).facing_flat()
	var front := _reach_mm(BodyFacts.of_body(caster).reach_m)
	return caster.global_position + ahead * (front + CAST_AHEAD)


## The reach as the millimetre double the rules have always read: the body scene keeps it in 32 bits and every body measure has at
## most three decimals, so dividing the rounded millimetres gives the same double (the cast position stays bit for bit).
static func _reach_mm(reach_m: float) -> float:
	return roundi(reach_m * 1000.0) / 1000.0


func _fly_step() -> void:
	var target_center := _target_center()
	var distance := target_center - global_position
	velocity = _cap(velocity + distance.normalized() * acceleration, distance)
	var next := global_position + velocity / MatchClock.TICKS_PER_SECOND_F
	var ground := _ground_height(global_position)
	var flat := Vector2(distance.x, distance.z).length()
	var floating := FLOAT_HEIGHT if _frame < WARMUP_FRAMES else minf(FLOAT_HEIGHT, 0.75 * flat)
	if next.y < ground + floating:
		var lifted := velocity
		lifted.y += (ground + floating - next.y) * MatchClock.TICKS_PER_SECOND_F
		next = global_position + _cap(lifted, distance) / MatchClock.TICKS_PER_SECOND_F
	global_position = next
	_frame += 1
	if _frame < WARMUP_FRAMES:
		return
	var hit := _collision_target()
	if hit:
		_burst(hit)
	elif global_position.y < _ground_height(global_position):
		_burst(null)
	elif distance.length() < ARRIVE_DISTANCE:
		_burst(_target())


func _cap(v: Vector3, distance: Vector3) -> Vector3:
	if v.length() > speed:
		v = v.normalized() * speed
	if v.length() > MatchClock.TICKS_PER_SECOND_F * distance.length():
		v = v.normalized() * distance.length() * MatchClock.TICKS_PER_SECOND_F
	return v


func _target() -> Node3D:
	return get_node_or_null(target_path) as Node3D if not target_path.is_empty() else null


func _caster() -> Node3D:
	return get_node_or_null(caster_path) as Node3D if not caster_path.is_empty() else null


func _target_center() -> Vector3:
	var target := _target()
	if target == null:
		return target_point
	target_point = ProjectileTargets.body_center(target)
	return target_point


func _ground_height(at: Vector3) -> float:
	return GroundRay.surface_y(self, at, 1, GroundRay.wizard_rids(get_tree()), -INF)


## Every living body in
## the ±1 m box except the caster; enemies first, then neutrals, then allies; closest wins.
func _collision_target() -> Node3D:
	return ProjectileTargets.pick_body(self, _query, global_position, _caster(), from_slot, false)


## Direct spell damage with no DamageMod.
func _burst(target: Node3D) -> void:
	if target and is_instance_valid(target) and ProjectileTargets.is_live_body(target):
		var health := target.get_node("Health") as Health
		var taken := health.damage_typed(damage, _HEALTH.DIRECT_SPELL, from_slot)
		ProjectileTargets.report(target, taken, _HEALTH.DIRECT_SPELL)
	for type in explosion:
		FxBus.broadcast(type, global_position)
	ScarMark.broadcast(ground_mark, global_position)
	set_physics_process(false)
	queue_free()
