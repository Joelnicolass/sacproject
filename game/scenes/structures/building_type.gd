@tool
class_name BuildingType
extends Resource

## A BLDG of the original (RFC-036 036c): what a map building is made of and how much it takes to destroy it.
## Baked once by tools/bake/bake_catalog.gd into data/catalog/buildings/<tag>.tres; MapBuilding reads it through GameCatalog.
## Never mutated at runtime: HP lives in the building's Health node.

@export var tag := ""
@export var flags := 0
## Peasants shelter in it (bit 15).
@export var shelter := false
## The land is changed under it and it has no body of its own.
@export var ground := false
## 0 = indestructible.
@export var max_health := 0.0
@export var tileset := ""
@export var folder := ""
## One row per model: kind, tag, destroyed, x, y, z, facing, spell.
@export var components: Array[Dictionary] = []


## The record shape MapBuilding has always read (numbers as floats, like the JSON parser gave them).
func to_record() -> Dictionary:
	var rows: Array = []
	for component in components:
		rows.append(component.duplicate(true))
	return {
		"flags": float(flags),
		"shelter": shelter,
		"ground": ground,
		"max_health": max_health,
		"tileset": tileset,
		"folder": folder,
		"components": rows,
	}
