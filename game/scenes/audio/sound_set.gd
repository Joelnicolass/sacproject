@tool
class_name SoundSet
extends Resource

## RFC-052 052a (F360): the sounds of one emitter type (a creature, a wizard, the UI, the advisor, the world), a type
## template in data/audio/ (never written at runtime). Found by convention (SoundLibrary), not by a field of the catalog.

## SoundEvent -> SoundCue. A key with no cue, or a silent cue, is silence (no warning).
@export var cues: Dictionary[StringName, SoundCue] = {}
## Asked when this set has no cue for an event (a custom creature over a generic one). Never itself.
@export var fallback: SoundSet


## The cue of `event` here or in the fallback chain; null when nobody has one.
func cue(event: StringName) -> SoundCue:
	var current := self
	var hops := 0
	while current != null and hops < 8:
		var found: SoundCue = current.cues.get(event)
		if found != null:
			return found
		current = current.fallback
		hops += 1
	return null
