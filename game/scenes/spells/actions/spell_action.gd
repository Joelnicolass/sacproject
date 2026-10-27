@tool
class_name SpellAction
extends Node

## Contract of a spell with its own procedure. Instanced by Caster under the wizard's `Caster/Actions`
## from `SpellType.action`; Caster finds it by `spell`, runs the common part (mana, cooldown, casting frames, drain) and asks
## the action for the rest: whether it can be armed, where it lands, what happens when the casting
## time ends and what to undo if the wizard dies midway. `pick` tells the click handler what to
## aim at, so neither Caster nor MatchCommand names a tag. Taking the child out turns the spell
## off: its icon answers «No implementado».
## Only the server (or solo) runs begin/finish/cancel. This base holds no game logic, so the editor
## can run it for the configuration warnings.
## Ref: RFC-021a

enum Pick { GROUND, OWN_UNIT, SOUL, OWN_BUILDING, SELF }

const NO_MANA := Refusal.NO_MANA
const COOLING := Refusal.COOLING
const OUT_OF_RANGE := Refusal.OUT_OF_RANGE
const BAD_TARGET := Refusal.BAD_TARGET
const NOT_IMPLEMENTED := Refusal.NOT_IMPLEMENTED
const NO_ROOM := Refusal.OCCUPIED


## Where a cast lands, or why it cannot start (`status` != "").
class Aim extends RefCounted:
	var status := ""
	var point := Vector3.ZERO
	var target: Node3D
	## Where the cast builds or lands when it is not `target` (a fount); previews draw there. Null = none.
	var site: Node3D
	## What `begin` needs from `check` (an action keeps its own keys).
	var data := {}


## The spell this action casts. Caster sets it when it instances `spell.action`; an action scene does not know its spell.
var spell: SpellType
## Network id of the spell (read only: `spell.tag`), "" before Caster sets it.
var tag: String:
	get:
		return spell.tag if spell != null else ""
## What the click aims at: the ground, an own creature, a soul or an own building. SELF aims at nothing: the cast starts on the key.
@export var pick := Pick.GROUND
## What the battle line says while the spell is armed.
@export var prompt := ""
## Particle the wizard's hands throw while he casts this spell. Empty = the one of his god (GodType.cast_fx).
@export var cast_fx: ParticleType
## The wizard neither walks nor turns while he casts it (a structure): a walk order waits for the end of the cast.
## Ref: sacspell.d:201 (a structure always casts standing), state.d:62-63, 14672 (no step while stationaryCasting).
@export var stationary := false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if prompt.is_empty():
		warnings.append("Escribí en `prompt` lo que se muestra al armar el hechizo.")
	var parent := get_parent()
	if parent != null and spell != null:
		for sibling in parent.get_children():
			if sibling != self and sibling is SpellAction and (sibling as SpellAction).spell == spell:
				warnings.append("Otra acción de `%s` lanza el mismo hechizo." % parent.name)
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


## Right after the common part started the cast (cooldown applied, `frames` of casting counted): a spell that
## launches something while it casts (Rock, Fireball, Speedup) does it here.
func started(_wizard: WizardBody, _spell: SpellType, _aim: Aim, _frames: int) -> void:
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
	if wizard.global_position.distance_to(point) > spell.cast_range_m:
		return OUT_OF_RANGE
	return ""


## The shared answer of a spell aimed at one body: funds first (cooldown, mana), then a valid body (`body`, already picked with the
## action's SpellTarget; null = not valid), then the cast range.
func aim_at_body(wizard: WizardBody, spell: SpellType, point: Vector3, funds: String, body: Node3D) -> Aim:
	var aim := Aim.new()
	aim.point = point
	if not funds.is_empty():
		aim.status = funds
		return aim
	aim.target = body
	if body == null:
		aim.status = BAD_TARGET
	elif wizard.global_position.distance_to(body.global_position) > spell.cast_range_m:
		aim.status = OUT_OF_RANGE
	return aim


## The spawner of projectiles in the world, or null.
func projectile_spawner() -> SpellSpawner:
	return get_tree().get_first_node_in_group("spell_spawner") as SpellSpawner
