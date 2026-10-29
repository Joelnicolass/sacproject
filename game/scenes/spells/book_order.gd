class_name BookOrder
extends RefCounted

## Where an entry of a wizard's book stands: its level and its place among the entries of that
## level. The entry is a CreatureType or a SpellType (each keeps `book_level` and `book_slot` as
## fields). It does NOT sort anything: Spellbook sorts, CastTime reads the level.


## level * 100 + position, the number the book is sorted by (0 for anything that is not a book
## entry).
static func key(entry: Resource) -> int:
	if entry is CreatureType:
		return (entry as CreatureType).order_key()
	if entry is SpellType:
		return (entry as SpellType).order_key()
	return 0


## The wizard level the entry is meant for (0 for anything that is not a book entry).
static func level(entry: Resource) -> int:
	if entry is CreatureType:
		return (entry as CreatureType).book_level
	if entry is SpellType:
		return (entry as SpellType).book_level
	return 0
