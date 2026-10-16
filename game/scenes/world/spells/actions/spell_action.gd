@tool
class_name SpellAction
extends Node

## Contract of a spell with its own procedure (RFC-021a). A child of the wizard's `Caster/Actions`;
## Caster finds it by `tag`, runs the common part (mana, cooldown, casting frames, drain) and asks
## the action for the rest: whether it can be armed, where it lands, what happens when the casting
## time ends and what to undo if the wizard dies midway. `pick` tells the click handler what to
## aim at, so neither Caster nor MatchCommand names a tag. Taking the child out turns the spell
## off: its icon answers «No implementado».
## Only the server (or solo) runs begin/finish/cancel. This base holds no game logic, so the editor
## can run it for the configuration warnings.

enum Pick { GROUND, OWN_UNIT, SOUL, OWN_BUILDING }

const NO_MANA := "Sin maná"
const COOLING := "Enfriando"
const OUT_OF_RANGE := "Fuera de alcance"
const BAD_TARGET := "Blanco inválido"
const NOT_IMPLEMENTED := "No implementado"
const NO_ROOM := "Sin lugar"


## Where a cast lands, or why it cannot start (`status` != "").
class Aim extends RefCounted:
	var status := ""
	var point := Vector3.ZERO
	var target: Node3D
	## What `begin` needs from `check` (an action keeps its own keys).
	var data := {}


## SpellType tag this action answers to.
@export var tag := ""
## What the click aims at: the ground, an own creature, a soul or an own building.
@export var pick := Pick.GROUND
## What the battle line says while the spell is armed.
@export var prompt := ""
## Particle (FxBus name) the wizard throws while he casts this spell. Empty = the one of his god.
@export var cast_fx := ""


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if tag.is_empty():
		warnings.append("Escribí en `tag` el tag del hechizo.")
	if prompt.is_empty():
		warnings.append("Escribí en `prompt` lo que se muestra al armar el hechizo.")
	var parent := get_parent()
	if parent != null and not tag.is_empty():
		for sibling in parent.get_children():
			if sibling != self and sibling is SpellAction and (sibling as SpellAction).tag == tag:
				warnings.append("Otra acción de `%s` usa el mismo tag." % parent.name)
				break
	return warnings


## Can the spell be armed apart from mana and cooldown? "" = yes, else the reason.
func arm_status(_wizard: WizardBody, _spell: SpellType) -> String:
	return ""


## Server or solo. `funds` is what Caster found about mana and cooldown: "", NO_MANA or COOLING
## (cooling wins). `picked` is the body the click named, or null. Returns where the cast lands,
## or the reason it cannot start.
## `picked` and `point` come from the client: validate owner, group and state here, and take the
## position from `picked` when the spell aims at a body.
func check(_wizard: WizardBody, _spell: SpellType, _point: Vector3, _picked: Node3D, _funds: String) -> Aim:
	var aim := Aim.new()
	aim.status = NOT_IMPLEMENTED
	return aim


## The cast starts (mana and cooldown are taken after this). Keep what `finish` will need.
func begin(_wizard: WizardBody, _spell: SpellType, _aim: Aim) -> void:
	pass


## The casting time ended with the wizard alive. Returns something to tell the owner, or "".
func finish(_wizard: WizardBody, _spell: SpellType, _target: Node3D) -> String:
	return ""


## The wizard died or was interrupted: forget what `begin` kept.
func cancel() -> void:
	pass


## Cooldown first, then mana, then range: the order every spell of the book answers in.
func standing_status(funds: String, wizard: WizardBody, spell: SpellType, point: Vector3) -> String:
	if funds == COOLING or funds == NO_MANA:
		return funds
	if wizard.global_position.distance_to(point) > spell.cast_range:
		return OUT_OF_RANGE
	return ""
