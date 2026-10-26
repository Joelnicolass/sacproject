@tool
class_name SoundCue
extends Resource

## What one event sounds like, a type template (a .tres, never written at runtime).
## SoundBus picks one of `streams` with its own generator (never the global one, never an AudioStreamRandomizer) and
## applies the rest: volume, a pitch jitter, the bus, the 3D falloff and its limits.
## Ref: RFC-052 052a (F360).

## Variants; one is drawn per play. Empty = the cue is silent (a set may name an event it has no sound for yet).
@export var streams: Array[AudioStream] = []
@export_range(-60.0, 24.0, 0.1, "suffix:dB") var volume_db := 0.0
## Each play changes the pitch by up to ± this fraction (0.05 = ±5 %).
@export_range(0.0, 0.5, 0.01) var pitch_jitter := 0.0
## Bus of default_bus_layout.tres (Music, SFX, Voice, Ambience).
@export var bus: StringName = &"SFX"
## 3D only: silent past this distance (linear falloff, as the original: 200 m).
@export_range(1.0, 1000.0, 1.0, "suffix:m") var max_distance_m := 200.0
## 3D only: AudioStreamPlayer3D.unit_size (the distance at which the volume starts to fall).
@export_range(0.1, 100.0, 0.1) var unit_size := 10.0
## At most this many plays of this cue at once; a new one past it is dropped. 0 = no limit (the pool still caps it).
@export_range(0, 64) var max_voices := 4
## A play within this time of the previous one of this cue is dropped.
@export_range(0.0, 10.0, 0.01, "suffix:s") var cooldown_s := 0.0
## When the pool is full, a play takes the voice of the lowest priority playing (the oldest among equals) if that one
## is not higher than its own; otherwise it is dropped.
@export_range(0, 100) var priority := 50


func is_silent() -> bool:
	for stream in streams:
		if stream != null:
			return false
	return true


## Seconds of the longest variant: how long a play of this cue may last. 0 when it is silent.
func longest_s() -> float:
	var longest := 0.0
	for stream in streams:
		if stream != null:
			longest = maxf(longest, stream.get_length())
	return longest
