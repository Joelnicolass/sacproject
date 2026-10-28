@tool
class_name RadialEntry
extends Resource

## One choice of a radial menu. A type resource: it never changes during a match. The menu only shows it and
## says which one the pointer chose; what `action` means is decided by whoever listens (OrderRadial).

## CONTEXT: the center: releasing there cancels. ARM_ORDER: `order` is given at the point the menu opened.
## ORDER_NOW: it happens at once (retreat). FORMATION: the order of a right click at that point, in `formation`.
## ABILITY: the selection's active ability.
enum Action { CONTEXT, ARM_ORDER, ORDER_NOW, FORMATION, ABILITY }

@export var id: StringName = &""
## UI text (Spanish): the caption under the menu and the line of the log.
@export var label := ""
@export var icon: Texture2D
@export var action := Action.ARM_ORDER
## "attack", "guard", "move" (ARM_ORDER) or "retreat" (ORDER_NOW).
@export var order: StringName = &""
## FORMATION: the formation this entry stores; its name and icon are used when this entry has none.
@export var formation: FormationType


func display_label() -> String:
	if not label.is_empty() or formation == null:
		return label
	return formation.display_name


func display_icon() -> Texture2D:
	if icon != null or formation == null:
		return icon
	return formation.icon
