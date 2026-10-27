class_name HaloOfEarth
extends SpellLaunch

## F127 (RFC-030 030p-a): the Rhinok's Halo of Earth (HRba). sacengine haloOfEarth (state.d:13232-13236) adds the effect at
## once; updateHaloOfEarth (19284-19321) runs it from the next tick: while the Rhinok can carry it (canCarryHaloOfEarth,
## 202-209) it makes rocks until there are 6, and when it cannot it blows up the free ones (despawnHaloOfEarth, 19272-19282);
## it ends when every rock it made is gone. This node is that coordinator and simulates the 6 rocks; each rock's body is a
## RangedShot of the shot container (ShotLook halo_rock: collides off), which only draws it and replicates its position.
## Server (or solo) only: a client never gets this node (HaloOfEarthAbility adds it on the server). Priority −1: it moves the
## rocks before the bodies move, like Protector.
##
## Per rock and tick (updateHaloRock, 19212-19270; `isCasting` is false for an ability):
## - free: Hermite interpolation (cintp2, util.d:554-560) between points of a ball of `orbit_radius` around the center
##   (the top of the Rhinok's box + `orbit_height`), `orbit_speed` per second; it is born buried inside the Rhinok's box
##   scaled by `spawn_box_scale`, so it rises into the orbit.
## - with a target: velocity += acceleration toward the target's center, capped at the SPEL's speed and at 60 · distance;
##   it blows up on the target when the distance (before the step) is under `arrive_distance`.
## - then, whatever it does: it blows up on the first live body not of its side its `ShotLook.hit_size` box touches, on the
##   land from `ground_grace_s` of life, and at `life_s` (the SPEL duration, 35 s) with no target.
## - free ones look for a target (closestNonAllyInRange, 28825): the closest non-ally creature or wizard within
##   effectRange (50 m), alive, targetable, in sight, that no other rock chases.
## Blowing up = the SPEL's amount as direct spell damage to the body it hit (haloRockExplosion, 19076-19100).
##
## RFC-061e: the wizard's Halo of Earth (olah) is the same node. LaunchAction makes it when the cast starts (`begin_cast`: the numbers
## come from the SpellType): the rocks come out staggered while the wizard casts, floor((progress + 0.1) × 6) of them by the share of the
## casting that has gone, and only orbit until `release` (no target, no hit, no ground, no clock); `abort` blows the free ones up.
##
## Divergences (declared): the line of sight is a ray to the target's center (sacengine: a box); an ally is the same slot;
## the rocks use MatchSeed's stream, not the engine's; the dust trail is always there; no screen shake, no sound, no
## particles of its own (the look's FxBus types); a rock that blows up does not make the rock after it move twice in the
## same tick (the swap of 19311-19313); buildings without Health do not stop a rock.



const GROUP := &"halo_of_earth"

## The shot container's spawner (group `shot_spawner`): the rocks are its shots. The ability that adds this node hands it over.
@export var spawner: Node
## A rock's look (data/shots/halo_rock.tscn): its mesh, hit box and bursts.
@export var look: PackedScene
@export_range(1, 12) var num_rocks := 6
## The Rhinok's box (BodyNudge.box) is scaled by this to place a newborn rock (haloRockSpawnPosition: 1.25 for an ability,
## 2.5 for the spell).
@export var spawn_box_scale := 1.25
## Meters a newborn rock is buried under the land (haloRockBuryDepth).
@export var bury_depth := 0.25
## Meters over the top of the Rhinok's box where the orbit is centered (HaloRock.centerHeight).
@export var orbit_height := 3.0
@export var orbit_radius := 2.0
## Hermite tangent length (HaloRock.speedRadius).
@export var orbit_tangent := 3.0
## Orbit points per second (HaloRock.interpolationSpeed).
@export var orbit_speed := 1.75
## A rock chasing its target blows up under this distance.
@export var arrive_distance := 0.25
## Ticks of life before a rock may blow up on the land (the original: frame ≥ 60 / 1.75, so 35).
@export_range(0.0, 10.0, 0.0001, "suffix:s") var ground_grace_s := 0.5833
## Ticks of life of a rock (SPEL duration 35 s · 60); at the next it blows up.
@export_range(0.0, 600.0, 0.0001, "suffix:s") var life_s := 35.0
## The line of sight starts at least this high over the land (a newborn rock is buried).
@export var los_lift := 0.5
## The burst played where a rock is born (empty = none).
@export var emerge_fx: ParticleType = preload("res://data/fx/rock_emerge.tres")
## More types played where a rock is born (the wizard's halo throws dirt and dust up too).
@export var emerge_extra: Array[ParticleType] = []
## Played where a rock picks its target (the sound `halo`). Optional.
@export var throw_burst: ParticleType

