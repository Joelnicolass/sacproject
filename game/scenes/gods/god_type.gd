@tool
class_name GodType
extends Resource

## A god (RFC-042 042a): everything the game knows about one, in one file `data/gods/<tag>.tres`. Adding a god is adding
## that file; no code lists the gods. Read-only at runtime, like the other types.
## The book, the AI profile and the look sit in the file as references; the casting particle is a file path loaded when
## a match needs it.

@export var tag: String = ""
@export var display_name: String = ""
## Gods are listed by `sort_order`, then tag. The order is part of the rules: the biome draw, the AI's god draw and
## SpellType.structures index into it, so never renumber an existing god.
@export var sort_order: int = 0
## The land the god brings to a match: sky, fog, light, glow, ground and grass (`data/look/<tag>.tres`).
@export var look: LookProfile
## The particle of its casting hand (a ParticleType, data/fx/cast_<tag>.tres). Empty: the god casts without one.
@export_file("*.tres") var cast_fx_path: String = ""
## The AI profile of a wizard of this god; empty: the original's profile.
@export var ai_profile: AiProfile
@export var book: GodBook


## Name FxBus plays for the casting hand. A god without a particle still names one (`cast_<tag>`): the wizard's pose follows it.
func cast_fx_name() -> String:
	if not cast_fx_path.is_empty():
		return cast_fx_path.get_file().get_basename()
	return "cast_%s" % tag
