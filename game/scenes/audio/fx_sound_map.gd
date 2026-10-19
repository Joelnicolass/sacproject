@tool
class_name FxSoundMap
extends SoundSet

## RFC-052 052d (F363): what the FX of FxBus sound like, a type template (data/audio/fx_sounds.tres; yours in
## data/audio/custom/fx_sounds.tres win key by key). SoundBus listens to FxBus.played on every peer and plays the cue of
## the FX name here, so a broadcast FX carries its sound with no RPC of its own.
## - Keys of `cues` (inherited): the FX name as FxBus gets it: a ParticleType (`blood`), a BeamType (`lightning`), or the
##   file name without extension of a broadcast scene (`spike_field` for res://scenes/fx/spike_field.tscn).
## - The same table holds the cues of the SoundEmitter3D nodes (`fountain_loop`, `fireball_cast`...): an emitter names
##   its key, not a stream, so a dedicated server that loads the scene loads no audio.
## - An FX with no key, or a silent cue, is silence (no warning). Only the kinds in `heard_kinds` sound: a trail's puffs
##   (FxBus.KIND_PUFF) never do, even when their type has a cue as a burst ("heal" is a trail and a burst).

@export var heard_kinds: Array[StringName] = [&"burst", &"beam", &"scene"]


## The cue of an FX of `kind` named `fx_name`, or null (a kind not heard, no key, a silent cue).
func fx_cue(kind: StringName, fx_name: String) -> SoundCue:
	if not heard_kinds.has(kind):
		return null
	var found: SoundCue = cues.get(StringName(key_of(kind, fx_name)))
	return found if found != null and not found.is_silent() else null


## The key an FX goes by: a scene by its file name (no folder, no extension), the rest by its name.
static func key_of(kind: StringName, fx_name: String) -> String:
	return fx_name.get_file().get_basename() if kind == &"scene" else fx_name