## The Rhinok (or the wizard) and the SPEL. Set by setup() / begin_cast() before the first tick.
var user: Node3D
var ability: AbilityType

## The numbers of the SPEL the rocks use, whatever type holds them (AbilityType of the Rhinok, SpellType of the wizard).
var _damage := 0.0
var _speed := 0.0
var _acceleration := 0.0
var _reach := 0.0
var _numbers := false
## False while the wizard casts: the rocks come out and orbit, nothing else.
var _armed := true
var _cast_ticks := 0
var _cast_elapsed := 0


class Rock extends RefCounted:
	var index := 0
	var node: Node3D
	var position := Vector3.ZERO
	var velocity := Vector3.ZERO
	var target: Node3D
	var target_center := Vector3.ZERO
	var has_orbit := false
	var from_point := Vector3.ZERO
	var from_tangent := Vector3.ZERO
	var to_point := Vector3.ZERO
	var to_tangent := Vector3.ZERO
	var progress := 0.0
	var age := 0


var _born := 0
var _rng: RandomNumberGenerator
var _look: ShotLook
var _slot := 0
var _who := "?"
var _active: Array[Rock] = []
var _spawned := 0
var _ended := false


## Before the node enters the tree. `rock_spawner` is the shot container's spawner.
func setup(body: Node3D, type: AbilityType, rock_spawner: Node) -> void:
	user = body
	ability = type
	_set_numbers(float(ability.damage), ability.speed_m_s, ability.acceleration_m_s2, ability.effect_range_m)
	spawner = rock_spawner
	_born = MatchClock.now()
	_who = AbilityEffect.who(body)
	_slot = int(body.get("owner_slot")) if "owner_slot" in body else 0
	_rng = MatchSeed.rng(["halo", _who, _born])
	_look = ShotLook.fit(self, _look, look)
	name = "Halo%s_%d" % [_who, _born]


## The wizard's halo: the cast started. The rocks come out as the casting goes on and wait for `release` to look for targets.
func begin_cast(caster: Node3D, spell: SpellType, _target: Node3D, _point: Vector3, cast_ticks: int) -> void:
	user = caster
	_set_numbers(float(spell.damage), spell.speed_m_s, spell.acceleration_m_s2, spell.effect_range_m)
	life_s = spell.duration_s
	spawner = ShotSpawner.of(get_tree())
	_born = MatchClock.now()
	_who = AbilityEffect.who(caster)
	_slot = int(caster.get("owner_slot")) if "owner_slot" in caster else 0
	_rng = MatchSeed.rng(["halo", _who, _born])
	_look = ShotLook.fit(self, _look, look)
	name = "Halo%s_%d" % [_who, _born]
	_armed = false
	_cast_ticks = maxi(1, cast_ticks)
	_cast_elapsed = 0


## The casting time ended: every rock is out and they start to look for targets.
func release(_target: Node3D) -> void:
	_armed = true


## The wizard was cut: the free rocks blow up where they are and the halo ends.
func abort() -> void:
	_armed = true
	_despawn_free()
	_finish()


func _set_numbers(damage: float, speed: float, acceleration: float, reach: float) -> void:
	_damage = damage
	_speed = speed
	_acceleration = acceleration
	_reach = reach
	_numbers = true


func _ready() -> void:
	add_to_group(GROUP)
	if not is_multiplayer_authority():
		set_physics_process(false)


## The bodies of the rocks that are out now (the harness reads them).
func rock_nodes() -> Array[Node3D]:
	var found: Array[Node3D] = []
	for rock in _active:
		if rock.node != null and is_instance_valid(rock.node):
			found.append(rock.node)
	return found


