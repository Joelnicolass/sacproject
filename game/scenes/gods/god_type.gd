@tool
class_name GodType
extends Resource

## A god (RFC-042 042a): everything the game knows about one, in one file `data/gods/<tag>.tres`. Adding a god is adding
## that file; no code lists the gods. Read-only at runtime, like the other types.
## The book, the AI profile and the look sit in the file as references; the casting particle is a file path loaded when
## a match needs it.

@export var tag: String = ""
@export var display_name: String = ""
## Gods are listed by `sort_order`, then tag. The order is part of the rules: the biome draw and the AI's god draw index into it, so never renumber an existing god.
@export var sort_order: int = 0
## The land the god brings to a match: sky, fog, light, glow, ground and grass (`data/look/<tag>.tres`).
@export var look: LookProfile
## The particle of its casting hand (a ParticleType, data/fx/cast_<tag>.tres). Empty: the god casts without one.
@export_file("*.tres") var cast_fx_path: String = ""
## The AI profile of a wizard of this god; empty: the original's profile.
@export var ai_profile: AiProfile
@export var book: GodBook
## The towers this god raises: one row per structure spell (Manalith, Shrine) with the scene of its own model.
@export var structures: Array[GodStructure] = []
## Lobby (055i-a): false takes this god out of the menu, the AI picker and the rooms without deleting the file.
@export var offered := true


## The id of this god on the network and in the catalog: its `tag`, or the file name when the tag is empty (new content).
func id() -> String:
	return tag if not tag.is_empty() else resource_path.get_file().get_basename()


## Name FxBus plays for the casting hand. A god without a particle still names one (`cast_<tag>`): the wizard's pose follows it.
func cast_fx_name() -> String:
	if not cast_fx_path.is_empty():
		return cast_fx_path.get_file().get_basename()
	return "cast_%s" % tag


## The row of `spell` in this god's structures, or null when the god does not raise it.
func structure_for(spell: SpellType) -> GodStructure:
	for entry in structures:
		if entry != null and entry.spell == spell:
			return entry
	return null
