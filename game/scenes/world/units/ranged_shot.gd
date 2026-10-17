class_name RangedShot
extends Node3D

## A creature's ranged shot. sacengine updateEarthflingProjectile (state.d:23178-23198): each frame
## position += velocity/fps and, for ballistic shots, velocity.z −= fallingAcceleration/fps. It bursts
## on the first body in its hit box that is the intended target or not of the shooter's side
## (earthflingProjectileCollisionTarget, state.d:23145), or under the ground, and deals the ability's
## amount as direct ranged damage (earthflingProjectileExplosion, state.d:23152-23154). Straight shots
## (getShotDirection) fly their ability range and vanish.
## The server (or solo) moves it; clients get the position and play the trail locally.
## F119: a ShotLook with an `impact` scene (ShotImpact) decides the damage where it bursts instead (splash, 030h).
## F136: ShotLook.hits_allies turns the side filter around (the Scarab's web) and burst_at_range_end bursts it where its range ends.
## F148: a ShotLook with an `in_flight` scene (ShotInFlight) acts on every tick of the flight: the Abomination's droplets
## (ShotDropper, 030h3); F149: the Silverback's breath (FrostWave), whose ShotLook.collides is off: it touches neither a
## body nor the ground and flies its whole range.
## F151: an in_flight that holds the shot's height (GroundHug, ShotInFlight.holds_height) takes the ground check away: the
## Rhinok's shot ends on a body or at the end of its range only.

const TRAIL_FPS := 60.0

var damage := 0.0
var from_slot := 0
var gravity := 0.0
var max_distance := INF
var velocity := Vector3.ZERO
var target_path := NodePath()
var shooter_path := NodePath()
var look: ShotLook
## The shot's SPEL (ranges for its impact); null when GameData has no such tag.
var ability: AbilityType

## F125: the packet it was spawned with (RangedAttack._fire). Its ShotInFlight reads what the flight needs (ShotSplit:
## volley_index, aim_distance). Read only.
var spawn_data: Dictionary = {}

var _traveled := 0.0
var _spin_axis := Vector3.UP
var _spin_rate := 0.0
var _in_flight: ShotInFlight


func setup(data: Dictionary) -> void:
	name = str(data["name"])
	spawn_data = data
	position = Vector3(float(data["x"]), float(data["y"]), float(data["z"]))
	velocity = Vector3(float(data["vx"]), float(data["vy"]), float(data["vz"]))
	damage = float(data.get("damage", 0.0))
	from_slot = int(data.get("slot", 0))
	gravity = float(data.get("gravity", 0.0))
	max_distance = float(data.get("max_distance", INF))
	target_path = NodePath(str(data.get("target", "")))
	shooter_path = NodePath(str(data.get("shooter", "")))
	look = ShotLook.for_tag(str(data.get("tag", "")))
	ability = GameData.ability(str(data.get("tag", "")))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	_spin_axis = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
	_spin_rate = TAU * rng.randf_range(look.spin_min, look.spin_max)
	_add_visual()
	_attach_net()
	_add_in_flight()
	## ShotLook.trail_every counts 60 fps frames; the trail now goes by time (FxTrail, RFC-029 029b).
	FxTrail.attach(self, look.trail_fx, float(maxi(look.trail_every, 1)) / TRAIL_FPS)


func _add_visual() -> void:
	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = BodyLibrary.mesh(look.model) if not look.model.is_empty() else null
	if visual.mesh == null:
		var ball := SphereMesh.new()
		ball.radius = look.fallback_radius
		ball.height = look.fallback_radius * 2.0
		visual.mesh = ball
		var mat := StandardMaterial3D.new()
		mat.albedo_color = look.fallback_color
		mat.roughness = 1.0
		visual.material_override = mat
	else:
		visual.scale = Vector3.ONE * look.model_scale
	add_child(visual)


## Server (or solo) only, like the impact: what it does in flight is simulation (ShotLook.in_flight).
func _add_in_flight() -> void:
	if look.in_flight == null or (MpKit.is_networked() and not MpKit.is_server()):
		return
	var node := look.in_flight.instantiate()
	_in_flight = node as ShotInFlight
	if _in_flight:
		add_child(_in_flight)
	else:
		node.free()
		push_warning("RangedShot: el in_flight de %s no es un ShotInFlight." % name)


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
	net.sync_properties = PackedStringArray([".:position"])
	MpAuthority.ensure_sync(self, net.sync_properties)
	add_child(net)


