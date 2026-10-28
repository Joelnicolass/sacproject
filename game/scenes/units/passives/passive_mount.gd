@tool
class_name PassiveMount
extends Node

## Where a creature keeps the passives of the body scene it wears (BodyFacts.passives, the
## `Passives` instance of that scene): mount() builds that scene, moves its nodes here and hands
## each UnitPassive the parts of the creature it works with. CreatureLink mounts it as soon as the
## type is set, before the body enters the tree, so every peer builds the same nodes. Not: what a
## passive does (each UnitPassive) nor which creature has which (its `<name>_passives.tscn`).

@export var body: UnitBody
@export var health: Health
@export var mana: ManaPool
## Who multiplies the creature's pace (the Lightning Charge speeds it up).
@export var pace: PaceFactors
## The weapons that ask the damage passive for the factor of a blow.
@export var weapons: Weapons
## The blow whose connection fires the on-hit passives (the Yeti's freeze).
@export var melee: MeleeWeapon
## The carried effect that follows the mana a Manahoar gives.
@export var creature_fx: CreatureFx

var _mounted: PackedScene


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null or health == null or mana == null or pace == null or weapons == null or melee == null:
		warnings.append("Assign body, health, mana, pace, weapons and melee.")
	return warnings


## Builds `scene` (a `<name>_passives.tscn`) here, once. The same scene again, or null, does
## nothing.
func mount(scene: PackedScene) -> void:
	if scene == null or scene == _mounted:
		return
	if _mounted != null:
		push_error("PassiveMount on '%s': already wears %s, cannot mount %s"
				% [body.name, _mounted.resource_path, scene.resource_path])
		return
	_mounted = scene
	var holder := scene.instantiate()
	for node in holder.get_children():
		holder.remove_child(node)
		node.owner = null
		add_child(node)
		var passive := node as UnitPassive
		if passive != null:
			passive.attach(self)
		else:
			push_error("PassiveMount: %s in %s is not a UnitPassive" % [node.name, scene.resource_path])
	holder.free()
