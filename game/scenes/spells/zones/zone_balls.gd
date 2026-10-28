@tool
class_name ZoneBalls
extends Node3D

## The balls of a zone: each child stands on one point of the zone and grows from nothing to its size while the wizard casts. They go when
## the zone acts (the burst takes their place) and shrink away if the cast is cut. Presentation only, on every peer, from the zone's phase.
## It does not hurt anyone (ZoneBlast).

## How fast a cut cast's balls shrink, as a share of their size per second.
@export_range(0.1, 10.0, 0.1) var shrink_per_s := 2.0
@export var zone: GroundZone

var _size := 0.0


## This moves by itself every frame, so physics interpolation must leave it alone.
func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ready() -> void:
	set_process(zone != null and not Engine.is_editor_hint())
	if not is_processing():
		return
	var balls := get_children()
	for i in balls.size():
		var ball := balls[i] as Node3D
		if ball == null:
			continue
		ball.visible = false
		if i < zone.points.size():
			ball.position = to_local(zone.points[i])


func _process(delta: float) -> void:
	match zone.phase:
		GroundZone.Phase.CASTING:
			_size = clampf(float(zone.phase_ticks) / float(maxi(zone.cast_ticks, 1)), 0.0, 1.0)
		GroundZone.Phase.ARMING:
			_size = 1.0
		GroundZone.Phase.ACTIVE:
			_size = 0.0
		GroundZone.Phase.ENDING:
			_size = maxf(0.0, _size - shrink_per_s * delta) if zone.cancelled else 0.0
	var balls := get_children()
	for i in mini(balls.size(), zone.points.size()):
		var ball := balls[i] as Node3D
		ball.visible = _size > 0.001
		ball.scale = Vector3.ONE * maxf(_size, 0.001)


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if zone != null
		else PackedStringArray(["The zone (GroundZone) whose phase it follows is missing."])
	)
