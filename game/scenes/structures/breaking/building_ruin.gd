@tool
class_name BuildingRuin
extends Node3D

## What stays of its building when it falls, on every peer: the parts under `Visuals` hide and
## `type.ruin_scene` (if the BuildingType has one) appears as a normal child of this node, at the
## building's place. A peer that joins late sees it too. Does not decide the fall (MapBuilding) nor
## burst (StructureBreak). Take the node out: the building stays whole when it falls.

## The building whose ruin this shows (the root of map_building.tscn); this node sits at its origin.
@export var building: MapBuilding:
	set(value):
		building = value
		update_configuration_warnings()

## The ruin it added, or null while the building stands (or has no ruin).
var ruin: Node


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if building != null
		else PackedStringArray(["Assign `building` (the MapBuilding root)."])
	)


func _ready() -> void:
	if Engine.is_editor_hint() or building == null:
		return
	building.destroyed.connect(_on_destroyed)


func _on_destroyed(_building: MapBuilding) -> void:
	if building.visuals != null:
		building.visuals.visible = false
	var type := building.type
	if ruin != null or type == null or type.ruin_scene == null:
		return
	ruin = type.ruin_scene.instantiate()
	add_child(ruin)
