@tool
class_name GameCatalog
extends Resource

## The game's catalog (RFC-040 040a): every type of data/catalog/<folder>/<tag>.tres, discovered by scanning the folders.
## There is nothing to register: drop a .tres in a folder and it is in the game. The files are the only source of truth;
## this class holds no copy of them. Lists are sorted by tag so the order never depends on the file system.
## Types are read-only at runtime.

const DIR := "res://data/catalog/"

var creatures: Array[CreatureType] = []
var spells: Array[SpellType] = []
var wizards: Array[WizardType] = []
var abilities: Array[AbilityType] = []
var buildings: Array[BuildingType] = []
## Bodies and props together; `BodySize.is_prop` tells them apart.
var body_sizes: Array[BodySize] = []
## god -> {creatures, spells, structures, levels}, from data/catalog/books.tres.
var books: Dictionary = {}

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
	body_sizes.assign(_load_folder("body_sizes", BodySize, reload_from_disk))
	books = {}
	if ResourceLoader.exists(GodBooks.PATH):
		var file := ResourceLoader.load(GodBooks.PATH, "", ResourceLoader.CACHE_MODE_REPLACE if reload_from_disk else ResourceLoader.CACHE_MODE_REUSE) as GodBooks
		if file:
			books = file.books


## The .tres file names (with extension) of a catalog folder, sorted.
static func files_in(folder: String) -> PackedStringArray:
	var names := PackedStringArray()
	for entry in ResourceLoader.list_directory(DIR + folder + "/"):
		if entry.ends_with(".tres"):
			names.append(entry)
	names.sort()
	return names


func _load_folder(folder: String, script: Script, reload_from_disk: bool) -> Array:
	var mode := ResourceLoader.CACHE_MODE_REPLACE if reload_from_disk else ResourceLoader.CACHE_MODE_REUSE
	var found: Array = []
	for file in files_in(folder):
		var type := ResourceLoader.load(DIR + folder + "/" + file, "", mode)
		if type == null or type.get_script() != script:
			push_warning("GameCatalog: %s/%s is not a %s; skipped." % [folder, file, script.get_global_name()])
			continue
		found.append(type)
	found.sort_custom(func(a: Resource, b: Resource) -> bool: return a.tag < b.tag)
	return found
