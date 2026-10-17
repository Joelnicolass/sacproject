@tool
class_name ClipEvents
extends Node

## RFC-023 (023b): the target of the method tracks BodyRig adds to every clip. A clip's SKEL events (sound, attack,
## cast, shoot, death, grab, foot...) call fire(kind) at their frame; listeners connect to clip_event.
## Presentation only: the simulation never reads it (ticks come from CreatureType).

## A clip passed one of its events. `kind` is the SKEL event name ("attack", "cast", "foot"...).
signal clip_event(kind: String)


func fire(kind: String) -> void:
	clip_event.emit(kind)
