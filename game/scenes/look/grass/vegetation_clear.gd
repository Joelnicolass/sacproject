@tool
class_name VegetationClear
extends GrassClear3D

## A clearing for all the vegetation: no grass (GrassKit reads every GrassClear3D) and no plants
## inside `radius`, growing back over `soft`. Put one anywhere in the map scene; altars and
## fountains are cleared by group on the grass field. The flora reads it live, also in the editor.
## Presentation only: it has no effect in a dedicated or headless process.

## The flora reads its clearings from this group (GrassClear3D.GROUP is the grass's).
const CLEAR_GROUP := &"vegetation_clear"
## Every FloraField joins it and answers `clears_changed()`.
const FIELD_GROUP := &"vegetation_field"


func _enter_tree() -> void:
	super._enter_tree()
	add_to_group(CLEAR_GROUP)
	set_notify_transform(true)
	if not changed.is_connected(_notify_changed):
		changed.connect(_notify_changed)
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


## Every clear of the tree in world coordinates (rows x, z, radius, soft): what a patch of plants
## avoids.
static func world_rows(tree: SceneTree) -> PackedVector4Array:
	var found := PackedVector4Array()
	for node in tree.get_nodes_in_group(CLEAR_GROUP):
		var clear := node as VegetationClear
		if clear and clear.is_inside_tree() and clear.radius > 0.0:
			found.append(
				Vector4(clear.global_position.x, clear.global_position.z, clear.radius, clear.soft)
			)
	return found
