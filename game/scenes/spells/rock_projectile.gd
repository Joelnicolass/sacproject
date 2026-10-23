extends SpellProjectile

## James' Rock (sacengine state.d:10541-10561, 16707-16855). While the wizard casts it rises
## out of the ground ahead of him (rockCastingPosition, buried 1 m). Then it flies at its
## target, homing on the target's center: each frame the velocity gains `acceleration` toward
## it, capped at `speed`, floating up to 7 m over the ground. It bursts on the first body it
## touches (enemies first), on the ground, or at the target, and deals its damage to the body
## it hit as direct spell damage (rockExplosion, state.d:16784).
## The server (or solo) moves it; clients get the position and play the trail locally.

const _HEALTH := preload("res://scenes/components/health.gd")

## sacengine rockWarmupTime = updateFPS / 4.
const WARMUP_FRAMES := 15
const FLOAT_HEIGHT := 7.0
const FPS := 60.0
## sacengine rockSize 2: hit box of ±1 m.
const HALF_SIZE := 1.0
const ARRIVE_DISTANCE := 0.25
## sacengine rockBuryDepth.
const BURY_DEPTH := 1.0
## sacengine rockCastingPosition: 1.5 m past the front of the caster's hit box.
const CAST_AHEAD := 1.5
## MODL.WAD rock.MRMM (tools/import/import_props.py), drawn at scale 1.
const MODEL := "rock"
## sacengine makeRock: spins 2π·[0.2, 0.8] rad/s around a random axis.
const SPIN_MIN := 0.2
const SPIN_MAX := 0.8
## Trail puffs (animateRock) on every peer, by time (FxTrail): one per 2/60 s.
const TRAIL_FX := "rock_trail"
const TRAIL_INTERVAL_S := 2.0 / 60.0

@export var rock_color := Color(0.42, 0.4, 0.34)

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


