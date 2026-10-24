class_name TornadoWinds
extends Node

## The four winds that bend the funnel: each starts at a random angle of this cast and turns at its own rate; every peer counts its own ticks,
## so the bend is the same everywhere with nothing replicated (a peer that joins late is a few ticks off, which nobody can see). The only
## source of the winds' angles: TornadoLift reads them to find the axis and TornadoLook to draw it.
## Ref: sacengine castTornado wobblePhases and updateTornado (state.d:11477, 22865-22868).

@export var zone: GroundZone

var _starts := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _ticks := 0


func _ready() -> void:
	if zone == null:
		return
	var rng := MatchSeed.rng(["tornado_winds", String(zone.name)])
	for i in 4:
		_starts[i] = rng.randf_range(-PI, PI)


func _physics_process(_delta: float) -> void:
	_ticks += 1


## Seconds since the tornado was born.
func seconds() -> float:
	return float(_ticks) / MatchClock.TICKS_PER_SECOND_F


## The four angles now.
func phases() -> PackedFloat32Array:
	var angles := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	for i in 4:
		angles[i] = TornadoRules.wind_phase(_starts[i], i, _ticks)
	return angles
