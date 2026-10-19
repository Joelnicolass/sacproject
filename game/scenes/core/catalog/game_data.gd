extends Node

## The game's types (creatures, spells, wizards, abilities, god books), read from the files of data/catalog/
## through GameCatalog (RFC-040). The types are shared Resources: read them, never write them. Edit the .tres in the inspector.

const _CREATURE_TYPE := preload("res://scenes/units/creature_type.gd")
const _SPELL_TYPE := preload("res://scenes/data/spell_type.gd")
const _ABILITY_TYPE := preload("res://scenes/units/abilities/ability_type.gd")
const _WIZARD_TYPE := preload("res://scenes/data/wizard_type.gd")

var _creatures: Dictionary = {}
var _spells: Dictionary = {}
var _abilities: Dictionary = {}
var _wizards: Array = []
var _wizards_by_tag: Dictionary = {}
var _gods: Array[GodType] = []
var _gods_by_tag: Dictionary = {}
var _god_tags := PackedStringArray()


func _ready() -> void:
	reload()


## Rebuilds the lookups from the catalog; `from_disk` rescans the folders and rereads the files first.
func reload(from_disk := false) -> void:
	_creatures.clear()
	_spells.clear()
	_abilities.clear()
	_wizards.clear()
	_wizards_by_tag.clear()
	_gods.clear()
	_gods_by_tag.clear()
	_god_tags = PackedStringArray()
	var catalog := GameCatalog.shared(from_disk)
	if catalog.creatures.is_empty() or catalog.spells.is_empty() or catalog.wizards.is_empty() or catalog.gods.is_empty():
		print("GameData: data/catalog/ está vacío o incompleto. Corré tools/bake_catalog.gd.")
		return
	for type in catalog.creatures:
		_creatures[type.tag] = type
	for type in catalog.spells:
		_spells[type.tag] = type
	for type in catalog.abilities:
		_abilities[type.tag] = type
	for type in catalog.wizards:
		_wizards.append(type)
		_wizards_by_tag[type.tag] = type
	for type in catalog.gods:
		_gods.append(type)
		_gods_by_tag[type.tag] = type
		_god_tags.append(type.tag)


func is_loaded() -> bool:
	return not _creatures.is_empty()


func all_creatures() -> Array:
	return _creatures.values()


func creature(tag: String) -> _CREATURE_TYPE:
	return _creatures.get(tag)


func spell(tag: String) -> _SPELL_TYPE:
	return _spells.get(tag)


func ability(tag: String) -> _ABILITY_TYPE:
	return _abilities.get(tag)


func wizard(tag: String) -> _WIZARD_TYPE:
	return _wizards_by_tag.get(tag)


func wizards() -> Array:
	return _wizards.duplicate()


## The tags of the gods, in the order of data/gods/ (sort_order, then tag).
func gods() -> PackedStringArray:
	return _god_tags


func god(tag: String) -> GodType:
	return _gods_by_tag.get(tag)


## The god's book up to a wizard level, like sacengine `getSpells` (state.d:29512): entries of a higher
## level are left out. The default 1 is the book the game has used so far (F112).
func book(god_tag: String, max_level := 1) -> Dictionary:
	var type: GodType = _gods_by_tag.get(god_tag)
	if type == null or type.book == null:
		return {"creatures": [] as Array[_CREATURE_TYPE], "spells": [] as Array[_SPELL_TYPE], "structures": [] as Array[_SPELL_TYPE]}
	return type.book.up_to(max_level)


## Wizard level at which `tag` enters the god's book (computeDefaultSpells), or -1 if it is not in it.
func creature_level(god_tag: String, tag: String) -> int:
	var type: GodType = _gods_by_tag.get(god_tag)
	return type.book.level_of(tag) if type != null and type.book != null else -1
