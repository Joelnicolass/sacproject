extends SpellProjectile

## Persephone's Wrath. A ball of light leaves the
## caster's hands and flies at its target (accelerateTowards, 0.5 m over the ground). It
## bursts on the first body of another side it touches, under the ground, or at the target.
## The body hit takes the full amount as splash spell damage; every other body within
## damage_range takes amount·(1 − distance/range), also as splash spell damage.
## The server (or solo) moves it; clients get the position and play the trail locally.
## Ref: sacengine state.d:10493-10506, 16386-16581; wrathExplosion, state.d:16496-16501; dealDamage, state.d:9053-9088

const _ROCK := preload("res://scenes/spells/rock_projectile.gd")

const FPS := 60.0
## Flying height.
## Ref: sacengine wrathFlyingHeight
const FLYING_HEIGHT := 0.5
## Hit box of ±0.05 m.
## Ref: sacengine wrathSize 0.1
const SIZE := 0.1
const ARRIVE_DISTANCE := 0.25
## Trail puffs on every peer, by time (FxTrail): one per 2/60 s.
const TRAIL_INTERVAL_S := 2.0 / 60.0

## Puffed behind it while it flies: the ball is only this trail. Empty = no trail.
@export var trail: ParticleType
## Bursts where it breaks, on every peer.
@export var explosion: Array[ParticleType] = []

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
	## The ball is only particles, its trail.
	## Ref: sacengine animateWrath
	FxTrail.attach(self, trail, TRAIL_INTERVAL_S)


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
	net.sync_properties = PackedStringArray([".:position"])
	MpAuthority.ensure_sync(self, net.sync_properties)
	add_child(net)


## Flight with accelerateTowards. The target's
## motion is not predicted: it aims at the current center.
## Ref: sacengine updateWrath (flying); state.d:16528-16562; sacengine predictCenter
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
	var hit := _ROCK.pick_body(self, shape, global_position, null, from_slot, true)
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


func _target_center() -> Vector3:
	var target := _target()
	if target == null:
		return target_point
	target_point = _ROCK.body_center(target)
	return target_point


func _ground_height(at: Vector3) -> float:
	return GroundRay.surface_y(self, at, 1, GroundRay.wizard_rids(get_tree()), -INF)


## The direct hit gets the whole amount (DamageMod.splash), then
## dealSplashSpellDamageAt hurts the rest by the distance to their hit box.
## Ref: sacengine wrathExplosion
func _explode(direct: Node3D) -> void:
	var center := global_position
	if direct and is_instance_valid(direct) and _ROCK.is_live_body(direct):
		SplashDamage.hurt(direct, damage, from_slot)
	else:
		direct = null
	SplashDamage.deal(get_tree(), center, damage, damage_range, direct, from_slot)
	for type in explosion:
		FxBus.broadcast(type, center)
	set_physics_process(false)
	set_process(false)
	queue_free()
