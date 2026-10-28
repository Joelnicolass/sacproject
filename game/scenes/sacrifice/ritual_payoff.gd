@tool
class_name RitualPayoff
extends Node

## What a completed ritual gives: the creature disintegrates in blood and its souls go to the caster's purse (a conversion also
## announces them). What it does not do: end the ritual or free the doctors (Ritual does, right after). Take this node out and a
## completed ritual pays nothing and leaves the creature alone.
## Ref: sacengine state.d:8341-8350, 16020-16041.

@export var ritual: Ritual


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if ritual == null:
		warnings.append("Asigná en `ritual` el Ritual que paga.")
	return warnings


func pay() -> void:
	var creature := ritual.creature
	if is_instance_valid(creature):
		if ritual.fx != null:
			ritual.fx.splash_blood(creature.global_position)
		var caster := _wizard_of(ritual.caster_slot)
		var purse := caster.get_node_or_null("SoulPurse") as SoulPurse if caster else null
		if purse != null:
			if ritual.type().counts_as_conversion:
				var system := _system()
				if system != null:
					system.announce_conversion(ritual.caster_slot, ritual.souls, creature)
			purse.add(ritual.souls)
		_free(creature)
	if DebugLog.on(&"ritual"): print("ritual: completo, %d almas para el slot %d (altar del slot %d)" % [ritual.souls, ritual.caster_slot, ritual.target_slot])


## A hanging rag doll is handed back to its clips before the body goes (a body that simulates is never freed with `free()`).
func _free(creature: UnitBody) -> void:
	for node in creature.find_children("*", "RagdollDriver", true, false):
		var driver := node as RagdollDriver
		if driver != null and driver.pose() != RagdollDriver.Pose.OFF:
			driver.set_pose(RagdollDriver.Pose.OFF)
	creature.queue_free()


func _system() -> SacrificeSystem:
	if ritual.system != null and is_instance_valid(ritual.system):
		return ritual.system
	return get_tree().get_first_node_in_group(SacrificeSystem.GROUP) as SacrificeSystem


func _wizard_of(slot: int) -> WizardBody:
	for node in get_tree().get_nodes_in_group(WizardBody.GROUP):
		var wizard := node as WizardBody
		if wizard != null and wizard.owner_slot == slot:
			return wizard
	return null
