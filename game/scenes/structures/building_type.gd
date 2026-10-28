@tool
class_name BuildingType
extends Resource

## What a building of the map is: the name its panel shows, how much it takes to destroy it, whether peasants hide in it
## and what stays when it falls. One .tres per building in data/buildings/; the building you drag into a map is a scene of
## scenes/structures/buildings/ whose MapBuilding root points here through `type`. Never changed while playing: the health
## lives in the building's Health node. Does not place anything: MapBuilding does.

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

