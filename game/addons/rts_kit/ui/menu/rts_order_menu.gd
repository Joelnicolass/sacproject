@tool
class_name RtsOrderMenu
extends Control

## The contract of a menu that opens at a point of the world (a radial menu, a game's own list): the
## order button (RtsOrderButton) opens it where a hold started, feeds it the pointer and ends it, and
## runs the entry it chose at that point. Extend it and override the five methods; RtsRadialMenu is
## the kit's one. With no menu at all the order button is a plain right click.

## The pointer was released on `entry` and the menu closed.
signal entry_chosen(entry: RtsMenuEntry)
## The menu closed on nothing.
signal cancelled

## Seconds the order button (or the menu key) is held before the menu opens.
@export var hold_s := 0.25


## Opens at `screen` (pixels). `context` is what a right click would order there (RtsOrderInput.
## context_kind: `ground`, `enemy`, `own`…), for a menu that shows it.
func open_at(_screen: Vector2, _context: StringName) -> void:
	pass


## The pointer is at `screen`: highlight what it is on and return it (null: nothing).
func point_at(_screen: Vector2) -> RtsMenuEntry:
	return null


## Ends the menu where the pointer is: `entry_chosen` or `cancelled`. Returns the entry chosen.
func confirm() -> RtsMenuEntry:
	return null


func cancel() -> void:
	pass


func is_open() -> bool:
	return false
