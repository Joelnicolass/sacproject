@tool
class_name RitualSite
extends Node3D

## "A ritual can be held here": whose it is, where its center is, and whether another ritual
## already uses it. The altar has one; a Shrine would add its own as a child (RFC-020).
## Only the server calls occupy() and release().

enum Kind { ALTAR, SHRINE }

## A ritual took the site.
signal occupied(by: Node)
## The site is free again.
signal released

@export var kind := Kind.ALTAR
## The building this site belongs to; it says who owns it and whether it still stands.
@export var altar: Altar

var occupant: Node


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if altar == null:
		warnings.append("Asigná en `altar` el altar al que pertenece este sitio.")
	return warnings


func owner_slot() -> int:
	return altar.owner_slot if altar else 0


func center() -> Vector3:
	return global_position


## Standing: a collapsing or destroyed altar is not a place for rituals.
func is_standing() -> bool:
	return altar != null and altar.is_standing()


func is_free() -> bool:
	return occupant == null or not is_instance_valid(occupant)


## Takes the site for `by`. False if it does not stand or another ritual has it.
func occupy(by: Node) -> bool:
	if by == null or not is_standing() or not is_free():
		return false
	occupant = by
	occupied.emit(by)
	return true


func release() -> void:
	if occupant == null:
		return
	occupant = null
	released.emit()