func setup(data: Dictionary) -> void:
	name = str(data["name"])
	position = Vector3(float(data["x"]), float(data["y"]), float(data["z"]))
	target_point = Vector3(float(data["tx"]), float(data["ty"]), float(data["tz"]))
	target_path = NodePath(str(data.get("target", "")))
	caster_path = NodePath(str(data.get("caster", "")))
	speed = float(data["speed"])
	acceleration = float(data["acceleration"])
	damage = float(data.get("damage", 0.0))
	from_slot = int(data.get("slot", 0))
	cast_frames = int(data.get("cast_frames", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	_spin_axis = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
	_spin_rate = TAU * rng.randf_range(SPIN_MIN, SPIN_MAX)
	_add_visual()
	_attach_net()
	_trail = FxTrail.attach(self, TRAIL_FX, TRAIL_INTERVAL_S)


func _add_visual() -> void:
	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = BodyCatalog.mesh(MODEL)
	if visual.mesh == null:
		var ball := SphereMesh.new()
		ball.radius = HALF_SIZE
		ball.height = HALF_SIZE * 2.0
		visual.mesh = ball
		var mat := StandardMaterial3D.new()
		mat.albedo_color = rock_color
		mat.roughness = 1.0
		visual.material_override = mat
	add_child(visual)


func _ready() -> void:
	if MpKit.is_networked() and not MpKit.is_server():
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
	var mesh := get_node_or_null("Mesh") as Node3D
	if _trail:
		_trail.emitting = mesh != null and flying
	if mesh == null or not flying:
		return
	mesh.rotate(_spin_axis, _spin_rate * delta)


func _physics_process(_delta: float) -> void:
	if not flying:
		_cast_step()
		return
	_fly_step()


## sacengine updateRockCasting: glued ahead of the caster, rising out of the ground.
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
	FxBus.broadcast("rock_emerge", global_position)
	FxBus.broadcast("rock_dust", global_position)


## sacengine rockCastingPosition: ahead of the caster, past the front of its hit box.
static func cast_position(caster: Node3D) -> Vector3:
	var ahead := Vector3(0.0, 0.0, 1.0)
	if caster.has_method("facing_flat"):  # dynamic: unit, wizard and doctor bodies all face
		ahead = caster.call("facing_flat")
	var model := str(caster.get("model")) if "model" in caster else ""
	var front := float(BodyCatalog.info(model).get("reach", 0.5))
	return caster.global_position + ahead * (front + CAST_AHEAD)


func _fly_step() -> void:
	var target_center := _target_center()
	var distance := target_center - global_position
	velocity = _cap(velocity + distance.normalized() * acceleration, distance)
	var next := global_position + velocity / FPS
	var ground := _ground_height(global_position)
	var flat := Vector2(distance.x, distance.z).length()
	var floating := FLOAT_HEIGHT if _frame < WARMUP_FRAMES else minf(FLOAT_HEIGHT, 0.75 * flat)
	if next.y < ground + floating:
		var lifted := velocity
		lifted.y += (ground + floating - next.y) * FPS
		next = global_position + _cap(lifted, distance) / FPS
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
	if v.length() > FPS * distance.length():
		v = v.normalized() * distance.length() * FPS
	return v


func _target() -> Node3D:
	return get_node_or_null(target_path) as Node3D if not target_path.is_empty() else null


func _caster() -> Node3D:
	return get_node_or_null(caster_path) as Node3D if not caster_path.is_empty() else null


func _target_center() -> Vector3:
	var target := _target()
	if target == null:
		return target_point
	target_point = body_center(target)
	return target_point


static func body_center(body: Node3D) -> Vector3:
	var col := body.get_node_or_null("Collision") as Node3D
	return col.global_position if col else body.global_position


func _ground_height(at: Vector3) -> float:
	return GroundRay.surface_y(self, at, 1, GroundRay.wizard_rids(get_tree()), -INF)


## sacengine rockCollisionTarget / collisionTarget (state.d:16431, 16777): every living body in
## the ±1 m box except the caster; enemies first, then neutrals, then allies; closest wins.
func _collision_target() -> Node3D:
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * HALF_SIZE * 2.0
	return pick_body(self, shape, global_position, _caster(), from_slot, false)


## Shared by the spell projectiles. `skip_own_side` drops bodies of `slot` (wrathCollisionTarget).
static func pick_body(from: Node3D, shape: Shape3D, at: Vector3, skip: Node, slot: int, skip_own_side: bool) -> Node3D:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), at)
	query.collision_mask = 3
	var best: Node3D = null
	var best_key := Vector2(INF, INF)
	for hit in from.get_world_3d().direct_space_state.intersect_shape(query, 16):
		var body := hit.get("collider") as Node3D
		if body == null or body == skip or not is_live_body(body):
			continue
		var other := int(body.get("owner_slot")) if "owner_slot" in body else 0
		if skip_own_side and other == slot:
			continue
		var rank := 2.0 if other == slot else (1.0 if other <= 0 or slot <= 0 else 0.0)
		var key := Vector2(rank, at.distance_squared_to(body_center(body)))
		if key < best_key:
			best_key = key
			best = body
	return best


static func is_live_body(body: Node) -> bool:
	if not Attackable.is_body(body):
		return false
	if body.has_method("is_targetable") and not body.call("is_targetable"):  # dynamic: unit, wizard, structure and doctor bodies answer it
		return false
	var health := body.get_node_or_null("Health") as Health
	return health != null and not health.is_dead()


## sacengine rockExplosion: dealSpellDamage(target, …, DamageMod.none) = direct spell damage.
func _burst(target: Node3D) -> void:
	if target and is_instance_valid(target) and is_live_body(target):
		var health := target.get_node("Health") as Health
		var taken := health.damage_typed(damage, _HEALTH.DIRECT_SPELL, from_slot)
		report(target, taken, _HEALTH.DIRECT_SPELL)
	FxBus.broadcast("rock", global_position)
	FxBus.broadcast("dirt", global_position)
	set_physics_process(false)
	queue_free()


static func report(target: Node3D, taken: float, kind: StringName) -> void:
	var health := target.get_node("Health") as Health
	## F155: the bench tells apart bodies of the same kind.
	var who := str(target.call("display_name")) if target.has_method("display_name") and not DebugLog.on(&"oil") else str(target.name)  # dynamic: unit, wizard and doctor bodies name themselves
	var line := "dano %s %d vida %d" % [who, roundi(taken), roundi(health.current)]
	if taken <= 0.0 and health.resistance(kind) <= 0.0:
		line += " (inmune)"
	print(line)
