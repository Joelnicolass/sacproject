class_name TornadoWinds
extends Node

## The four winds that bend the funnel: each starts at a random angle of this cast and turns at its own rate, so every peer that counts the
## zone's ticks (`age_ticks`) gets the same bend, with nothing replicated. The only source of the winds' angles; TornadoLift reads them to find
## the axis and TornadoLook to draw it.
## Ref: sacengine castTornado wobblePhases and updateTornado (state.d:11477, 22865-22868).

@export var zone: GroundZone

var _starts := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


func _ready() -> void:
	if zone == null:
		return
	var rng := MatchSeed.rng(["tornado_winds", String(zone.name)])
	for i in 4:
		_starts[i] = rng.randf_range(-PI, PI)


## The four angles `ticks` ticks after the tornado was born.
func phases(ticks: int) -> PackedFloat32Array:
	var angles := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	for i in 4:
		angles[i] = TornadoRules.wind_phase(_starts[i], i, ticks)
	return angles
