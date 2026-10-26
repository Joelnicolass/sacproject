extends RefCounted

## No necesita el juego original; traduce filas ya exportadas (assets/original/data/spells.json).
## Turns the flag words of a spell row of the original into the named fields of a SpellType while the catalog is baked. It runs only in
## tools: the game reads the named fields, never the bits. The bits nobody reads (flags 16-20, flags1 0, 1, 5, all of flags2) are lost on
## purpose. The same table is written in tools/migrate/spell_fields_055e.py (it rewrote the .tres); spell_field_cases proves they agree.
## Preloaded by path (no class_name), like catalog_builder.gd: both callers run as --script.

const _SPELL_TYPE := preload("res://scenes/spells/spell_type.gd")

## flags bit -> bool of SpellType («who it may land on»).
const FLAG_BITS := {
	"targets_wizards": 0, "targets_souls": 1, "targets_creatures": 2, "targets_corpses": 3, "targets_structures": 4,
	"only_free_manafounts": 11, "only_allies": 12, "never_allies": 13, "targets_ground": 14,
}
## flags1 bits the old attack and support masks read (0x58000000 and 0xa4000000 shifted back by 16).
const ATTACK_BITS := 0x5800
const SUPPORT_BITS := 0xa400
const ONLY_ON_SELF_BIT := 0x10
## The tags the 023 and 041 cuts gave an evaluator by hand; the bits do not say them.
const SELF_GUARD_TAGS := ["niks", "dlhs", "mrfe", "mrff", "rwsp"]
const DISABLE_FOE_TAGS := ["zerf", "eniv", "rapf", "htel"]
## Spells the old chain left without evaluator whatever their bits said.
const NO_EVALUATOR_TAGS := ["omna", "ndrg", "elet", "taed"]
## Spells whose AI use and phase are set by hand in their .tres (055f f5, plan 055f §12): apply() leaves `ai_use` and `ai_phase`
## as the type has them, so a re-bake never writes the bits' answer over the authored one (a fresh type keeps the defaults; set
## them in the inspector). spell_field_cases reads this list (F5_USES) to skip those two decisions.
const HAND_SET_TAGS := ["olah", "mrhc", "taed", "rter", "wobr", "ruah", "deda", "dnws", "pmcd", "elet", "ndrg"]


static func apply(type: Resource, row: Dictionary) -> void:
	var flags := int(row.get("flags", 0))
	var flags1 := int(row.get("flags1", 0))
	for field: String in FLAG_BITS:
		type.set(field, (flags & (1 << int(FLAG_BITS[field]))) != 0)
	var hand_set := HAND_SET_TAGS.has(str(row.get("tag", "")))
	if not hand_set:
		type.ai_phase = _phase(flags1)
	type.ai_only_on_self = (flags1 & ONLY_ON_SELF_BIT) != 0
	type.ai_worth = int(row.get("amount2", 0))
	if not hand_set:
		type.ai_use = _use(str(row.get("tag", "")), flags1, float(row.get("effect_range", 0.0)))


static func _phase(flags1: int) -> int:
	if flags1 & ATTACK_BITS:
		return _SPELL_TYPE.AiPhase.ATTACK
	if flags1 & SUPPORT_BITS:
		return _SPELL_TYPE.AiPhase.SUPPORT
	return _SPELL_TYPE.AiPhase.NEVER


static func _use(tag: String, flags1: int, effect_range_m: float) -> int:
	var use: Dictionary = _SPELL_TYPE.AiUse
	match tag:
		"ccas":
			return use["CONVERT"]
		"ucas":
			return use["DESECRATE"]
		"laeh":
			return use["HEAL"]
		"pups":
			return use["SPEEDUP"]
	if SELF_GUARD_TAGS.has(tag):
		return use["SELF_GUARD"]
	if DISABLE_FOE_TAGS.has(tag):
		return use["DISABLE_FOE"]
	if NO_EVALUATOR_TAGS.has(tag):
		return use["NONE"]
	if flags1 & 0x4000:
		return use["HIT_AREA"] if ((flags1 & 0x40) != 0 and effect_range_m > 0.0) else use["HIT_ONE"]
	if flags1 & 0x8000:
		return use["HEAL"]
	return use["NONE"]
