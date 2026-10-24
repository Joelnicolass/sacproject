extends RefCounted

## No necesita el juego original; usa los modelos y datos ya importados en assets/original (versionados).
## Builds the catalog types from the original JSON rows (RFC-036 036c). Used by tools/bake/bake_catalog.gd to write the .tres
## and by debug/suite/catalog_cases.gd to prove the .tres say the same. Preloaded by path (no class_name): both callers
## run as --script, without autoloads and possibly before the class cache knows this file.

const _CREATURE_TYPE := preload("res://scenes/units/creature_type.gd")
const _SPELL_TYPE := preload("res://scenes/spells/spell_type.gd")
const _ABILITY_TYPE := preload("res://scenes/units/abilities/ability_type.gd")
const _WIZARD_TYPE := preload("res://scenes/wizards/wizard_type.gd")
const _BODY_SIZE := preload("res://scenes/bodies/body_size.gd")

const DATA_DIR := "res://assets/original/data/"
const SIZES_PATH := "res://assets/original/models/sizes.json"


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## Tags of the structures every god's book offers (they make a SpellType a structure).
static func structure_tags(books: Dictionary) -> Dictionary:
	var tags := {}
	for god in books:
		for tag in books[god].get("structures", []):
			tags[tag] = true
	return tags


static func make_creature(row: Dictionary) -> Resource:
	var type := _CREATURE_TYPE.new()
	type.tag = row.get("tag", "")
	type.display_name = row.get("name", "")
	type.god = row.get("god", "")
	type.model = row.get("model", "")
	type.health = int(row.get("health", 0))
	type.regeneration_per_s = float(row.get("regeneration_per_s", 0.0))
	type.drain = float(row.get("drain", 0.0))
	type.running_speed = float(row.get("running_speed", 0.0))
	type.flying_speed = float(row.get("flying_speed", 0.0))
	type.melee_strength = int(row.get("melee_strength", 0))
	type.melee_accuracy = int(row.get("melee_accuracy", 0))
	type.melee_evasion = int(row.get("melee_evasion", 0))
	type.ranged_accuracy = int(row.get("ranged_accuracy", 0))
	type.aggressiveness = int(row.get("aggressiveness", 0))
	type.sight_range = float(row.get("sight_range", 0.0))
	var resist: Dictionary = row.get("resistances", {})
	type.melee_resistance = float(resist.get("melee", 1.0))
	type.direct_spell_resistance = float(resist.get("direct_spell", 1.0))
	type.splash_spell_resistance = float(resist.get("splash_spell", 1.0))
	type.direct_ranged_resistance = float(resist.get("direct_ranged", 1.0))
	type.splash_ranged_resistance = float(resist.get("splash_ranged", 1.0))
	type.mana = int(row.get("mana", 0))
	type.mana_cost = int(row.get("mana_cost", 0))
	type.souls = int(row.get("souls", 0))
	type.cooldown_s = float(row.get("cooldown_s", 0.0))
	type.casting_time_s = float(row.get("casting_time_s", 0.0))
	type.spell_order = int(row.get("spell_order", 0))
	type.ability_tags = PackedStringArray(row.get("abilities", []))
	type.stance_animation = row.get("stance_animation", {}) if row.get("stance_animation", {}) is Dictionary else {}
	type.idle_animation = row.get("idle_animation", {}) if row.get("idle_animation", {}) is Dictionary else {}
	type.run_animation = row.get("run_animation", {}) if row.get("run_animation", {}) is Dictionary else {}
	type.walk_animation = row.get("walk_animation", {}) if row.get("walk_animation", {}) is Dictionary else {}
	for anim: Variant in row.get("melee_animations", []):
		type.melee_animations.append(anim if anim is Dictionary else {})
	type.is_ranged = bool(row.get("ranged", false))
	type.ranged_attack_tag = str(row.get("ranged_attack", ""))
	type.active_ability_tag = str(row.get("active_ability", ""))
	type.passive_on_damage = str(row.get("passive_on_damage", ""))
	type.passive_abilities = PackedStringArray(row.get("passive_abilities", []))
	for anim: Variant in row.get("shoot_animations", []):
		type.shoot_animations.append(anim if anim is Dictionary else {})
	type.extra_animations = row.get("extra_animations", {}) if row.get("extra_animations", {}) is Dictionary else {}
	type.flight_animations = row.get("flight_animations", {}) if row.get("flight_animations", {}) is Dictionary else {}
	type.stun_animations = row.get("stun_animations", {}) if row.get("stun_animations", {}) is Dictionary else {}
	type.death_animations = row.get("death_animations", {}) if row.get("death_animations", {}) is Dictionary else {}
	type.captive_animations = row.get("captive_animations", {}) if row.get("captive_animations", {}) is Dictionary else {}
	return type


