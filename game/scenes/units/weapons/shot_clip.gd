class_name ShotClip
extends RefCounted

## The shoot animation in course: how long it lasts and the frames where a shot leaves. It is read
## once when the shot starts, so the ticks that follow read only variables. Not: what each shot does
## (RangedFire).

## The clip of the shot, whose `shoot` markers say the frames where a shot leaves.
const ROLE := &"shoot"

var active := false
var frames := 1
var rate := 30.0
var shots := PackedInt32Array([0])
var elapsed := 0.0
var next_tick := 0


## Reads the numbers of the `shoot` clip and starts counting from zero. A model without one shoots
## at once, as a clip of one frame.
func begin(facts: ClipFacts) -> void:
	active = true
	elapsed = 0.0
	next_tick = 0
	if facts.frames(ROLE) > 1:
		frames = facts.frames(ROLE)
		rate = float(facts.fps(ROLE))
		shots = facts.shots(ROLE)
		if shots.is_empty():
			shots = PackedInt32Array([frames - 1])
	else:
		frames = 1
		rate = 30.0
		shots = PackedInt32Array([0])


## Adds `scaled_delta` seconds and returns how many shots left in that time (their frames reached,
## in order).
func advance(scaled_delta: float) -> int:
	elapsed += scaled_delta
	var due := 0
	while next_tick < shots.size() and elapsed >= float(shots[next_tick]) / rate:
		next_tick += 1
		due += 1
	return due


func ended() -> bool:
	return elapsed >= float(frames) / rate