func _process(delta: float) -> void:
	var mesh := get_node_or_null("Mesh") as Node3D
	if mesh and _spin_rate > 0.0:
		mesh.rotate(_spin_axis, _spin_rate * delta)


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	var from := global_position
	global_position += step
	velocity.y -= gravity * delta
	_traveled += step.length()
	if _in_flight:
		_in_flight.fly(self, global_position)
	if not look.collides:
		if _traveled >= max_distance:
			set_physics_process(false)
			queue_free()
		return
	var hit := _collision_target()
	if hit == null and look.sweep:
		hit = _swept_target(from, global_position)
	if hit:
		_burst(hit)
	elif not (_in_flight and _in_flight.holds_height()) and global_position.y < ground_height(global_position):
		_burst(null)
	elif _traveled >= max_distance:
		if look.burst_at_range_end:
			_burst(null)
			return
		set_physics_process(false)
		queue_free()


## The live body not of this shot's side that its box touches now (a coordinator that moves the shot asks it).
func touching() -> Node3D:
	return _collision_target()


func _collision_target() -> Node3D:
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * look.hit_size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 3
	var intended := get_node_or_null(target_path) if not target_path.is_empty() else null
	var shooter := get_node_or_null(shooter_path) if not shooter_path.is_empty() else null
	var best: Node3D = null
	var best_d := INF
	for found in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var body := found.get("collider") as Node3D
		if not _can_hit(body, intended, shooter):
			continue
		var d := global_position.distance_squared_to(body.global_position)
		if d < best_d:
			best_d = d
			best = body
	return best


## The first body the shot may hit on the segment `from` → `to` (ShotLook.sweep), or null.
func _swept_target(from: Vector3, to: Vector3) -> Node3D:
	var intended := get_node_or_null(target_path) if not target_path.is_empty() else null
	var shooter := get_node_or_null(shooter_path) if not shooter_path.is_empty() else null
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 3
	var skip: Array[RID] = []
	for _try in 8:
		query.exclude = skip
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return null
		var body := hit.get("collider") as Node3D
		if _can_hit(body, intended, shooter):
			return body
		var object := hit.get("collider") as CollisionObject3D
		if object == null:
			return null
		skip.append(object.get_rid())
	return null


## earthflingProjectileCollisionTarget / scarabProjectileCollisionTarget: a live body, not the shooter, that is the
## intended target or (ShotLook.hits_allies) of the shooter's side, else not of it.
func _can_hit(body: Node3D, intended: Node, shooter: Node) -> bool:
	if body == null or body == shooter or not _is_live_body(body):
		return false
	var side := int(body.get("owner_slot")) if "owner_slot" in body else 0
	return body == intended or from_slot <= 0 or (side == from_slot) == look.hits_allies


static func _is_live_body(body: Node) -> bool:
	if not Attackable.is_body(body):
		return false
	if body.has_method("is_targetable") and not body.call("is_targetable"):
		return false
	var health := body.get_node_or_null("Health")
	return health != null and not health.call("is_dead")


## sacengine getHeight: the top of the land or of a building (structures, altars, manafounts: layer 1) under `at`, wizards
## left out; -INF off the map. The ground check of the flight, and GroundHug's height (F151).
func ground_height(at: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 500.0, at + Vector3.DOWN * 500.0)
	query.collision_mask = 1
	var skip: Array[RID] = []
	for body in get_tree().get_nodes_in_group("wizard"):
		if body is CollisionObject3D:
			skip.append((body as CollisionObject3D).get_rid())
	query.exclude = skip
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else -INF


## F151: the shot flew its whole range (sacengine remainingDistance <= 0). SpikeImpact asks it before it hurts the target.
func range_spent() -> bool:
	return _traveled >= max_distance


## Server (or solo) only: _physics_process is off on clients.
func _burst(target: Node3D) -> void:
	ShotImpact.land(self, look, target, global_position, ability)
	set_physics_process(false)
	queue_free()
