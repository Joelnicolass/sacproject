class_name GroundSeat
extends Node

## Seats a body on the land under it after it spawns: one ray cast down per physics step, up to
## `attempts`, until one finds the land; the soles of the feet (the Feet marker of the body scene)
## end on it. Server or solo; the body calls `begin` once and `step` first in its physics step.
## Not: gravity or flight (Locomotion, UnitAir) nor what a fall off the map means (the body).

@export var body: GameBody
## The body scene the body wears: its Feet marker says how far the soles are below the origin.
@export var mount: BodyMount
## Ray mask of the land the body is seated on.
@export_flags_3d_physics var ground_mask := 1
## Ray casts the body gets to find the land. 0 = never seated.
@export_range(0, 120) var attempts := 12

var _left := 0
var _seated_frame := -1


func _get_configuration_warnings() -> PackedStringArray:
	if body == null or mount == null:
		return PackedStringArray(["Assign body and mount."])
	return PackedStringArray()


func _ready() -> void:
	if body == null or mount == null:
		push_error("GroundSeat: assign body and mount.")


## The body spawned: the ray casts start.
func begin() -> void:
	_left = attempts


## The seating is not over, or it ended on this physics tick: the body waits on the air for the land
## under it and the tick that finds the land seats and nothing else.
func is_seating() -> bool:
	return _left > 0 or _seated_frame == Engine.get_physics_frames()


## One ray cast. True while the body is still seating (the step does nothing else).
func step() -> bool:
	if _left <= 0:
		return false
	var ground := GroundRay.surface_y(
		body, body.global_position, ground_mask, [body.get_rid()], NAN
	)
	_left -= 1
	if is_nan(ground):
		return true
	body.global_position.y = ground - mount.facts.feet.y
	body.reset_physics_interpolation()
	body.velocity = Vector3.ZERO
	_left = 0
	_seated_frame = Engine.get_physics_frames()
	return true
