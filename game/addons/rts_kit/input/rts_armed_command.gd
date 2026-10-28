class_name RtsArmedCommand
extends Node

## What waits for the next left click: a command of the catalog (an order that aims: attack, guard,
## move…) or anything a game arms (a spell, a building to place) with what it was armed with
## (`payload`). Arming and clearing live here and mirror into RtsCommandState, so the cursor icon comes
## and goes with it. A command goes to RtsOrderInput on the click; any other mode to the game
## (RtsSelectInput.armed_clicked).

## Where an armed order may land (RtsTargetProbe classes): anything but the sky.
const ORDER_TARGETS: PackedStringArray = [
	"ground", "own_unit", "ally_unit", "neutral_unit", "enemy_unit", "other"
]

@export var state: RtsCommandState
## The commands that arm as orders (the same catalog RtsOrders uses).
@export var commands: RtsCommandCatalog = preload("res://addons/rts_kit/commands/commands.tres")
## The pictures of armed orders (RtsCueSet.aim_icons); empty: the state's own cues.
@export var cues: RtsCueSet

## &"" = nothing armed.
var mode: StringName = &"":
	set(value):
		mode = value
		if value == &"":
			payload = null
			if state:
				state.disarm()
## What the game armed it with (a spell index, a building type). The kit never reads it.
var payload: Variant


func is_armed() -> bool:
	return mode != &""


## True when what is armed is a command of the catalog (the kit applies its click).
func is_order() -> bool:
	return mode != &"" and commands != null and commands.has_id(mode)


## A right click drops what is armed instead of ordering. True when it did.
func cancel() -> bool:
	if mode == &"":
		return false
	mode = &""
	return true


## Arms command `id` of the catalog for the next left click. It only arms while nothing else waits,
## unless `replace` (a menu's or a button's choice wins). False for an id the catalog lacks.
func arm_order(id: StringName, replace := false) -> bool:
	if commands == null or not commands.has_id(id):
		return false
	var type := commands.find(id)
	return arm(id, null, ORDER_TARGETS, replace, type.icon)


## Arms `kind` for the next left click with `value` as its payload. `icon` null: the cue set's
## picture for `kind`. True when it armed.
func arm(
	kind: StringName,
	value: Variant = null,
	accepts := PackedStringArray(),
	replace := false,
	icon: Texture2D = null
) -> bool:
	if kind == &"":
		return false
	if mode != &"":
		if not replace:
			return false
		mode = &""
	mode = kind
	payload = value
	if state:
		state.arm(kind, icon if icon else _icon(kind), accepts)
	return true


func _icon(kind: StringName) -> Texture2D:
	var set_ := cues if cues else (state.cues if state else null)
	return set_.aim_icon(kind) if set_ else null