func _exit_tree() -> void:
	for rock in _active:
		if rock.node != null and is_instance_valid(rock.node):
			rock.node.queue_free()
	_active.clear()


func _physics_process(_delta: float) -> void:
	if _ended or not _numbers or MatchClock.now() <= _born:
		return
	var center := _center()
	if not is_nan(center.x):
		if _spawned == 0:
			_log_start(center)
		while _spawned < _rocks_due():
			_spawn()
	else:
		_despawn_free()
	if not _armed:
		_cast_elapsed += 1
	for rock in _active.duplicate():
		if not _armed:
			_orbit_only(rock, center)
		elif _update(rock, center) and rock.target == null:
			_seek(rock)
	if (_spawned > 0 and _active.is_empty()) or (_spawned == 0 and is_nan(center.x)):
		_finish()


## How many rocks are out by now: all at once for an ability, floor((progress + 0.1) × rocks) while the wizard casts (REA HaloOfEarthRun).
func _rocks_due() -> int:
	if _armed:
		return num_rocks
	return mini(num_rocks, floori((float(_cast_elapsed) / float(_cast_ticks) + 0.1) * float(num_rocks)))


## updateHaloRock with isCasting: the free flight only.
func _orbit_only(rock: Rock, center: Vector3) -> void:
	_orbit(rock, center)
	_place(rock)


## canCarryHaloOfEarth: alive, on the field, not being revived or taken.
func _can_carry() -> bool:
	if user == null or not is_instance_valid(user) or not user.is_inside_tree():
		return false
	var unit := user as UnitBody
	if unit == null:
		var health := Health.of(user)
		return health == null or not health.is_dead()
	return unit.mode != UnitBody.Mode.DEAD and unit.mode != UnitBody.Mode.SUMMONING \
		and unit.mode != UnitBody.Mode.REVIVING and not unit.is_taken()


## haloRockCenterPosition: over the top of the Rhinok's box. NaN x = it cannot carry the halo.
func _center() -> Vector3:
	if not _can_carry():
		return Vector3(NAN, NAN, NAN)
	var box := BodyNudge.box(user)
	var mid := box.get_center()
	return Vector3(mid.x, box.end.y + orbit_height, mid.z)


func _spawn() -> void:
	var box := BodyNudge.box(user)
	var size := box.size * spawn_box_scale
	var low := box.get_center() - size * 0.5
	var at := Vector3(_rng.randf_range(low.x, low.x + size.x), 0.0, _rng.randf_range(low.z, low.z + size.z))
	at.y = BodyNudge.ground_y(user, at) - bury_depth
	var rock := Rock.new()
	rock.index = _spawned
	rock.position = at
	rock.node = _make_node(at)
	_active.append(rock)
	_spawned += 1
	if emerge_fx != null:
		FxBus.broadcast(emerge_fx, at)
	for extra: ParticleType in emerge_extra:
		FxBus.broadcast(extra, at)
	_say("halo %s roca %d nace en %s (tick %d)" % [_who, rock.index, _v(at), MatchClock.now()])


## The rock's body: a RangedShot of the shot container.
func _make_node(at: Vector3) -> Node3D:
	if spawner == null:
		push_warning("HaloOfEarth: sin spawner de disparos; las rocas no se ven.")
		return null
	var data := {
		"x": at.x, "y": at.y, "z": at.z, "vx": 0.0, "vy": 0.0, "vz": 0.0,
		"damage": _damage, "slot": _slot, "gravity": 0.0,
		"max_distance": 1.0e9, "look": FxWire.id_of(look), "target": "",
		"shooter": str(user.get_path()) if user != null and user.is_inside_tree() else "",
	}
	return (spawner as ShotSpawner).spawn_shot(data)


