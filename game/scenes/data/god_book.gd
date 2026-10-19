@tool
class_name GodBook
extends Resource

## What a god's book offers (RFC-042 042a). The three lists are the book's rows in the order the game shows them; `unlocks`
## says at which wizard level each tag enters the book (a tag with no line enters at level 0). All of it points to the
## per-type files of data/catalog/, so adding a creature to a book is dropping it in a list.

@export var creatures: Array[CreatureType] = []
@export var spells: Array[SpellType] = []
## Structures (Manalith, Hut...) are spells; they are listed apart because the book's structure tab shows them.
@export var structures: Array[SpellType] = []
@export var unlocks: Array[BookUnlock] = []

var _levels: Dictionary = {}
var _levels_for := -1


## Wizard level at which `tag` enters the book, or -1 when the book has no unlock line for it.
func level_of(tag: String) -> int:
	_index_levels()
	return int(_levels.get(tag, -1))


## The book up to a wizard level, like sacengine `getSpells` (state.d:29512): rows of a higher level are left out.
## A row with no unlock line is level 0.
func up_to(max_level: int) -> Dictionary:
	var found_creatures: Array[CreatureType] = []
	for type in creatures:
		if type != null and maxi(level_of(type.tag), 0) <= max_level:
			found_creatures.append(type)
	var found_spells: Array[SpellType] = []
	for type in spells:
		if type != null and maxi(level_of(type.tag), 0) <= max_level:
			found_spells.append(type)
	var found_structures: Array[SpellType] = []
	for type in structures:
		if type != null and maxi(level_of(type.tag), 0) <= max_level:
			found_structures.append(type)
	return {"creatures": found_creatures, "spells": found_spells, "structures": found_structures}


func _index_levels() -> void:
	# Rebuilt when the number of lines changes (the inspector edits the array in place).
	if _levels_for == unlocks.size():
		return
	_levels.clear()
	for unlock in unlocks:
		if unlock != null and not unlock.tag().is_empty():
			_levels[unlock.tag()] = unlock.level
	_levels_for = unlocks.size()
