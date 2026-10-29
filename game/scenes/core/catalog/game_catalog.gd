@tool
class_name GameCatalog
extends Resource

## The game's catalog: every type, discovered by scanning the folders. A creature, a spell, a
## wizard and a god are each a folder, res://<kind>/<name>/<name>.tres, with everything only it
## uses.
## Shared abilities are in scenes/units/abilities/; buildings are in their god's folder
## (gods/<god>/buildings/) or, when neutral, in scenes/structures/buildings/. There is nothing to
## register: drop the file in and it is in the game. The files are the only source of truth; this
## class holds no copy of them. Lists are sorted by tag so the order never depends on the file
## system. Types are read-only at runtime.

## The kinds that are one folder per entity: res://<kind>/<name>/<name>.tres.
const ENTITY_KINDS: Array[String] = ["creatures", "spells", "wizards", "gods"]
const CREATURES_DIR := "res://creatures/"
const GODS_DIR := "res://gods/"
## Abilities two or more creatures share; one only a creature has is in its folder.
const ABILITIES_DIR := "res://scenes/units/abilities/"
## Neutral buildings; a god's own are in gods/<god>/buildings/. Named for humans (james_hut.tres);
## the tag is a field inside.
const BUILDINGS_DIR := "res://scenes/structures/buildings/"

static var _shared: GameCatalog

var creatures: Array[CreatureType] = []
var spells: Array[SpellType] = []
var wizards: Array[WizardType] = []
var abilities: Array[AbilityType] = []
var buildings: Array[BuildingType] = []
## Tags that two building files claim (the catalog test fails on them).
var duplicate_building_tags := PackedStringArray()
## The gods of gods/<tag>/<tag>.tres, by sort_order then tag. Each carries its theme, look and typed
## book.
var gods: Array[GodType] = []
## The game modes in the order the screens list them (scenes/match/modes/mode_catalog.tres).
var modes: Array[GameMode] = []

var _building_by_tag: Dictionary = {}
var _creature_by_id: Dictionary = {}
var _ability_by_tag: Dictionary[String, AbilityType] = {}


## The catalog, built once from the folders. `refresh` rescans and reloads the files from disk
## (tools, tests, the editor).
static func shared(refresh := false) -> GameCatalog:
	if _shared == null or refresh:
		_shared = GameCatalog.new()
		_shared.scan(refresh)
	return _shared


## Fills the lists from the folders. Files that are not the folder's type are skipped with a
## warning.
func scan(reload_from_disk := false) -> void:
	creatures.assign(_load_folder("creatures", CreatureType, reload_from_disk))
	_creature_by_id.clear()
	for type in creatures:
		_creature_by_id[type.id()] = type
	spells.assign(_load_folder("spells", SpellType, reload_from_disk))
	wizards.assign(_load_folder("wizards", WizardType, reload_from_disk))
	abilities.assign(_load_folder("abilities", AbilityType, reload_from_disk))
	_add_creature_abilities()
	_ability_by_tag.clear()
	for type in abilities:
		_ability_by_tag[type.tag] = type
	buildings.assign(_load_folder("buildings", BuildingType, reload_from_disk))
	_index_buildings()
	gods.assign(_load_gods(reload_from_disk))
	modes.assign(GameModeCatalog.shared().modes)


## The .tres files of a catalog kind, sorted: <kind>/<name>/<name>.tres for the entity kinds, the
## shared folder for the abilities, and the neutral folder plus every god's buildings/ for the
## buildings.
static func paths_of(folder: String) -> PackedStringArray:
	var paths := PackedStringArray()
	match folder:
		"abilities":
			paths = _tres_in(ABILITIES_DIR)
		"buildings":
			paths = _tres_in(BUILDINGS_DIR)
			for god in _entities_in(GODS_DIR):
				paths.append_array(_tres_in(god.get_base_dir() + "/buildings/"))
		_:
			if folder in ENTITY_KINDS:
				paths = _entities_in("res://%s/" % folder)
	paths.sort()
	return paths


