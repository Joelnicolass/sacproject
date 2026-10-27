class_name MinimapPointing
extends Node

## The minimap is another surface to point at. It only gives a ground point (no ray): `order_units` orders the selection
## there (or drops an armed icon), `select` with an icon armed aims it there (a body near the point, else the spot).
## `select` with nothing armed does nothing: the camera stays on the wizard and there is no box here.
## Ref: RFC-037 037c (P2).

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


func _on_pointed(point: Vector3, action: StringName) -> void:
	if CommandInput.blocked(self):
		return
	if action == &"order_units":
		if not armed.cancel():
			orders.order("move", point, null)
		return
	if action != &"select":
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
