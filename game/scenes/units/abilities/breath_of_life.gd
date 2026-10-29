class_name BreathOfLife
extends Node3D

## The flight of the Dragon's Breath of life. The effect is added at the shoot tick and runs from
## the next tick: each tick velocity = 60·(target − position), capped at the spell's speed (60),
## position += velocity / 60. When that velocity is under 0.01 the breath has arrived and the target
## revives fast (FastRevive). So it takes ⌈d⌉ ticks to land and one more to notice: ⌈d⌉ + 1 from the
## shoot tick. The target is the corpse's center, followed every tick (a soul was resolved to its
## corpse). This node is the coordinator; the body of the breath is a RangedShot of the shot
## container (ShotLook breath_of_life: collides off), which only draws it and replicates its
## position. Server (or solo) only; priority −1: it moves the shot before the bodies move, like
## Protector and HaloOfEarth.
##
## Look: the breath is a golden ball with the heal trail; it does not turn the caster's head; no
## sound.

## The breath's look (scenes/units/attacks/shots/breath_of_life.tscn). Empty = a plain ball.
@export var look: PackedScene
## The revival the breath starts on arrival (fast_revive.tscn).
@export var fast_revive_scene: PackedScene
## Arrived when the velocity of the tick is under this (0.01 m/s).
@export var arrive_speed := 0.01

## The Dragon, the SPEL and the corpse. Set by setup() before the node enters the tree.
var user: Node3D
var ability: AbilityType
var corpse: UnitBody
var spawner: ShotSpawner

var _born := 0
var _position := Vector3.ZERO
var _shot: RangedShot
var _ended := false
var _who := "?"


## Before the node enters the tree. `shot_spawner` is the shot container's spawner.
func setup(body: Node3D, type: AbilityType, shot_spawner: ShotSpawner, target: UnitBody) -> void:
	user = body
	ability = type
	spawner = shot_spawner
	corpse = target
	_born = MatchClock.now()
	_who = AbilityEffect.who(body)
	_position = _origin()
	name = "Breath%s_%d" % [_who, _born]


func _ready() -> void:
	if not is_multiplayer_authority():
		set_physics_process(false)
		return
	_shot = _make_shot()
	_say(
		(
			"breath %s leaves %s toward %s d %.4f m (tick %d)"
			% [
				_who,
				_v(_position),
				AbilityEffect.who(corpse),
				_position.distance_to(BodyNudge.center(corpse)),
				_born
			]
		)
	)


func _exit_tree() -> void:
	if _shot != null and is_instance_valid(_shot):
		_shot.queue_free()
	_shot = null


func _physics_process(_delta: float) -> void:
	if _ended or ability == null or MatchClock.now() <= _born:
		return
	if (
		corpse == null
		or not is_instance_valid(corpse)
		or not corpse.is_inside_tree()
		or not corpse.is_dead()
	):
		_say("breath %s loses its target (tick %d)" % [_who, MatchClock.now()])
		_finish()
		return
	var velocity := MatchClock.TICKS_PER_SECOND_F * (BodyNudge.center(corpse) - _position)
	if velocity.length() > ability.speed_m_s:
		velocity = velocity.normalized() * ability.speed_m_s
	_position += velocity / MatchClock.TICKS_PER_SECOND_F
	if _shot != null and is_instance_valid(_shot):
		_shot.global_position = _position
	if velocity.length() < arrive_speed:
		_arrive()


## Arrival: the target revives fast. A corpse that cannot be revived any more (its soul was taken)
## just ends the breath.
func _arrive() -> void:
	_say("breath %s reaches %s (tick %d)" % [_who, AbilityEffect.who(corpse), MatchClock.now()])
	var fast := fast_revive_scene.instantiate() as FastRevive if fast_revive_scene != null else null
	if fast == null:
		push_warning("BreathOfLife: fast_revive_scene is not a FastRevive.")
	elif fast.begin(corpse, BreathOfLifeAbility.soul_of(corpse)):
		corpse.add_child(fast)
	else:
		fast.free()
		_say(
			(
				"breath %s cannot raise %s (tick %d)"
				% [_who, AbilityEffect.who(corpse), MatchClock.now()]
			)
		)
	_finish()


## The Dragon's shot origin (its RangedWeapon), or its feet lifted when it has none.
func _origin() -> Vector3:
	return ShotAim.shot_position(user)


## The breath's body: a RangedShot of the shot container, placed by this node every tick.
func _make_shot() -> RangedShot:
	if spawner == null:
		push_warning("BreathOfLife: no shot spawner; the breath is not shown.")
		return null
	var data := {
		"x": _position.x,
		"y": _position.y,
		"z": _position.z,
		"vx": 0.0,
		"vy": 0.0,
		"vz": 0.0,
		"damage": 0.0,
		"slot": int(user.get("owner_slot")) if "owner_slot" in user else 0,
		"gravity": 0.0,
		"max_distance": 1.0e9,
		"look": FxWire.id_of(look),
		"target": "",
		"shooter": str(user.get_path()) if user.is_inside_tree() else "",
	}
	return spawner.spawn_shot(data)


func _finish() -> void:
	_ended = true
	set_physics_process(false)
	queue_free()


func _say(text: String) -> void:
	if DebugLog.on(&"breath"):
		print(text)


static func _v(v: Vector3) -> String:
	return "(%.4f, %.4f, %.4f)" % [v.x, v.y, v.z]
