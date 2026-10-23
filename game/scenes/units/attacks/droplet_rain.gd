class_name DropletRain
extends Node3D

## F148 (RFC-030 030h3): every falling AbominationDroplet of the world, in one pool (packed arrays, no node per drop).
## Server (or solo) only; clients see the drops as the shot's trail (ShotLook.trail_fx), drawn locally by FxTrail.
## ShotDropper adds them. Each physics tick, for each drop (updateAbominationDroplet, state.d:24488-24505):
## - position += velocity/fps, then velocity.z −= gravity/fps (10 m/s², starting at rest);
## - collision: the first live body whose collider touches the drop's box (abominationDropletSize 0.25 m,
##   state.d:24481-24487). The filter is only isProjectileObstacle: any side, the shooter too. Several: a foe of the
##   drop's side first, then neutral, then its own (collisionTarget's rank by stance, state.d:16442-16447 and 30033),
##   then the closest. It deals `amount` as direct ranged damage (dealRangedDamage(target, amount, …, DamageMod.none),
##   state.d:24494) through Health.damage_typed, so resistance, friendly fire (F139) and passives apply; the drop ends;
## - below the ground it ends without damage (state.d:24497-24498, «TODO: scar»). Off the map (no ground under it,
##   the fallLimit branch) it ends after `max_fall_ticks`.
## The drop falls straight down (velocity has only a vertical part), so the ground under it is measured once, when
## it is added: one shape query per drop per tick, no ray.

const _HEALTH := preload("res://scenes/components/health.gd")
const _ROCK := preload("res://scenes/spells/rock_projectile.gd")
const GROUP := &"droplet_rain"

## Bodies (creatures, wizards, structures) the drop can touch.
@export_flags_3d_physics var body_mask := 3
## Layers whose top is the ground a drop ends on (terrain, map buildings); wizards are left out.
@export_flags_3d_physics var ground_mask := 1
## A drop with no ground under it (off the map) ends after this many ticks.
@export var max_fall_ticks := 600
## Most drops alive at once; past it a new drop is not added (counted in `over_cap`).
@export var max_drops := 1024
## Prints one `gota <body> <taken> vida <current>` line per hit (bench and debug scenes read it).
## Debug log (hits and the summary at exit). Off in the product; debug/ai/ai_match.gd turns it on.
@export var log_hits := false

## Totals of the match, for the bench and the debug scenes.
var added := 0
var hits := 0
var landed := 0
var over_cap := 0
## Most drops alive in one tick, and the cost of the tick that had them.
var peak := 0
var peak_us := 0
## Slowest tick of this node, ticks that had any drop and their summed cost.
var max_us := 0
var busy_ticks := 0
var busy_us := 0

var _pos := PackedVector3Array()
var _vy := PackedFloat32Array()
var _ground := PackedFloat32Array()
var _amount := PackedFloat32Array()
var _gravity := PackedFloat32Array()
var _size := PackedFloat32Array()
var _slot := PackedInt32Array()
var _age := PackedInt32Array()
var _shapes: Dictionary = {}
var _query := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	add_to_group(GROUP)
	_query.collision_mask = body_mask
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)


## How many drops are falling now.
func active() -> int:
	return _pos.size()


## A drop at rest at `at` (ShotDropper.drop).
func add(at: Vector3, amount: float, from_slot: int, gravity: float, size: float) -> void:
	if _pos.size() >= max_drops:
		over_cap += 1
		return
	added += 1
	_pos.append(at)
	_vy.append(0.0)
	_ground.append(_ground_height(at))
	_amount.append(amount)
	_gravity.append(gravity)
	_size.append(size)
	_slot.append(from_slot)
	_age.append(0)


func _physics_process(delta: float) -> void:
	var count := _pos.size()
	if count == 0:
		return
	var start := Time.get_ticks_usec()
	var space := get_world_3d().direct_space_state
	var i := 0
	while i < _pos.size():
		var at := _pos[i] + Vector3(0.0, _vy[i] * delta, 0.0)
		_pos[i] = at
		_vy[i] -= _gravity[i] * delta
		_age[i] += 1
		var target := _target_at(space, at, _size[i], _slot[i])
		if target:
			_hit(target, _amount[i], _slot[i])
			_remove(i)
			continue
		if at.y < _ground[i] or (_ground[i] == -INF and _age[i] > max_fall_ticks):
			landed += 1
			_remove(i)
			continue
		i += 1
	var spent := Time.get_ticks_usec() - start
	busy_ticks += 1
	busy_us += spent
	max_us = maxi(max_us, spent)
	if count >= peak:
		peak = count
		peak_us = spent


## The body the drop's box touches, by collisionTarget's order (foe, neutral, own side; then the closest; then the name,
## so the pick does not depend on the order the physics server lists them in).
func _target_at(space: PhysicsDirectSpaceState3D, at: Vector3, size: float, from_slot: int) -> Node3D:
	_query.shape = _shape(size)
	_query.transform = Transform3D(Basis(), at)
	var best: Node3D = null
	var best_rank := 0
	var best_d := INF
	for found in space.intersect_shape(_query, 8):
		var body := found.get("collider") as Node3D
		if body == null or not _ROCK.is_live_body(body):
			continue
		var rank := _rank(body, from_slot)
		var d := at.distance_squared_to(body.global_position)
		if best == null or rank < best_rank or (rank == best_rank and (d < best_d or (d == best_d and str(body.name) < str(best.name)))):
			best = body
			best_rank = rank
			best_d = d
	return best


static func _rank(body: Node3D, from_slot: int) -> int:
	var side := int(body.get("owner_slot")) if "owner_slot" in body else 0
	if side <= 0 or from_slot <= 0:
		return 1
	return 2 if side == from_slot else 0


func _hit(target: Node3D, amount: float, from_slot: int) -> void:
	hits += 1
	var health := target.get_node("Health") as Health
	var taken := health.damage_typed(amount, _HEALTH.DIRECT_RANGED, from_slot)
	if log_hits:
		print("gota %s %.2f vida %.2f" % [ShotImpact.who(target), taken, float(health.get("current"))])


func _remove(i: int) -> void:
	var last := _pos.size() - 1
	if i != last:
		_pos[i] = _pos[last]
		_vy[i] = _vy[last]
		_ground[i] = _ground[last]
		_amount[i] = _amount[last]
		_gravity[i] = _gravity[last]
		_size[i] = _size[last]
		_slot[i] = _slot[last]
		_age[i] = _age[last]
	_pos.resize(last)
	_vy.resize(last)
	_ground.resize(last)
	_amount.resize(last)
	_gravity.resize(last)
	_size.resize(last)
	_slot.resize(last)
	_age.resize(last)


func _shape(size: float) -> BoxShape3D:
	var shape: BoxShape3D = _shapes.get(size)
	if shape == null:
		shape = BoxShape3D.new()
		shape.size = Vector3.ONE * size
		_shapes[size] = shape
	return shape


## The ground under `at` (RangedShot.ground_height: terrain and buildings, wizards left out), or -INF off the map.
func _ground_height(at: Vector3) -> float:
	return GroundRay.surface_y(self, at, ground_mask, GroundRay.wizard_rids(get_tree()), -INF)


func _exit_tree() -> void:
	if log_hits and added > 0:
		print("lluvia gotas %d golpes %d suelo %d fuera_tope %d pico %d (%.3f ms) tick_max %.3f ms medio %.3f ms en %d ticks" % [
			added, hits, landed, over_cap, peak, peak_us / 1000.0, max_us / 1000.0,
			(float(busy_us) / busy_ticks / 1000.0) if busy_ticks > 0 else 0.0, busy_ticks])
