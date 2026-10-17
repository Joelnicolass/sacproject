class_name RangedAttack
extends Node

## A ranged creature's shot (sacengine `attack`/`shoot`/`aim`/`shootOnTick`, state.d:12511-12855).
## Runs on the server (or solo) only.
##
## - Ranged or melee (`attack`, state.d:12849-12855): a creature with a ranged attack shoots unless
##   the target touches its 0.8-scaled melee box and the boxes are within rangedMeleeAttackDistance
##   0.5 m (state.d:8752).
## - Range (`shootRange`, state.d:12468): max(0.8·range, range − 30) from the body to the target's
##   box; farther, or without a clear line, it keeps walking (`aim`, state.d:12521-12558).
## - It stops, turns until within 4·rotationSpeed/fps of the aim, and starts the shoot0 animation
##   only if the ranged cooldown is 0 and its mana ≥ manaCost (state.d:12560-12571).
## - On each shoot tick of the animation it drains manaCost/numShootTicks (if it has that much) and
##   fires (state.d:12631-12758); the cooldown (ability cooldown·60 frames) starts on the first
##   shot (state.d:12774-12776) and counts down every frame (state.d:13936).
## - Aim: target center led by its velocity, plus 0.5·g·d/speed² upward for ballistic shots
##   (getShotDirectionWithGravity, state.d:11506), then ranged accuracy (ShotAim.scatter, applyRangedAccuracy,
##   state.d:11491): angle = atan(accuracy·0.001·0.14 + 0.03), azimuth angle·r³ and elevation
##   0.1·angle·r³ with r uniform in [−1, 1].

signal fired(target: Node3D, damage: float, mana_before: float, mana_after: float)

enum Step { APPROACH, HOLD, FIRE }

const FPS := 60.0
## sacspell.d:120 fallingAcceleration; 30 for every other tag.
const FALLING_ACCELERATION := {"dkba": 10.0}
const DEFAULT_FALLING := 30.0
## Shots fired with getShotDirectionWithGravity (state.d:11548-11800): earthfling, flame minion,
## fallen, sylph, ranger, mutant, abomination, bombard, flurry, flummox. The rest fly straight.
const BALLISTIC: PackedStringArray = ["ekba", "fkba", "dkba", "aaba", "wobf", "babt", "tugt", "cfba", "caba", "crba"]

## sacengine rangedMeleeAttackDistance.
@export var melee_distance := 0.5
## sacengine shootRange: max(range_factor·range, range − range_margin).
@export var range_factor := 0.8
@export var range_margin := 30.0
## sacengine aim: facing once within facing_frames·turn_rate/fps of the aim.
@export var facing_frames := 4.0
## The shot leaves from the body's front at this fraction of its height. sacengine uses the
## shoot animation's hand (shotPosition, state.d:1346); the baked bodies have no hand bones.
@export var shot_height := 0.7
## sacengine hasClearShot: the line is checked 0.2 m under both ends (state.d:12460).
@export var clear_shot_drop := 0.2
@export_flags_3d_physics var ground_mask := 1

var attack: AbilityType
var type: CreatureType

var _body: Node3D
var _mana: Node
var _melee: Node
var _rng: RandomNumberGenerator
var _cooldown := 0.0
var _target: Node3D
var _anim: Dictionary = {}
var _elapsed := 0.0
var _next_tick := 0


func setup(body: Node3D, creature: CreatureType, mana: Node, melee: Node, rng: RandomNumberGenerator) -> void:
	_body = body
	type = creature
	_mana = mana
	_melee = melee
	_rng = rng
	attack = GameData.ability(creature.ranged_attack_tag) if creature and creature.is_ranged else null
	if attack and attack.speed <= 0.0:
		attack = null


func _ready() -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


func has_attack() -> bool:
	return attack != null


func is_shooting() -> bool:
	return not _anim.is_empty()


func cooldown_left() -> float:
	return _cooldown


func cancel() -> void:
	_anim = {}
	_target = null


func shoot_range() -> float:
	if attack == null:
		return 0.0
	return maxf(range_factor * attack.cast_range, attack.cast_range - range_margin)


## sacengine attack: shoot unless the foe is in melee contact. A body of its own side (a Scarab's patient, F136) is
## always shot, never struck (state.d:12850-12853).
func prefers(target: Node3D) -> bool:
	if attack == null or target == null:
		return false
	if "owner_slot" in target and int(target.get("owner_slot")) == int(_body.get("owner_slot")):
		return true
	if _melee == null or not _melee.call("in_reach", target, float(_melee.get("start_factor"))):
		return true
	return _box_gap(target) > melee_distance


