extends SpellProjectile

## Charnel Insect Swarm (sacengine castSwarm/updateSwarm, state.d:10576, 17011).
## Guided projectile with smaller hit box, higher cruise height and splash spell damage.

const _ROCK := preload("res://scenes/spells/rock_projectile.gd")

const FPS := 60.0
const FLYING_HEIGHT := 1.25
const SIZE := 0.3
const ARRIVE_DISTANCE := 0.25
## Trail puffs on every peer, by time (FxTrail): one per 2/60 s.
const TRAIL_INTERVAL_S := 2.0 / 60.0

var speed := 0.0
var acceleration := 0.0
var damage := 0.0
var damage_range := 0.0
var from_slot := 0
var velocity := Vector3.ZERO
var target_point := Vector3.ZERO
var target_path := NodePath()
var caster_path := NodePath()


func setup(data: Dictionary) -> void:
	name = str(data["name"])
	position = Vector3(float(data["x"]), float(data["y"]), float(data["z"]))
	target_point = Vector3(float(data["tx"]), float(data["ty"]), float(data["tz"]))
	target_path = NodePath(str(data.get("target", "")))
	caster_path = NodePath(str(data.get("caster", "")))
	speed = float(data["speed"])
	acceleration = float(data["acceleration"])
	damage = float(data.get("damage", 0.0))
	damage_range = float(data.get("damage_range", 0.0))
	from_slot = int(data.get("slot", 0))
	_attach_net()
	## Wrath's trail, played locally on every peer.
	FxTrail.attach(self, "wrath_trail", TRAIL_INTERVAL_S)


func _ready() -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)


func _attach_net() -> void:
	if get_node_or_null("Net"):
		return
	var net := MpReplicate.new()
	net.name = "Net"
	net.sync_properties = PackedStringArray([".:position"])
	MpAuthority.ensure_sync(self, net.sync_properties)
	add_child(net)


func _physics_process(_delta: float) -> void:
	var target_center := _target_center()
	var to_target := target_center - global_position
	velocity = _cap(velocity + to_target.normalized() * acceleration, to_target)
	var next := global_position + velocity / FPS
	var on_ground := false
	var ground := _ground_height(global_position)
	if is_finite(ground):
		var flat := Vector2(target_center.x - global_position.x, target_center.z - global_position.z).length()
		var flying_height := minf(FLYING_HEIGHT, 0.75 * flat)
		if next.y < ground + flying_height:
			var lifted := velocity
			lifted.y += (ground + flying_height - next.y) * FPS
			next = global_position + _cap(lifted, to_target) / FPS
			on_ground = true
	global_position = next
	var flat_left := Vector2(target_center.x - next.x, target_center.z - next.z).length()
	var close := (target_center - next).length() < ARRIVE_DISTANCE \
		or (on_ground and target_center.y < next.y and flat_left < ARRIVE_DISTANCE)
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * SIZE
	var hit := _ROCK.pick_body(self, shape, global_position, _caster(), from_slot, true)
	if hit:
		_explode(hit)
	elif global_position.y < _ground_height(global_position):
		_explode(null)
	elif close:
		_explode(_target())


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
	target_point = _ROCK.body_center(target)
	return target_point


func _ground_height(at: Vector3) -> float:
	return GroundRay.surface_y(self, at, 1, GroundRay.wizard_rids(get_tree()), -INF)


func _explode(direct: Node3D) -> void:
	var center := global_position
	if direct and is_instance_valid(direct) and _ROCK.is_live_body(direct):
		SplashDamage.hurt(direct, damage, from_slot)
	else:
		direct = null
	SplashDamage.deal(get_tree(), center, damage, damage_range, direct, from_slot)
	FxBus.broadcast("wrath_explosion1", center)
	FxBus.broadcast("wrath_explosion2", center)
	set_physics_process(false)
	set_process(false)
	queue_free()
