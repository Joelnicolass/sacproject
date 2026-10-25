@tool
class_name GameCatalog
extends Resource

## The game's catalog (RFC-040 040a): every type of data/catalog/<folder>/<tag>.tres, discovered by scanning the folders.
## There is nothing to register: drop a .tres in a folder and it is in the game. The files are the only source of truth;
## this class holds no copy of them. Lists are sorted by tag so the order never depends on the file system.
## Types are read-only at runtime.

const DIR := "res://data/catalog/"
const GODS_DIR := "res://data/gods/"
## Buildings are named for humans (james_hut.tres); the tag is a field inside.
const BUILDINGS_DIR := "res://data/buildings/"

var creatures: Array[CreatureType] = []
var spells: Array[SpellType] = []
var wizards: Array[WizardType] = []
var abilities: Array[AbilityType] = []
var buildings: Array[BuildingType] = []
## Tags that two building files claim (the catalog test fails on them).
var duplicate_building_tags := PackedStringArray()
var _building_by_tag: Dictionary = {}
## Bodies and props together; `BodySize.is_prop` tells them apart.
var body_sizes: Array[BodySize] = []
## The gods of data/gods/<tag>.tres (RFC-042), by sort_order then tag. Each carries its theme, look, AI profile and typed book.
var gods: Array[GodType] = []

static var _shared: GameCatalog


## The catalog, built once from the folders. `refresh` rescans and reloads the files from disk (tools, tests, the editor).
static func shared(refresh := false) -> GameCatalog:
	if _shared == null or refresh:
		_shared = GameCatalog.new()
		_shared.scan(refresh)
	return _shared


## Fills the lists from the folders. Files that are not the folder's type are skipped with a warning.
func scan(reload_from_disk := false) -> void:
	creatures.assign(_load_folder("creatures", CreatureType, reload_from_disk))
	spells.assign(_load_folder("spells", SpellType, reload_from_disk))
	wizards.assign(_load_folder("wizards", WizardType, reload_from_disk))
	abilities.assign(_load_folder("abilities", AbilityType, reload_from_disk))
	buildings.assign(_load_folder("buildings", BuildingType, reload_from_disk))
	_index_buildings()
	body_sizes.assign(_load_folder("body_sizes", BodySize, reload_from_disk))
	gods.assign(_load_gods(reload_from_disk))


## The folder of a catalog kind: data/catalog/<kind>/, except the buildings.
static func dir_of(folder: String) -> String:
	return BUILDINGS_DIR if folder == "buildings" else DIR + folder + "/"


## The .tres file names (with extension) of a catalog folder, sorted.
static func files_in(folder: String) -> PackedStringArray:
	var names := PackedStringArray()
	for entry in ResourceLoader.list_directory(dir_of(folder)):
		if entry.ends_with(".tres"):
			names.append(entry)
	names.sort()
	return names


## The building of a tag, or null.
func building(tag: String) -> BuildingType:
	return _building_by_tag.get(tag)


func _index_buildings() -> void:
	_building_by_tag.clear()
	duplicate_building_tags.clear()
	for type in buildings:
		if _building_by_tag.has(type.tag):
			duplicate_building_tags.append(type.tag)
			push_error("GameCatalog: two buildings claim the tag \"%s\" (%s and %s)." % [type.tag, _building_by_tag[type.tag].resource_path, type.resource_path])
		_building_by_tag[type.tag] = type


## The god with that id (its `tag`, or the file name when the tag is empty), or null.
func god(id: String) -> GodType:
	for type in gods:
		if type.id() == id:
			return type
	return null


## The wizard with that id (its `tag`, or the file name when the tag is empty), or null.
func wizard(id: String) -> WizardType:
	for type in wizards:
		if type.id() == id:
			return type
	return null


## The gods the menu, the AI picker and the rooms list (`offered`), in catalog order.
func offered_gods() -> Array[GodType]:
	var out: Array[GodType] = []
	for type in gods:
		if type.offered:
			out.append(type)
	return out


## The wizards the menu and the rooms list (`offered`), in catalog order.
func offered_wizards() -> Array[WizardType]:
	var out: Array[WizardType] = []
	for type in wizards:
		if type.offered:
			out.append(type)
	return out


func _load_gods(reload_from_disk: bool) -> Array:
	var mode := ResourceLoader.CACHE_MODE_REPLACE if reload_from_disk else ResourceLoader.CACHE_MODE_REUSE
	var found: Array = []
	for entry in ResourceLoader.list_directory(GODS_DIR):
		if not entry.ends_with(".tres"):
			continue
		var type := ResourceLoader.load(GODS_DIR + entry, "", mode) as GodType
		if type == null:
			push_warning("GameCatalog: gods/%s is not a GodType; skipped." % entry)
			continue
		found.append(type)
	found.sort_custom(func(a: GodType, b: GodType) -> bool:
		return a.sort_order < b.sort_order if a.sort_order != b.sort_order else a.tag < b.tag)
	return found


func _load_folder(folder: String, script: Script, reload_from_disk: bool) -> Array:
	var mode := ResourceLoader.CACHE_MODE_REPLACE if reload_from_disk else ResourceLoader.CACHE_MODE_REUSE
	var found: Array = []
	for file in files_in(folder):
		var type := ResourceLoader.load(dir_of(folder) + file, "", mode)
		if type == null or type.get_script() != script:
			push_warning("GameCatalog: %s/%s is not a %s; skipped." % [folder, file, script.get_global_name()])
			continue
		found.append(type)
	found.sort_custom(func(a: Resource, b: Resource) -> bool: return a.tag < b.tag)
	return found