static func make_spell(row: Dictionary, structure: bool) -> Resource:
	var type := _SPELL_TYPE.new()
	type.tag = row.get("tag", "")
	type.display_name = row.get("name", "")
	type.mana_cost = int(row.get("mana_cost", 0))
	type.cast_range = float(row.get("range", 0.0))
	type.cooldown_s = float(row.get("cooldown_s", 0.0))
	type.casting_time_s = float(row.get("casting_time_s", 0.0))
	type.spell_order = int(row.get("spell_order", 0))
	type.speed = float(row.get("speed", 0.0))
	type.acceleration = float(row.get("acceleration", 0.0))
	type.damage = int(row.get("amount", 0))
	type.amount2 = int(row.get("amount2", 0))
	type.count = int(row.get("amount3", 0))
	type.damage_range = float(row.get("damage_range", 0.0))
	type.effect_range = float(row.get("effect_range", 0.0))
	type.duration = float(row.get("duration", 0.0))
	type.flags = int(row.get("flags", 0))
	type.flags1 = int(row.get("flags1", 0))
	type.flags2 = int(row.get("flags2", 0))
	type.is_structure = structure
	return type


static func make_ability(row: Dictionary) -> Resource:
	var type := _ABILITY_TYPE.new()
	type.tag = row.get("tag", "")
	type.display_name = row.get("name", "")
	type.mana_cost = int(row.get("mana_cost", 0))
	type.cast_range = float(row.get("range", 0.0))
	type.cooldown_s = float(row.get("cooldown_s", 0.0))
	type.casting_time_s = float(row.get("casting_time_s", 0.0))
	type.speed = float(row.get("speed", 0.0))
	type.acceleration = float(row.get("acceleration", 0.0))
	type.damage = int(row.get("amount", 0))
	type.amount2 = int(row.get("amount2", 0))
	type.damage_range = float(row.get("damage_range", 0.0))
	type.effect_range = float(row.get("effect_range", 0.0))
	type.duration = float(row.get("duration", 0.0))
	type.flags = int(row.get("flags", 0))
	type.flags1 = int(row.get("flags1", 0))
	type.flags2 = int(row.get("flags2", 0))
	type.args = row.get("args", {})
	return type


static func make_wizard(row: Dictionary) -> Resource:
	var type := _WIZARD_TYPE.new()
	type.tag = row.get("tag", "")
	type.spell_tag = row.get("spell_tag", "")
	type.display_name = row.get("name", "")
	type.model = row.get("model", "")
	type.health = int(row.get("health", 0))
	type.mana = int(row.get("mana", 0))
	type.running_speed = float(row.get("running_speed", 0.0))
	type.regeneration_per_s = float(row.get("regeneration_per_s", 0.0))
	type.melee_evasion = int(row.get("melee_evasion", 0))
	var resist: Dictionary = row.get("resistances", {})
	type.melee_resistance = float(resist.get("melee", 1.0))
	type.direct_spell_resistance = float(resist.get("direct_spell", 1.0))
	type.splash_spell_resistance = float(resist.get("splash_spell", 1.0))
	type.direct_ranged_resistance = float(resist.get("direct_ranged", 1.0))
	type.splash_ranged_resistance = float(resist.get("splash_ranged", 1.0))
	type.stance_animation = row.get("stance_animation", {}) if row.get("stance_animation", {}) is Dictionary else {}
	type.idle_animation = row.get("idle_animation", {}) if row.get("idle_animation", {}) is Dictionary else {}
	type.run_animation = row.get("run_animation", {}) if row.get("run_animation", {}) is Dictionary else {}
	type.walk_animation = row.get("walk_animation", {}) if row.get("walk_animation", {}) is Dictionary else {}
	type.cast_animations = row.get("cast_animations", {}) if row.get("cast_animations", {}) is Dictionary else {}
	type.death_frames = PackedInt32Array(row.get("death_frames", []))
	type.corpse_rise_frames = int(row.get("corpse_rise_frames", 0))
	type.float_to_stance_frames = int(row.get("float_to_stance_frames", 0))
	type.stun_animations = row.get("stun_animations", {}) if row.get("stun_animations", {}) is Dictionary else {}
	return type


static func make_body_size(tag: String, row: Dictionary, is_prop: bool) -> Resource:
	var type := _BODY_SIZE.new()
	type.tag = tag
	type.is_prop = is_prop
	type.box = PackedFloat64Array(row.get("box", []))
	type.foot_offset = float(row.get("foot_offset", 0.0))
	type.height = float(row.get("height", 0.0))
	type.radius = float(row.get("radius", 0.0))
	type.reach = float(row.get("reach", 0.0))
	type.upright_fix = PackedFloat64Array(row.get("upright_fix", []))
	type.pose_source = str(row.get("pose_source", ""))
	type.has_upright_checked = row.has("upright_checked")
	type.upright_checked = bool(row.get("upright_checked", false))
	return type
