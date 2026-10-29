@tool
class_name BookUnlock
extends Resource

## One line of a god's book: a creature or a spell and the wizard level at which it enters the book
##. Level 0 is there from the start.

@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "CreatureType,SpellType") var type: Resource
@export_range(0, 9) var level: int = 0


## Tag of the creature or spell; empty when the slot is empty.
func tag() -> String:
	return str(type.get("tag")) if type != null else ""
