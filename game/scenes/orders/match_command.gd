class_name MatchCommand
extends Node

## The player's commands in the world, as a coordinator of small children (scenes/orders/command/):
## CommandInput routes keys and the left button, MinimapPointing the minimap, ArmedCommand holds
## what waits for its target, SpellCommand / AbilityCommand / OrderCommand apply it, PointerRay
## turns pixels into bodies, GroupKeys reads the group keys and CommandFeedback pings and says. Take
## a child out and that command is gone. The right button belongs to OrderRadial: a tap calls
## `right_at`, a hold opens the radial menu, whose entries call `order_at`, `order_in_formation`,
## `retreat`, `use_ability` and `set_formation` here.
## Nothing is drawn as text: what is armed goes to %Battle (CommandLog) and CommandCue draws it on
## the cursor.

## The local player's command input (one per match).
const GROUP := &"match_command"

@export var ray: PointerRay
@export var armed: ArmedCommand
@export var orders: OrderCommand
@export var abilities: AbilityCommand


func _ready() -> void:
	add_to_group(GROUP)


## True while the world camera counts the pointer as dragged (a click that ends it is not an order).
func camera_dragged() -> bool:
	return ray.camera_dragged()


## The order of a right click at `screen` (see OrderCommand.right_at).
func right_at(screen: Vector2, from_action := false, formation_id := &"") -> void:
	orders.right_at(screen, from_action, formation_id)


## What a right click would order at `screen`: `ground`, `enemy`, `own` or `corpse`.
func context_kind(screen: Vector2) -> StringName:
	return orders.context_kind(screen)


## The radial menu chose an order entry at the point it opened on.
func order_at(kind: String, screen: Vector2) -> void:
	orders.order_at(kind, screen)


## The radial menu chose a formation at the point it opened on.
func order_in_formation(id: StringName, screen: Vector2) -> void:
	orders.order_in_formation(id, screen)


## Arms an order icon (`kind`: "attack", "guard" or "move") for the next left click; `replace` wins
## over what was armed.
func arm_order(kind: String, replace := false) -> void:
	armed.arm_order(kind, replace)


## Alt+1..8: the formation of the selection.
func set_formation(id: StringName) -> void:
	orders.set_formation(id)


## Calls every creature back to the wizard.
func retreat() -> void:
	orders.retreat()


## The selection's active ability (Ctrl+Q, the radial menu).
func use_ability() -> void:
	abilities.use()
