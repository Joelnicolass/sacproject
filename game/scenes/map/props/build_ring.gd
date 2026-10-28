@tool
class_name BuildRing
extends MeshInstance3D

## The ring on the ground that shows the area a structure spell clears around a manafount: green when the tower can rise there,
## red when the cast would be refused, hidden otherwise. The editor always shows it (green) so the area can be seen while it
## is moved; in the game it stays hidden until a preview asks for it. Presentation only: it reads nothing of the match.
## Does not decide the state (ArmedPreview, through BuildArea) nor the radius (BuildArea calls `set_radius`).
## The mesh is a 2 x 2 PlaneMesh: the node's scale is the radius. Without `material_override` it takes build_ring_material.tres.

enum State { HIDDEN, OK, BLOCKED }

const _MATERIAL := preload("res://scenes/map/props/build_ring_material.tres")

## Colours and line width (data/ui/build_area_look.tres).
@export var look: BuildAreaLook:
	set(value):
		if look != null and look.changed.is_connected(_paint):
			look.changed.disconnect(_paint)
		look = value
		if look != null:
			look.changed.connect(_paint)
		if is_node_ready():
			_paint()
		update_configuration_warnings()

## What the ring shows now (a flow reads it).
var state := State.HIDDEN


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if look == null:
		warnings.append("Assign `look` (data/ui/build_area_look.tres).")
	if not mesh is PlaneMesh:
		warnings.append("The ring needs a 2 x 2 m PlaneMesh: the node's scale is the radius.")
	return warnings


func _ready() -> void:
	if material_override == null:
		material_override = _MATERIAL
	show_state(State.OK if Engine.is_editor_hint() else State.HIDDEN)


func show_state(next: State) -> void:
	state = next
	visible = next != State.HIDDEN
	_paint()


## The radius of the area in metres (the mesh is 2 m wide, so the scale is the radius).
func set_radius(radius_m: float) -> void:
	var r := maxf(radius_m, 0.01)
	scale = Vector3(r, 1.0, r)


func _paint() -> void:
	if look == null:
		return
	set_instance_shader_parameter(
		&"ring_color", look.blocked_color if state == State.BLOCKED else look.ok_color
	)
	set_instance_shader_parameter(&"width_m", look.width_m)
