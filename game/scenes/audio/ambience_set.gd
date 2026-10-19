@tool
class_name AmbienceSet
extends Resource

## RFC-052 052g (F366): the ambience of one god (data/audio/ambience/<god>.tres), a type template (never written at
## runtime). AmbienceDirector plays `bed` in a loop on its own 2D player and, every `interval_s` (drawn with its own
## generator), one of the one-shots at a point around the listener.
## - `bed`: a SoundCue whose stream loops by itself (gapless: a WAV with `edit/loop_mode=2` in its .import). Null = none
##   (the original has no bed for every god; a custom one goes here).
## - One-shots: the cues of `one_shot_keys` in the SoundSet of `one_shot_source` (the original's `A*` codes of the `spel`
##   set in world.tres: `AjaN`, `AstU`...; looked up over SoundLibrary's roots, so a custom world.tres overrides) plus
##   `one_shots`, cues of its own.

@export var bed: SoundCue
@export var one_shot_source := "world"
@export var one_shot_keys: Array[StringName] = []
@export var one_shots: Array[SoundCue] = []
## Seconds between two one-shots (min, max).
@export var interval_s := Vector2(6.0, 14.0)
## Horizontal distance from the listener (min, max).
@export var distance_m := Vector2(12.0, 40.0)
## Height over the listener (min, max).
@export var height_m := Vector2(0.0, 8.0)