static func _entities_in(dir: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for entry in ResourceLoader.list_directory(dir):
		if entry.ends_with("/"):
			var name := entry.trim_suffix("/")
			var path := "%s%s/%s.tres" % [dir, name, name]
			if ResourceLoader.exists(path):
				paths.append(path)
	return paths


static func _tres_in(dir: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for entry in ResourceLoader.list_directory(dir):
		if entry.ends_with(".tres"):
			paths.append(dir + entry)
	return paths


## The building of a tag, or null.
func building(tag: String) -> BuildingType:
	return _building_by_tag.get(tag)


func _index_buildings() -> void:
	_building_by_tag.clear()
	duplicate_building_tags.clear()
	for type in buildings:
		if _building_by_tag.has(type.tag):
			duplicate_building_tags.append(type.tag)
			push_error(
				(
					'GameCatalog: two buildings claim the tag "%s" (%s and %s).'
					% [type.tag, _building_by_tag[type.tag].resource_path, type.resource_path]
				)
			)
		_building_by_tag[type.tag] = type


## The creature with that id (its `tag`, or the file name when the tag is empty), or null. Indexed
## in scan().
func creature(id: String) -> CreatureType:
	return _creature_by_id.get(id)


## The ability with that tag, or null. Indexed in scan().
func ability(tag: String) -> AbilityType:
	return _ability_by_tag.get(tag)


## The god with that id (its `tag`, or the file name when the tag is empty), or null.
func god(id: String) -> GodType:
	var found := gods.filter(func(type: GodType) -> bool: return type.id() == id)
	return found[0] if not found.is_empty() else null


## The wizard with that id (its `tag`, or the file name when the tag is empty), or null.
func wizard(id: String) -> WizardType:
	var found := wizards.filter(func(type: WizardType) -> bool: return type.id() == id)
	return found[0] if not found.is_empty() else null


## Every map, the default first and the test maps last. Loads them all: ask for it from a screen,
## not from the autoload.
func maps() -> Array[MapDefinition]:
	return MapCatalog.shared().maps


## The gods the menu, the AI picker and the rooms list (`offered`), in catalog order.
func offered_gods() -> Array[GodType]:
	var out: Array[GodType] = []
	out.assign(gods.filter(func(type: GodType) -> bool: return type.offered))
	return out


## The wizards the menu and the rooms list (`offered`), in catalog order.
func offered_wizards() -> Array[WizardType]:
	var out: Array[WizardType] = []
	out.assign(wizards.filter(func(type: WizardType) -> bool: return type.offered))
	return out


func _load_gods(reload_from_disk: bool) -> Array:
	var mode := (
		ResourceLoader.CACHE_MODE_REPLACE if reload_from_disk else ResourceLoader.CACHE_MODE_REUSE
	)
	var found: Array = []
	for path in paths_of("gods"):
		var type := ResourceLoader.load(path, "", mode) as GodType
		if type == null:
			push_warning("GameCatalog: %s is not a GodType; skipped." % path)
			continue
		found.append(type)
	found.sort_custom(
		func(a: GodType, b: GodType) -> bool:
			return a.sort_order < b.sort_order if a.sort_order != b.sort_order else a.tag < b.tag
	)
	return found


func _load_folder(folder: String, script: Script, reload_from_disk: bool) -> Array:
	var mode := (
		ResourceLoader.CACHE_MODE_REPLACE if reload_from_disk else ResourceLoader.CACHE_MODE_REUSE
	)
	var found: Array = []
	for path in paths_of(folder):
		var type := ResourceLoader.load(path, "", mode)
		if type == null or type.get_script() != script:
			push_warning("GameCatalog: %s is not a %s; skipped." % [path, script.get_global_name()])
			continue
		found.append(type)
	found.sort_custom(func(a: Resource, b: Resource) -> bool: return a.tag < b.tag)
	return found


# An ability only one creature has lives in that creature's folder: it is known through the
# creature's slots. The shared ones are in scenes/units/abilities/.
func _add_creature_abilities() -> void:
	var known := {}
	for type in abilities:
		known[type.tag] = true
	for creature in creatures:
		for type in creature.abilities():
			if not known.has(type.tag):
				known[type.tag] = true
				abilities.append(type)
	abilities.sort_custom(func(a: AbilityType, b: AbilityType) -> bool: return a.tag < b.tag)
