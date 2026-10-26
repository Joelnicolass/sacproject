@tool
class_name BuildingType
extends Resource

## What a building of the map is: the name its panel shows, how much it takes to destroy it, whether peasants hide in it
## and what stays when it falls. One .tres per building in data/buildings/; the scene with the same name in
## scenes/structures/buildings/ is the building you drag into a map. Never changed while playing: the health lives in the
## building's Health node. Does not place anything: MapBuilding does.

## What the building does in the game: nothing (scenery), a Manalith (feeds mana, the Manahoar use it) or a Shrine (feeds
## less mana, takes Convert rituals). Code that needs the difference asks this, never the tag.
enum Role { SCENERY, MANALITH, SHRINE }

## The name the info panel shows («Casa», «Lápida»). Empty: the generic «Edificio».
@export var display_name := ""
## Manalith or Shrine for the ten towers a wizard can cast; every other building is scenery.
@export var role := Role.SCENERY
## 0 = cannot be destroyed.
@export_range(0.0, 20000.0, 1.0, "or_greater") var max_health := 0.0
## Peasants run to it when they are scared.
@export var shelters_peasants := false
## The land is changed under it and it has no box body (not a target); a tree's `trunk` (MapBuilding) still stops bodies.
@export var flattens_ground := false
## What stays when it falls: the destroyed models, placed like the parts. Empty: nothing.
@export var ruin_scene: PackedScene
## The id the network and the old maps use (jhut, jwg1). Derived: not edited by hand.
@export var tag := ""


func _validate_property(property: Dictionary) -> void:
	if property.name == "tag":
		property.usage |= PROPERTY_USAGE_READ_ONLY


## The building scene to drag into a map: scenes/structures/buildings/<this file's name>.tscn (its root is a MapBuilding
## whose `type` is this resource). Null when there is none. For code that spawns a building by type (debug, tools).
func scene() -> PackedScene:
	var path := "res://scenes/structures/buildings/%s.tscn" % resource_path.get_file().get_basename()
	return load(path) as PackedScene if ResourceLoader.exists(path) else null


## The mesh of the first part (the base of a fountain). Null when there is no scene.
func base_mesh() -> Mesh:
	var packed := scene()
	if packed == null:
		return null
	var top := packed.instantiate() as MapBuilding
	var found: Mesh = null
	if top != null and top.visuals != null:
		for part in top.visuals.get_children():
			for child in part.get_children():
				if child is MeshInstance3D and found == null:
					found = (child as MeshInstance3D).mesh
	if top != null:
		top.free()
	return found
