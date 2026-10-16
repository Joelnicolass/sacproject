class_name Affliction
extends Node

## F120 (RFC-030i): one state that takes the creature out of the fight (Stunned; later Petrified, Frozen). A child of
## Afflictions, which owns the questions the body asks and the replicated mask. Whether it is on is that mask's bit
## (`type.bit`), the same on the server and on the clients. Variants start themselves (stun_with_cooldown, petrify…)
## through Afflictions.admit/mark and draw themselves in _shown().

@export var type: AfflictionType


func is_on() -> bool:
	var owner_node := _afflictions()
	return owner_node != null and type != null and owner_node.is_on(type)


## The clip role the body plays while it is on ("" = it does not say).
func clip_role() -> String:
	return ""


## Every peer, when its bit changes: start or stop the look (and the local clock of the clip). Also when Afflictions
## ends it on the server (a state that cancels it started, or the body died).
func _shown(_on: bool) -> void:
	pass


func _afflictions() -> Afflictions:
	return get_parent() as Afflictions


func _body() -> Node3D:
	var owner_node := _afflictions()
	return owner_node.body if owner_node else null


func _simulates() -> bool:
	return not MpKit.is_networked() or MpKit.is_server()
