@tool
class_name GrassClear3D
extends Node3D

## No grass around this node: none within `radius`, thinning out up to `radius + soft`. Place it
## by hand where a clearing goes (a path's turn, a camp); the editor draws its circles. For
## clearings around the game's own nodes, use a GrassClearing (by group) on the field instead.

const GROUP := &"grass_clear_3d"

## `radius` or `soft` changed (in the inspector, by its handles, or from code): anything else that
## follows the clearing (the game's own flora) can listen to it.
signal changed

@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m") var radius := 3.0:
	set(value):
		radius = value
		update_gizmos()
		changed.emit()
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m") var soft := 1.5:
	set(value):
		soft = value
		update_gizmos()
		changed.emit()


func _enter_tree() -> void:
	add_to_group(GROUP)
