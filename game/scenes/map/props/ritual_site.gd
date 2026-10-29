@tool
class_name RitualSite
extends Node3D

## "A ritual can be held here": whose it is, where its center is, and whether another ritual already
## uses it. The altar has one and so has every Shrine. Only the server calls occupy() and release().

## A ritual took the site.
signal occupied(by: Node)
## The site is free again.
signal released

enum Kind { ALTAR, SHRINE }

## Every site in play: where Convert looks for the closest one of a side.
const GROUP := &"ritual_site"

@export var kind := Kind.ALTAR
## The altar this site belongs to (an altar's site). Leave empty on a Shrine.
@export var altar: Altar
## The building this site belongs to (a Shrine's site). Leave empty on an altar.
@export var building: MapBuilding

var occupant: Node


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if altar == null and building == null:
		warnings.append("Assign in `altar` or in `building` who owns this site.")
	return warnings


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)


func owner_slot() -> int:
	if altar != null:
		return altar.owner_slot
	return building.owner_slot if building != null else 0


func center() -> Vector3:
	return global_position


## Standing: a collapsing or destroyed altar is not a place for rituals.
func is_standing() -> bool:
	if altar != null:
		return altar.is_standing()
	return (
		building != null
		and is_instance_valid(building)
		and not building.is_destroyed()
		and not building.is_queued_for_deletion()
	)


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
