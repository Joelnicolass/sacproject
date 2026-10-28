class_name PlaceWarnings
extends RefCounted

## The editor warnings every "places" frame shares: a shape that is missing or is not a sphere or cylinder, an Area3D that is still
## alive (an active one would move the simulation) and a marker that is missing. The texts are the ones the sacrifice frame always gave.
## What it does not do: read a SceneState (SceneStateReader), hold the sockets or know what a place means.


## Warnings for the shapes (by socket name) and markers (by socket name) of a frame; empty when it is complete.
static func check(
	shapes: Dictionary[String, CollisionShape3D], marks: Dictionary[String, Marker3D]
) -> PackedStringArray:
	var warnings := PackedStringArray()
	for prop: String in shapes:
		var node := shapes[prop]
		if node == null or node.shape == null:
			warnings.append("`%s` is missing (a CollisionShape3D with its shape)." % prop)
			continue
		if not (node.shape is SphereShape3D or node.shape is CylinderShape3D):
			warnings.append("`%s` must hold a sphere or a cylinder." % prop)
		var area := node.get_parent() as Area3D
		if (
			area != null
			and (area.monitoring or area.collision_layer != 0 or area.collision_mask != 0)
		):
			warnings.append(
				"The Area3D of `%s` must be off (monitoring off, layer and mask 0)." % prop
			)
	for prop: String in marks:
		if marks[prop] == null:
			warnings.append("`%s` is missing (Marker3D)." % prop)
	return warnings
