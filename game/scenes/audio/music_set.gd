@tool
class_name MusicSet
extends Resource

## RFC-052 052f (F365): the music of one god (data/audio/music/<god>.tres) or of the menu (music/menu.tres), a type
## template (never written at runtime). One list of tracks per MusicMood; MusicDirector plays one of them (the battle
## track is drawn with its own generator). A mood with no track here is asked to `fallback` (the gods share
## music/common.tres: battle, sacrifice, winning, losing, victory, defeat), and silence when nobody has one.
## Looping is the stream's own (the .import of a looping track has `loop=true`); `victory` and `defeat` play once.

@export var calm: Array[AudioStream] = []
@export var battle: Array[AudioStream] = []
@export var sacrifice: Array[AudioStream] = []
@export var winning: Array[AudioStream] = []
@export var losing: Array[AudioStream] = []
@export var victory: Array[AudioStream] = []
@export var defeat: Array[AudioStream] = []
## Tracks no mood plays (the original's God Realm, in menu.tres): available to a custom set or a later cut.
@export var extras: Array[AudioStream] = []
@export_range(-60.0, 12.0, 0.1, "suffix:dB") var volume_db := -6.0
@export var bus: StringName = &"Music"
## Seconds of the crossfade between two tracks (the original: 0.5 s).
@export_range(0.0, 10.0, 0.05, "suffix:s") var crossfade_s := 0.5
## Asked for a mood this set has no track for. Never itself.
@export var fallback: MusicSet


## The usable tracks of `mood` here or in the fallback chain; empty when nobody has one.
func tracks(mood: StringName) -> Array[AudioStream]:
	var current := self
	var hops := 0
	while current != null and hops < 8:
		var found := current._own(mood)
		if not found.is_empty():
			return found
		current = current.fallback
		hops += 1
	return []


func _own(mood: StringName) -> Array[AudioStream]:
	var list: Array[AudioStream] = []
	var source: Variant = get(String(mood)) if MusicMood.ALL.has(mood) else null
	if source is Array:
		for stream in source:
			if stream is AudioStream:
				list.append(stream)
	return list
