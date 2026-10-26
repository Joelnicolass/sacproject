extends RefCounted

## No necesita el juego original; traduce filas ya exportadas (assets/original/data/abilities.json).
## Turns the flag words and args of an ability row of the original into the named fields of an AbilityType while the catalog is baked.
## It runs only in tools: the game reads the named fields, never the bits. What nobody reads (flags bits 12, 13, 16, flags1 but the
## attack bit, all of flags2, every arg but `ires` and `freg`) is lost on purpose. The same table is written in
## tools/migrate/ability_fields_055e6.py (it rewrote the .tres); ability_field_cases proves they agree.
## Preloaded by path (no class_name), like spell_bits.gd: both callers run as --script.

## flags bit -> bool of AbilityType («who it aims at»).
const FLAG_BITS := {
	"targets_wizards": 0, "targets_souls": 1, "targets_creatures": 2, "targets_corpses": 3, "targets_structures": 4, "targets_ground": 14,
}
## flags1 bit the AI rater reads: the ability is an attack.
const ATTACK_BIT := 0x4000


static func apply(type: Resource, row: Dictionary) -> void:
	var flags := int(row.get("flags", 0))
	for field: String in FLAG_BITS:
		type.set(field, (flags & (1 << int(FLAG_BITS[field]))) != 0)
	type.ai_attack = (int(row.get("flags1", 0)) & ATTACK_BIT) != 0
	type.ai_worth = int(row.get("amount2", 0))
	var args: Dictionary = row.get("args", {})
	type.poison_resistance_debuff = int(args.get("ires", 0))
	type.poison_regen_factor = float(args.get("freg", 1.0))
