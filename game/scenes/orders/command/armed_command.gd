class_name ArmedCommand
extends Node

## What waits for the next left click: a spell, a structure, an ability or an order icon (`mode`, in
## the words %Battle uses for `armed`), with the index or tag it was armed with, and the local
## wizard's Caster whose answers end the wait. Arming and clearing live here; each kind of command
## reads the state and applies its own click. Disarming (`mode = ""`) also clears %Battle, so the
## cursor icon goes away with it. An armed spell or ability stays armed after a refused click, as in
## the original.

const _WORLD := preload("res://scenes/match/match_world.gd")

@export var feedback: CommandFeedback

## "", "spell", "structure", "ability", "attack", "guard" or "move".
var mode := "":
	set(value):
		mode = value
		if value.is_empty():
			_log.disarm()
var spell_index := -1
var structure_index := -1
## Name the caster answers once the armed spell starts; until then it stays armed.
var cast_pending := ""
var ability: AbilityType
var caster: Caster

@onready var _log: CommandLog = %Battle
@onready var _selection: RtsSelection = %Selection


func _ready() -> void:
	var world := owner as _WORLD
	if world:
		world.local_wizard_changed.connect(_on_local_wizard)
		_on_local_wizard(world.local_wizard())


func is_armed() -> bool:
	return not mode.is_empty()


## A right click drops an armed icon instead of ordering. True when it did.
func cancel() -> bool:
	if mode.is_empty():
		return false
	mode = ""
	feedback.on_selection_changed(_selection.units())
	return true


## Ctrl+R / Ctrl+A only arm while no other icon waits (mouse.status == standard). The radial menu
## passes `replace`: its choice wins over what was armed. `kind` is "attack", "guard" or "move".
func arm_order(kind: String, replace := false) -> void:
	if not mode.is_empty():
		if not replace:
			return
		mode = ""
	mode = kind
	_log.arm(kind, _order_icon(kind), TargetProbe.ORDER_TARGETS)


## The picture of an armed order on the cursor: attack, guard, move… (CueSet.aim_icons).
func _order_icon(kind: String) -> Texture2D:
	var cues: CueSet = _log.cues
	return cues.aim_icon(kind) if cues else null


func _on_local_wizard(wizard: Node3D) -> void:
	var next := wizard.get_node_or_null("Caster") as Caster if wizard else null
	if next == caster:
		return
	if caster and is_instance_valid(caster):
		caster.feedback.disconnect(_on_feedback)
	caster = next
	if caster:
		caster.feedback.connect(_on_feedback)


func _on_feedback(text: String) -> void:
	# The answer to the pending cast is the one that is not a refusal (by key, never by the spell's
	# words).
	if (
		(mode == "spell" or mode == "structure")
		and not cast_pending.is_empty()
		and not _log.is_reason(text)
	):
		mode = ""
		cast_pending = ""
	_log.say(text)
