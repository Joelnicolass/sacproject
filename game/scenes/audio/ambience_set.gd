@tool
class_name AmbienceSet
extends Resource

## The ambience of one god (scenes/audio/ambience/<god>.tres), a type template (never written at
## runtime). AmbienceDirector plays `bed` in a loop on its own 2D player and, every `interval_s`
## (drawn with its own generator), one of the one-shots at a point around the listener. It does not
## say which god uses it: LookProfile.ambience points here.
## - `bed`: a SoundCue whose stream loops by itself (gapless: a WAV with `edit/loop_mode=2` in its
##   .import). Null = none (not every god has a bed; a custom one goes here).
## - `one_shots`: the cues played at random around the listener (the birds, the wind, the lava of
##   the land).
## - `night_one_shots`: the ones played instead while it is night (owls, crickets, insects). Empty =
##   the same by night.

@export var bed: SoundCue
@export var one_shots: Array[SoundCue] = []
@export var night_one_shots: Array[SoundCue] = []
## Seconds between two one-shots (min, max).
@export var interval_s := Vector2(6.0, 14.0)
## Horizontal distance from the listener (min, max).
@export var distance_m := Vector2(12.0, 40.0)
## Height over the listener (min, max).
@export var height_m := Vector2(0.0, 8.0)
