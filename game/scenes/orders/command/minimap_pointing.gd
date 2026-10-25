class_name MinimapPointing
extends Node

## RFC-037 037c: the minimap is another surface to point at. It only gives a ground point (no ray): a right click orders
## the selection there (or drops an armed icon), a left click with an icon armed aims it there (a body near the point, else
## the spot). A left click with nothing armed does nothing (P2): the original keeps the camera on the wizard and has no
## box here.

## The minimap that gives the points. Empty (the minimap was removed): this does nothing.
@export var minimap: Minimap
@export var armed: ArmedCommand
@export var ray: PointerRay
@export var spells: SpellCommand
@export var abilities: AbilityCommand
@export var orders: OrderCommand


func _ready() -> void:
	if minimap != null:
		minimap.ground_pointed.connect(_on_pointed)


func _on_pointed(point: Vector3, button: int) -> void:
	if CommandInput.blocked(self):
		return
	if button == MOUSE_BUTTON_RIGHT:
		if not armed.cancel():
			orders.order("move", point, null)
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	match armed.mode:
		"spell":
			spells.cast_on(ray.body_near(point), point)
		"structure":
			spells.structure_at_point(point)
		"ability":
			abilities.click_on(ray.body_near(point), point)
		"attack", "guard", "move":
			orders.icon_on(ray.body_near(point), point)
