@tool
class_name VegetationClear
extends Node3D

## A clearing: no grass inside `radius_m`, growing back over `edge_m`. Put one anywhere in the
## map scene (altars and fountains get one by default from the `GrassSet`). The grass reads it
## live, also in the editor, and so does any later vegetation (dispersion, plants).
## Presentation only: it has no effect in a dedicated or headless process.

const GROUP := &"vegetation_clear"
## Every vegetation layer (GrassField, later FloraField) joins it and answers `clears_changed()` (RFC-054 054b).
const FIELD_GROUP := &"vegetation_field"

@export_range(0.0, 100.0, 0.5, "suffix:m") var radius_m := 6.0:
	set(value):
		radius_m = value
		_notify_changed()
@export_range(0.0, 50.0, 0.5, "suffix:m") var edge_m := 3.0:
	set(value):
		edge_m = value
		_notify_changed()


func _enter_tree() -> void:
	add_to_group(GROUP)
	set_notify_transform(true)
	_notify_changed()


func _exit_tree() -> void:
	# After leaving the group the layers must read the new list.
	_notify_changed.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_notify_changed()


func _notify_changed() -> void:
	if is_inside_tree():
		get_tree().call_group(FIELD_GROUP, &"clears_changed")
