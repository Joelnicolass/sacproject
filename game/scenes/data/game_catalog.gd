@tool
class_name GameCatalog
extends Resource

## The game's catalog (RFC-036 036c): every type the original defines, as .tres under data/catalog/.
## Baked once by tools/bake_catalog.gd; the JSON files are only that tool's input. Edit a type in the inspector,
## not the list. Lists keep the order of the original data. Types are read-only at runtime.

const PATH := "res://data/catalog/game_catalog.tres"

@export var creatures: Array[CreatureType] = []
@export var spells: Array[SpellType] = []
@export var wizards: Array[WizardType] = []
@export var abilities: Array[AbilityType] = []
@export var buildings: Array[BuildingType] = []
## Bodies first, then props, in the order of the original sizes.
@export var body_sizes: Array[BodySize] = []
## god -> {creatures, spells, structures, levels}: what each god's book offers and from which wizard level.
@export var books: Dictionary = {}


## The saved catalog, null when it has not been baked. Cached by the ResourceLoader.
static func shared() -> GameCatalog:
	if not ResourceLoader.exists(PATH):
		return null
	return ResourceLoader.load(PATH) as GameCatalog
