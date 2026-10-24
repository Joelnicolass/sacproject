class_name Spinner
extends Node3D

## A thing that turns on its own about an axis it drew when it was born (a meteorite's rock). Presentation only, on every peer. It does not move.

## Turns a second, drawn between the two.
@export var turns_per_s := Vector2(0.2, 0.8)

var _axis := Vector3.UP
var _rate := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_axis = Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
	_rate = TAU * rng.randf_range(turns_per_s.x, turns_per_s.y)
	set_process(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	rotate(_axis, _rate * delta)