## One chase frame toward `target`: APPROACH (walk on), HOLD (stand and turn) or FIRE (shoot0 started).
func aim(target: Node3D) -> Step:
	if _body.global_position.distance_to(_box_point(target)) > shoot_range():
		return Step.APPROACH
	var predicted := _predicted(target)
	if not _clear_shot(target, predicted):
		return Step.APPROACH
	var to := predicted - _body.global_position
	to.y = 0.0
	var turn_rate := float(_body.get("turn_rate"))
	var facing: Vector3 = _body.call("facing_flat")
	if to.length_squared() > 0.000001 and facing.angle_to(to.normalized()) > facing_frames * turn_rate / FPS:
		return Step.HOLD
	if _cooldown > 0.0 or _mana_left() < _mana_cost():
		return Step.HOLD
	_start(target)
	return Step.FIRE


## Flat direction the body should face to shoot `target`.
func aim_direction(target: Node3D) -> Vector3:
	var to := _predicted(target) - _body.global_position
	to.y = 0.0
	return to.normalized() if to.length_squared() > 0.000001 else _body.call("facing_flat")


## Advances shoot0 by delta. Returns false once the animation has ended.
func advance(delta: float) -> bool:
	if _anim.is_empty():
		return false
	_elapsed += delta
	var rate := float(_anim.get("framerate", 30))
	var frames := int(_anim.get("frames", 1))
	var ticks: Array = _anim.get("shoot_ticks", [])
	var tick_frames: Array = ticks if not ticks.is_empty() else [frames - 1]
	while _next_tick < tick_frames.size() and _elapsed >= float(tick_frames[_next_tick]) / rate:
		_next_tick += 1
		_shoot_tick(tick_frames.size())
	if _elapsed >= float(frames) / rate:
		_anim = {}
		return false
	return true


func _start(target: Node3D) -> void:
	_target = target
	_anim = _shoot_animation()
	_elapsed = 0.0
	_next_tick = 0


func _shoot_animation() -> Dictionary:
	if type and not type.shoot_animations.is_empty():
		var anim: Dictionary = type.shoot_animations[0]
		if int(anim.get("frames", 0)) > 1:
			return anim
	## No SXSK shoot0 in the cache: shoot at once, as an animation of one tick.
	return {"frames": 1, "framerate": 30, "shoot_ticks": [0]}


func _shoot_tick(tick_count: int) -> void:
	var target := _target
	if target == null or not is_instance_valid(target) or not _is_live(target):
		return
	var cost := _mana_cost() / float(maxi(tick_count, 1))
	var before := _mana_left()
	if before < cost:
		return
	_fire(target)
	_mana.call("spend", cost)
	if _cooldown <= 0.0:
		_cooldown = attack.cooldown_s
	fired.emit(target, float(attack.damage), before, _mana_left())


func _fire(target: Node3D) -> void:
	var look := ShotLook.for_tag(attack.tag)
	var spawner := get_tree().get_first_node_in_group("shot_spawner")
	if look.strike == null and spawner == null:
		push_warning("RangedAttack: no hay ShotSpawner en el mundo.")
		return
	var origin := shot_origin()
	var predicted := _predicted(target)
	var offset := predicted - origin
	var direction: Vector3 = offset.normalized() if offset.length_squared() > 0.000001 else _body.call("facing_flat")
	var ballistic := BALLISTIC.has(attack.tag)
	var gravity := float(FALLING_ACCELERATION.get(attack.tag, DEFAULT_FALLING)) if ballistic else 0.0
	if ballistic:
		direction.y += 0.5 * gravity * offset.length() / (attack.speed * attack.speed)
	direction = ShotAim.scatter(direction, _accuracy(), _rng)
	if not ballistic:
		direction = direction.normalized()
	var velocity: Vector3 = direction * attack.speed
	var data := {
		"tag": attack.tag,
		"x": origin.x, "y": origin.y, "z": origin.z,
		"vx": velocity.x, "vy": velocity.y, "vz": velocity.z,
		"damage": float(attack.damage) * _attack_factor(),
		"slot": int(_body.get("owner_slot")),
		"gravity": gravity,
		"max_distance": INF if ballistic else attack.cast_range * look.range_factor,
		"target": str(target.get_path()),
		"shooter": str(_body.get_path()),
		## F124: the predicted point without accuracy, and the accuracy, for the strikes that aim again.
		"aim_x": predicted.x, "aim_y": predicted.y, "aim_z": predicted.z,
		"accuracy": _accuracy(),
	}
	if look.strike != null:
		_strike(look, data)
		return
	## F125 (RFC-030 030n-a): ShotLook.volley shots with this one direction (one accuracy roll, boulderdashShoot
	## state.d:11806-11808); each packet says which one it is and how far the aim was (ShotSplit fans them out).
	var half := (maxi(look.volley, 1) - 1) / 2
	for index in range(-half, half + 1):
		var shot := data.duplicate()  # a new Dictionary per shot: the spawner writes its name
		shot["volley_index"] = index
		shot["aim_distance"] = offset.length()
		spawner.call("spawn_shot", shot)


