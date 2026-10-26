@tool
class_name GodType
extends Resource

## A god (RFC-042 042a): everything the game knows about one, in one file `data/gods/<tag>.tres`. Adding a god is adding
## that file; no code lists the gods. Read-only at runtime, like the other types.
## The book, the look and the casting particle sit in the file as references (how the AI plays is its seat's, not the god's).

@export var tag: String = ""
@export var display_name: String = ""
## Gods are listed by `sort_order`, then tag. The order is part of the rules: the biome draw and the AI's god draw index into it, so never renumber an existing god.
@export var sort_order: int = 0
## The land the god brings to a match: sky, fog, light, glow, ground and grass (`data/look/<tag>.tres`).
@export var look: LookProfile
## The particle its wizard's hands throw while he casts (data/fx/cast_<tag>.tres). Empty: the god casts without one (the pose
## still plays). A spell with its own (SpellAction.cast_fx) wins.
@export var cast_fx: ParticleType
@export var book: GodBook
## The towers this god raises: one row per structure spell (Manalith, Shrine) with the scene of its own model.
@export var structures: Array[GodStructure] = []
## Lobby (055i-a): false takes this god out of the menu, the AI picker and the rooms without deleting the file.
@export var offered := true


## The id of this god on the network and in the catalog: its `tag`, or the file name when the tag is empty (new content).
func id() -> String:
	return tag if not tag.is_empty() else resource_path.get_file().get_basename()


## The row of `spell` in this god's structures, or null when the god does not raise it.
func structure_for(spell: SpellType) -> GodStructure:
	for entry in structures:
		if entry != null and entry.spell == spell:
			return entry
	return null
