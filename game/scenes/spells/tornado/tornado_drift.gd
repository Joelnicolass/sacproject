class_name TornadoDrift
extends Node

## Where the tornado is and how big: it grows with the cast (to 0.8), then to 1 on the ground and
## wanders around the point it was cast at, picking a random spot inside the spell's range and going
## there at the spell's speed and acceleration; it shrinks when the zone ends. The only writer of
## the zone's position and of `size` (the server runs it and replicates both). It does not lift
## bodies (TornadoLift) or draw (TornadoLook).

@export var zone: GroundZone
## Size while the wizard casts is this fraction of the cast's progress.
@export_range(0.0, 1.0, 0.01) var cast_size := 0.8
## How fast the size changes, per second.
@export_range(0.05, 5.0, 0.05, "suffix:/s") var size_rate := 0.6
## The tornado picks another spot when it is this close to the one it was going to, m (squared in
## the original: 2).
@export_range(0.1, 10.0, 0.1, "suffix:m") var arrive_m := 1.41

## Replicated with the zone's position: 0 (gone) to 1 (full).
var size := 0.0
var velocity := Vector3.ZERO
var _goal := Vector3.ZERO
var _rng: RandomNumberGenerator


func _ready() -> void:
	process_physics_priority = -1
	set_physics_process(zone != null and zone.is_authority() and not Engine.is_editor_hint())
	if zone != null:
		_goal = zone.points[0]
		_rng = MatchSeed.rng(["tornado", String(zone.name)])


func _physics_process(_delta: float) -> void:
	var wanted := 0.0
	match zone.phase:
		GroundZone.Phase.CASTING:
			wanted = (
				cast_size * minf(1.0, float(zone.phase_ticks) / float(maxi(zone.cast_ticks, 1)))
			)
		GroundZone.Phase.ARMING, GroundZone.Phase.ACTIVE:
			wanted = 1.0 if _on_ground(zone.position) else 0.0
			_wander()
	size = move_toward(size, wanted, size_rate / MatchClock.TICKS_PER_SECOND_F)


func _on_ground(at: Vector3) -> bool:
	var shape := Terrain.of(self)
	return shape == null or shape.is_on_ground(at.x, at.z)


func _height(at: Vector3) -> float:
	var shape := Terrain.of(self)
	var land := shape.height_at(at.x, at.z) if shape != null else NAN
	return at.y if is_nan(land) else land


## One tick: stay on the ground, take a new goal near home when this one is reached or off the land,
## and accelerate towards it.
func _wander() -> void:
	var at := zone.position
	if _on_ground(at):
		at.y = _height(at)
	var flat := Vector2(at.x - _goal.x, at.z - _goal.z)
	if not _on_ground(_goal) or flat.length_squared() <= arrive_m * arrive_m:
		var home := zone.points[0]
		var range_m := zone.spell.effect_range_m
		_goal = Vector3(home.x + _offset(range_m), 0.0, home.z + _offset(range_m))
	_goal.y = _height(_goal)
	var delta := Vector3(_goal.x - at.x, 0.0, _goal.z - at.z)
	var most := zone.spell.acceleration_m_s2 / MatchClock.TICKS_PER_SECOND_F
	if delta.length() > most:
		delta *= most / delta.length()
	velocity += MatchClock.TICKS_PER_SECOND_F * delta
	if velocity.length() > zone.spell.speed_m_s:
		velocity *= zone.spell.speed_m_s / velocity.length()
	zone.position = at + velocity / MatchClock.TICKS_PER_SECOND_F


func _offset(range_m: float) -> float:
	return TornadoRules.wander_offset(range_m, _rng.randf(), _rng.randi() % 2 == 0)
