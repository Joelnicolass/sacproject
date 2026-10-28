@tool
class_name Wards
extends Node3D

## The one owner of «what protects this body right now»: it holds the Ward children (Life Shield, Skin of Stone, Air Shield,
## Ethereal Form, Fireform, Protective Swarm) and answers for all of them. Health asks factor() and immune(); Afflictions and
## Pull ask shielded(); a SpellAction asks ward_for(spell). It does not start a ward (the action does) nor draw one (the Ward).
## It is a Node3D (not a plain Node) so the transform of the body reaches the looks of its wards.
## `changed` fires on every peer when any ward goes on or off.

signal changed


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for ward in _wards():
		ward.shown_changed.connect(func(_on: bool) -> void: changed.emit())


## The Wards of `node`, or null (a body without one is never warded).
static func of(node: Node) -> Wards:
	return (node.get_node_or_null("Wards") as Wards) if node else null


## The ward the spell starts, or null.
func ward_for(spell: SpellType) -> Ward:
	if spell == null:
		return null
	for ward in _wards():
		if ward.spell != null and ward.spell.tag == spell.tag:
			return ward
	return null


## Is any ward that counts as a shield on? Freeze, Petrify and Pull refuse such a body.
func shielded() -> bool:
	for ward in _wards():
		if ward.counts_as_shield and ward.is_on():
			return true
	return false


## Is any ward on that makes the body immune to damage?
func immune() -> bool:
	for ward in _wards():
		if ward.immune and ward.is_on():
			return true
	return false


## What a hit of `kind` is multiplied by: the product of every ward that is on (1 with none).
func factor(kind: StringName) -> float:
	var result := 1.0
	for ward in _wards():
		result *= ward.factor_for(kind)
	return result


## Is a ward on that draws the body as stone (Skin of Stone)?
func stone_skin() -> bool:
	for ward in _wards():
		if ward.stone_skin and ward.is_on():
			return true
	return false


func _wards() -> Array[Ward]:
	var result: Array[Ward] = []
	for child in get_children():
		if child is Ward:
			result.append(child)
	return result