## F124 (RFC-030 030m): a ShotStrike (ShotLook.strike) in place of a flying shot: the Gnome's ray, the Styx's blow.
## Server (or solo) only, as this node's child; it is not replicated (its look goes through FxBus).
func _strike(look: ShotLook, data: Dictionary) -> void:
	var node := look.strike.instantiate()
	var strike := node as ShotStrike
	if strike == null:
		node.free()
		push_warning("RangedAttack: el strike de %s no es un ShotStrike." % attack.tag)
		return
	add_child(strike)
	strike.launch(data, look, self)


## The shooter's ranged accuracy (ShotAim.scatter).
func _accuracy() -> float:
	return float(type.ranged_accuracy) if type else 0.0


## Where a shot leaves: the body's front at shot_height of its height. Public for a strike that follows its shooter.
func shot_origin() -> Vector3:
	return ShotAim.origin(_body, shot_height)


## sacengine predictShotTargetPosition: the target's center where it will be when the shot arrives.
func _predicted(target: Node3D) -> Vector3:
	var center := _center(target)
	if attack == null or attack.speed <= 0.0 or not target is CharacterBody3D:
		return center
	var flight := _body.global_position.distance_to(center) / attack.speed
	var moving := (target as CharacterBody3D).velocity
	moving.y = 0.0
	return center + moving * flight


## sacengine getShotTargetPosition: the target's box point nearest to our center.
func _box_point(target: Node3D) -> Vector3:
	var center := _center(target)
	var reach := float(_profile(target).get("reach", 0.35))
	var toward := _body.global_position - center
	toward.y = 0.0
	if toward.length() <= reach:
		return center
	return center + toward.normalized() * reach


func _box_gap(target: Node3D) -> float:
	var d := target.global_position - _body.global_position
	var own := float(_body.call("melee_profile").get("reach", 0.35))
	return maxf(0.0, Vector2(d.x, d.z).length() - own - float(_profile(target).get("reach", 0.35)))


func _clear_shot(target: Node3D, predicted: Vector3) -> bool:
	var drop := Vector3.DOWN * clear_shot_drop
	var query := PhysicsRayQueryParameters3D.create(shot_origin() + drop, predicted + drop)
	query.collision_mask = ground_mask
	var skip: Array[RID] = []
	for node: Node in [_body, target]:
		if node is CollisionObject3D:
			skip.append((node as CollisionObject3D).get_rid())
	query.exclude = skip
	return _body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _center(target: Node3D) -> Vector3:
	var col := target.get_node_or_null("Collision") as Node3D
	return col.global_position if col else target.global_position + Vector3.UP * float(_profile(target).get("height", 1.8)) * 0.5


func _profile(target: Node3D) -> Dictionary:
	return _melee.call("profile_of", target) if _melee else {}


func _mana_cost() -> float:
	## sacspell.d:194 manaCost = max(1, cost).
	return maxf(1.0, float(attack.mana_cost)) if attack else INF


func _mana_left() -> float:
	return float(_mana.get("current")) if _mana else 0.0


static func _is_live(body: Node) -> bool:
	if body.has_method("is_targetable") and not body.call("is_targetable"):
		return false
	var health := body.get_node_or_null("Health")
	return health != null and not health.call("is_dead")


## sacengine attackDamageFactor (state.d:8884): a guardian hits harder. 1 for a body without the property.
func _attack_factor() -> float:
	var factor: Variant = _body.get("attack_factor")
	return maxf(0.0, float(factor)) if factor != null else 1.0
