@tool
class_name BuildingType
extends Resource

## What a building of the map is: the name its panel shows, how much it takes to destroy it, whether peasants hide in it
## and the scene with its parts. One .tres per building in data/buildings/. Never changed while playing: the health lives
## in the building's Health node. Does not place anything: MapBuilding does.

## The name the info panel shows («Casa», «Lápida»). Empty: the generic «Edificio».
@export var display_name := ""
## 0 = cannot be destroyed.
@export_range(0.0, 20000.0, 1.0, "or_greater") var max_health := 0.0
## Peasants run to it when they are scared.
@export var shelters_peasants := false
## The land is changed under it and it has no body of its own (no collision, not a target).
@export var flattens_ground := false
## A Node3D with the parts (BodyVisual under a placed Node3D), a Footprint and, unless it flattens the ground, a VegetationClear.
@export var scene: PackedScene
## What stays when it falls: the destroyed models, placed like the parts. Empty: nothing.
@export var ruin_scene: PackedScene
## The id the network and the old maps use (jhut, jwg1). Derived: not edited by hand.
@export var tag := ""


func _validate_property(property: Dictionary) -> void:
	if property.name == "tag":
		property.usage |= PROPERTY_USAGE_READ_ONLY


## The model of the first part (the base of a fountain). "" when there is no scene.
func base_model() -> String:
	if scene == null:
		return ""
	var top := scene.instantiate()
	var model := ""
	for part in top.get_children():
		for child in part.get_children():
			if child is BodyVisual and model.is_empty():
				model = (child as BodyVisual).model
	top.free()
	return model
