class_name Stalk
extends Node3D

## One stalk of Meanstalks: it grows while the wizard casts, then stretches its tip to the nearest body it can reach, hits it, lifts it to
## the top and throws it, and starts again; it shrinks when the zone ends. The only owner of its tip, growth and prey; the server replicates
## `tip`, `growth` and `mode`. It does not time the spell (GroundZone), choose the prey (StalkHunt), hold the body (StalkGrip) or draw (StalkLook).
## Ref: sacengine updateMeanstalk (state.d:22574-22695).

## The stalk entered mode `mode` (every peer): the look plays its sounds from it.
signal mode_changed(mode: int)

enum Mode { GROWING, SEARCHING, APPROACHING, HOLDING, SHRINKING }

@export var zone: GroundZone
## Which root of the zone it grows from.
@export_range(0, 11) var index := 0
@export var hunt: StalkHunt
@export var grip: StalkGrip
@export_range(1.0, 200.0, 0.5, "suffix:m") var height_m := 60.0
@export_range(0.1, 20.0, 0.1, "suffix:s") var grow_s := 3.0
## Replicated: the tip in the world, how much is out of the ground (0 to 1), what it does.
var tip := Vector3.ZERO
var growth := 0.0
var mode := Mode.GROWING:
	set(value):
		if value != mode:
			mode = value
			mode_changed.emit(mode)

var _velocity := Vector3.ZERO
var _goal := Vector3.ZERO
var _rate := 6.0
var _accel := 0.6
var _gap := 0.0
var _prey: Node3D
var _chased: Node3D


func _ready() -> void:
	process_physics_priority = -1
	if zone == null or index >= zone.points.size():
		visible = false
		set_physics_process(false)
		return
	global_position = zone.points[index]
	tip = _top()


func _physics_process(_delta: float) -> void:
	if not zone.is_authority() or Engine.is_editor_hint():
		return
	if zone.phase == GroundZone.Phase.ENDING and mode != Mode.SHRINKING:
		grip.drop()
		mode = Mode.SHRINKING
	var old_y := _base().y
	_chased = null
	match mode:
		Mode.GROWING:
			tip = _top()
			if growth >= 1.0:
				_begin_search()
		Mode.SEARCHING:
			_look()
		Mode.APPROACHING:
			_chased = _approach()
		Mode.HOLDING:
			_hold()
	growth = move_toward(growth, _want(), 1.0 / (grow_s * MatchClock.TICKS_PER_SECOND_F))
	tip.y += _base().y - old_y
	if growth != 1.0 or _want() != 1.0:
		_prey = null
		_goal = _top()
	var moved := StalkRules.step_tip(tip, _velocity, _goal, _rate, _accel)
	_gap = (_goal - tip).length()
	tip = moved[0]
	_velocity = moved[1]
	if _chased != null and StalkRules.is_live(_chased):
		_gap = minf(101.0, Pulling.box_distance(BodyNudge.box(_chased), tip))
	grip.follow(tip, _velocity)


## The root, sunk by what has not grown yet.
func _base() -> Vector3:
	return global_position + Vector3.DOWN * ((1.0 - growth) * height_m)


func _top() -> Vector3:
	return _base() + Vector3.UP * height_m


## How much of the stalk should be out: the cast's progress while the wizard casts, 0 when it shrinks, else all of it.
func _want() -> float:
	if mode == Mode.SHRINKING:
		return 0.0
	if zone.phase == GroundZone.Phase.CASTING:
		return minf(1.0, float(zone.phase_ticks) / float(maxi(zone.cast_ticks, 1)))
	return 1.0


func _begin_search() -> void:
	mode = Mode.SEARCHING
	_gap = 0.0
	_rate = hunt.wander_speed
	_accel = hunt.wander_accel
	_look()


## The nearest body it can reach, or a drift to a point of the cone over the root.
func _look() -> void:
	_prey = hunt.pick(_base(), zone.spell.effect_range_m)
	if _prey != null:
		_rate = zone.spell.speed_m_s
		_accel = zone.spell.acceleration_m_s2
		_gap = 50.0
		mode = Mode.APPROACHING
		_chased = _approach()
	elif _gap < 3.0:
		_goal = hunt.wander_goal(_base(), height_m)


## Follows the body; at the catch it hits it, throws it up and starts to lift. Returns the prey while it still stretches.
func _approach() -> Node3D:
	if not StalkRules.is_live(_prey):
		_begin_search()
		return null
	_goal = BodyNudge.center(_prey)
	if not hunt.takeable(_prey, _goal, _base()):
		_begin_search()
		return null
	if _gap >= hunt.catch_m:
		return _prey
	_velocity.y = maxf(_velocity.y, 0.0)
	SplashDamage.hurt(_prey, float(zone.spell.damage), zone.from_slot, Health.DIRECT_SPELL)
	hunt.roster.add(_prey)
	_rate = hunt.lift_speed
	_accel = hunt.lift_accel
	_goal = _top()
	if grip.catch(_prey, zone.from_slot, _velocity):
		_gap = 50.0
		mode = Mode.HOLDING
	else:
		_begin_search()
	return null


func _hold() -> void:
	if grip.holds() and _gap < hunt.release_m:
		grip.throw(_velocity)
	if not grip.holds():
		_begin_search()
