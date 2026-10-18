extends Node

## The game's types (creatures, spells, wizards, abilities, god books), read from data/catalog/game_catalog.tres
## (RFC-036 036c). The types are shared Resources: read them, never write them. Edit them in the inspector.

const _CREATURE_TYPE := preload("res://scenes/data/creature_type.gd")
const _SPELL_TYPE := preload("res://scenes/data/spell_type.gd")
const _ABILITY_TYPE := preload("res://scenes/data/ability_type.gd")
const _WIZARD_TYPE := preload("res://scenes/data/wizard_type.gd")

const GODS: PackedStringArray = ["persephone", "pyro", "james", "stratos", "charnel"]

var _creatures: Dictionary = {}
var _spells: Dictionary = {}
var _abilities: Dictionary = {}
var _wizards: Array = []
var _wizards_by_tag: Dictionary = {}
var _books: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	_creatures.clear()
	_spells.clear()
	_abilities.clear()
	_wizards.clear()
	_wizards_by_tag.clear()
	_books.clear()
	var catalog := GameCatalog.shared()
	if catalog == null or catalog.creatures.is_empty() or catalog.spells.is_empty() or catalog.wizards.is_empty() or catalog.books.is_empty():
		print("GameData: falta %s. Corré tools/bake_catalog.gd." % GameCatalog.PATH)
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
	_books = catalog.books


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


func gods() -> PackedStringArray:
	return GODS


## The god's book up to a wizard level, like sacengine `getSpells` (state.d:29512): entries of a higher
## level are left out. The default 1 is the book the game has used so far (F112). A book without
## "levels" (an older cache) gives every entry.
func book(god: String, max_level := 1) -> Dictionary:
	var creatures: Array[_CREATURE_TYPE] = []
	var spells: Array[_SPELL_TYPE] = []
	var structures: Array[_SPELL_TYPE] = []
	var entry: Dictionary = _books.get(god, {})
	var levels: Dictionary = entry.get("levels", {})
	for tag in entry.get("creatures", []):
		if _creatures.has(tag) and int(levels.get(tag, 0)) <= max_level:
			creatures.append(_creatures[tag])
	for tag in entry.get("spells", []):
		if _spells.has(tag) and int(levels.get(tag, 0)) <= max_level:
			spells.append(_spells[tag])
	for tag in entry.get("structures", []):
		if _spells.has(tag) and int(levels.get(tag, 0)) <= max_level:
			structures.append(_spells[tag])
	return {"creatures": creatures, "spells": spells, "structures": structures}


## Wizard level at which `tag` enters the god's book (computeDefaultSpells), or -1 if it is not in it.
func creature_level(god: String, tag: String) -> int:
	var levels: Dictionary = _books.get(god, {}).get("levels", {})
	return int(levels.get(tag, -1))