## One tick of a rock. False = it blew up and is gone.
func _update(rock: Rock, center: Vector3) -> bool:
	if rock.target == null:
		_orbit(rock, center)
	else:
		var seen := _target_center(rock)
		var distance := seen - rock.position
		rock.velocity = _cap(rock.velocity + distance.normalized() * _acceleration, distance)
		rock.position += rock.velocity / MatchClock.TICKS_PER_SECOND_F
		if distance.length() < arrive_distance:
			_explode(rock, rock.target, "llegada")
			return false
	_place(rock)
	var hit := _touching(rock)
	if hit != null:
		_explode(rock, hit, "choque")
		return false
	if rock.age >= MatchClock.ticks_for(ground_grace_s) and _under_land(rock.position):
		_explode(rock, null, "suelo")
		return false
	rock.age += 1
	if rock.age > MatchClock.ticks_for(life_s):
		_explode(rock, null, "vida")
		return false
	return true


## The free flight: Hermite (cintp2) between two points of the ball, `orbit_speed` per second.
func _orbit(rock: Rock, center: Vector3) -> void:
	if not rock.has_orbit:
		rock.has_orbit = true
		rock.to_point = rock.position - center
		rock.to_tangent = Vector3.ZERO
		rock.progress = 1.0
	if rock.progress >= 1.0:
		rock.progress -= 1.0
		rock.from_point = rock.to_point
		rock.from_tangent = rock.to_tangent
		rock.to_point = _in_ball(orbit_radius)
		rock.to_tangent = _direction() * orbit_tangent
	rock.progress += orbit_speed / MatchClock.TICKS_PER_SECOND_F
	rock.position = _hermite(rock.from_point, rock.from_tangent, rock.to_point, rock.to_tangent, rock.progress) + center


## util.d cintp2, the position part.
static func _hermite(p0: Vector3, m0: Vector3, p1: Vector3, m1: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * p0 + (t3 - 2.0 * t2 + t) * m0 + (-2.0 * t3 + 3.0 * t2) * p1 + (t3 - t2) * m1


## state.uniformDisk (3D): a point of the ball, by rejection in its cube.
func _in_ball(radius: float) -> Vector3:
	var point := Vector3.ZERO
	while true:
		point = Vector3(_rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius))
		if point.length_squared() <= radius * radius:
			return point
	return point


## state.uniformDirection: a point of the cube [−1, 1]³, normalized.
func _direction() -> Vector3:
	return Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized()


## The SPEL's speed cap and the one that stops it from passing its target in a tick (updateHaloRock capVelocity).
func _cap(velocity: Vector3, distance: Vector3) -> Vector3:
	if velocity.length() > _speed:
		velocity = velocity.normalized() * _speed
	if velocity.length() > MatchClock.TICKS_PER_SECOND_F * distance.length():
		velocity = velocity.normalized() * distance.length() * MatchClock.TICKS_PER_SECOND_F
	return velocity


## The target's center now, or where it was when it stopped being valid.
func _target_center(rock: Rock) -> Vector3:
	if _valid(rock.target):
		rock.target_center = BodyNudge.center(rock.target)
	return rock.target_center


## The rock's body follows the simulated position (the Net sync replicates it).
func _place(rock: Rock) -> void:
	if rock.node != null and is_instance_valid(rock.node):
		rock.node.global_position = rock.position


## The live body not of the rock's side that its box touches (RangedShot.touching).
func _touching(rock: Rock) -> Node3D:
	var shot := rock.node as RangedShot
	return shot.touching() if shot != null and is_instance_valid(shot) else null


func _under_land(at: Vector3) -> bool:
	var shape := Terrain.of(self)
	return shape != null and shape.is_on_ground(at.x, at.z) and at.y < shape.height_at(at.x, at.z)


## The target search of a free rock (updateHaloOfEarth, 19296-19316).
func _seek(rock: Rock) -> void:
	var chased := {}
	for other in _active:
		if other.target != null:
			chased[other.target] = true
	var found: Array = []
	var seen := {}
	for group in [&"wizard", &"unit"]:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or seen.has(body) or chased.has(body) or body == user:
				continue
			seen[body] = true
			if not _attackable(body) or (_slot > 0 and _slot_of(body) == _slot):
				continue
			var distance := rock.position.distance_to(BodyNudge.center(body))
			if distance <= _reach:
				found.append([distance, str(body.name), body])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for entry in found:
		var body: Node3D = entry[2]
		if _in_sight(rock, body):
			rock.target = body
			rock.target_center = BodyNudge.center(body)
			if throw_burst != null:
				FxBus.broadcast(throw_burst, rock.position)
			var half := BodyNudge.box(body).size * 0.5
			_say("halo %s roca %d blanco %s a %.4f m desde %s hacia %s caja %s (tick %d)" % [
				_who, rock.index, body.name, entry[0], _v(rock.position), _v(rock.target_center), _v(half), MatchClock.now()])
			return


