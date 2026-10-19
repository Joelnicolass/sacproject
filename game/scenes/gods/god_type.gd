@tool
class_name GodType
extends Resource

## A god (RFC-042 042a): everything the game knows about one, in one file `data/gods/<tag>.tres`. Adding a god is adding
## that file; no code lists the gods. Read-only at runtime, like the other types.
## The book and the AI profile are light and sit in the file as references. The theme, the look and the casting particle
## pull in the biome's textures, so they are file paths loaded when a match needs them: the catalog (and the dedicated
## server, and a headless test) never loads the five biomes just to list the gods.

@export var tag: String = ""
@export var display_name: String = ""
## Gods are listed by `sort_order`, then tag. The order is part of the rules: the biome draw, the AI's god draw and
## SpellType.structures index into it, so never renumber an existing god.
@export var sort_order: int = 0
## The land the god brings to a match (a GodTheme: colours, fog, classic ground).
@export_file("*.tres") var theme_path: String = ""
## The remaster look of the biome (a LookProfile, RFC-022); the theme points to the same one.
@export_file("*.tres") var look_path: String = ""
## The particle of its casting hand (a ParticleType, data/fx/cast_<tag>.tres). Empty: the god casts without one.
@export_file("*.tres") var cast_fx_path: String = ""
## The AI profile of a wizard of this god; empty: the original's profile.
@export var ai_profile: AiProfile
@export var book: GodBook


func load_theme() -> GodTheme:
	return load(theme_path) as GodTheme if ResourceLoader.exists(theme_path) else null


func load_look() -> LookProfile:
	return load(look_path) as LookProfile if ResourceLoader.exists(look_path) else null


## Name FxBus plays for the casting hand. A god without a particle still names one (`cast_<tag>`): the wizard's pose follows it.
func cast_fx_name() -> String:
	if not cast_fx_path.is_empty():
		return cast_fx_path.get_file().get_basename()
	return "cast_%s" % tag
