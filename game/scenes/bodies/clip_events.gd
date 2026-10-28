@tool
class_name ClipEvents
extends Node

## The target of the method tracks inside each Animation of a model's library: a clip's events (sound, attack, cast, shoot,
## death, grab, foot...) call fire(kind) at their frame; listeners connect to clip_event.
## Presentation only: the simulation never reads it (the rules take the blow frame from the `hit` marker through ClipFacts).

## A clip passed one of its events. `kind` is the event name ("attack", "cast", "foot"...).
signal clip_event(kind: String)


func fire(kind: String) -> void:
	clip_event.emit(kind)