## A ray from the rock (lifted off the land) to the target's center meets no land or building (layer 1, wizards left out).
func _in_sight(rock: Rock, body: Node3D) -> bool:
	var from := rock.position
	from.y = maxf(from.y, BodyNudge.ground_y(user, from) + los_lift)
	var query := PhysicsRayQueryParameters3D.create(from, BodyNudge.center(body))
	query.collision_mask = 1
	var skip: Array[RID] = []
	for wizard in get_tree().get_nodes_in_group(&"wizard"):
		if wizard is CollisionObject3D:
			skip.append((wizard as CollisionObject3D).get_rid())
	query.exclude = skip
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## despawnHaloOfEarth: the free rocks blow up (the Rhinok cannot carry them); the ones with a target keep flying.
func _despawn_free() -> void:
	for rock in _active.duplicate():
		if rock.target == null:
			_explode(rock, null, "despawn")


## haloRockExplosion: the damage to the valid body it hit, the look's effects, and the rock is gone.
func _explode(rock: Rock, hit: Node3D, why: String) -> void:
	_say("halo %s roca %d explota por %s en %s con %s (tick %d)" % [
		_who, rock.index, why, _v(rock.position), hit.name if hit != null and is_instance_valid(hit) else "nadie", MatchClock.now()])
	if _valid(hit):
		_hurt(hit)
	for fx: ParticleType in _look.impact_fx:
		FxBus.broadcast(fx, rock.position)
	ScarMark.broadcast(_look.ground_mark, rock.position)
	if rock.node != null and is_instance_valid(rock.node):
		rock.node.queue_free()
	rock.node = null
	_active.erase(rock)


## dealSpellDamage(target, spell, …, DamageMod.none): the SPEL's amount as direct spell damage.
func _hurt(body: Node3D) -> void:
	var health := body.get_node_or_null("Health") as Health
	if health == null:
		return
	var taken := health.damage_typed(_damage, Health.DIRECT_SPELL, _slot)
	_say("dano %s %d vida %d" % [body.name, roundi(taken), roundi(health.current)])


func _finish() -> void:
	_ended = true
	set_physics_process(false)
	_say("halo %s fin (tick %d)" % [_who, MatchClock.now()])
	queue_free()


## isValidTarget: alive and on the field.
func _valid(body: Node3D) -> bool:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree() or not Attackable.is_body(body):
		return false
	var unit := body as UnitBody
	if unit != null and (unit.is_summoning() or unit.is_taken()):
		return false
	var health := body.get_node_or_null("Health") as Health
	return health != null and not health.is_dead()


## isValidAttackTarget: valid and not hidden from the foe.
func _attackable(body: Node3D) -> bool:
	return _valid(body) and (not body.has_method("is_targetable") or bool(body.call("is_targetable")))  # dynamic: unit, wizard, structure and doctor bodies answer it


static func _slot_of(body: Node) -> int:
	return int(body.get("owner_slot")) if "owner_slot" in body else 0


func _log_start(center: Vector3) -> void:
	var box := BodyNudge.box(user)
	var size := box.size * spawn_box_scale
	var low := box.get_center() - size * 0.5
	_say("halo %s usa tick %d nacen %d en tick %d caja %s a %s x%.2f centro %s" % [
		_who, _born, num_rocks, MatchClock.now(), _v(low), _v(low + size), spawn_box_scale, _v(center)])


func _say(text: String) -> void:
	if DebugLog.on(&"halo"):
		print(text)


static func _v(v: Vector3) -> String:
	return "(%.4f, %.4f, %.4f)" % [v.x, v.y, v.z]
