extends Node

const _CREATURE_TYPE := preload("res://scenes/data/creature_type.gd")
const _SPELL_TYPE := preload("res://scenes/data/spell_type.gd")
const _ABILITY_TYPE := preload("res://scenes/data/ability_type.gd")
const _WIZARD_TYPE := preload("res://scenes/data/wizard_type.gd")

const DATA_DIR := "res://cache/data/"
const GODS: PackedStringArray = ["persephone", "pyro", "james", "stratos", "charnel"]

var _creatures: Dictionary = {}
var _spells: Dictionary = {}
var _abilities: Dictionary = {}
var _wizards: Array = []
var _wizards_by_tag: Dictionary = {}
var _books: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	_creatures.clear()
	_spells.clear()
	_abilities.clear()
	_wizards.clear()
	_wizards_by_tag.clear()
	_books.clear()
	var books := _read_json("books.json")
	var creatures := _read_json("creatures.json")
	var spells := _read_json("spells.json")
	var abilities := _read_json("abilities.json")
	var wizards := _read_json("wizards.json")
	if creatures.is_empty() or spells.is_empty() or wizards.is_empty() or books.is_empty():
		print("GameData: faltan los datos del instalador en %s. Corré python3 tools/export_stats.py." % DATA_DIR)
		return
	var structure_tags := {}
	for god in books:
		for tag in books[god].get("structures", []):
			structure_tags[tag] = true
	for tag in creatures:
		_creatures[tag] = _make_creature(creatures[tag])
	for tag in spells:
		_spells[tag] = _make_spell(spells[tag], structure_tags.has(tag))
	for tag in abilities:
		_abilities[tag] = _make_ability(abilities[tag])
	for tag in wizards:
		var wizard := _make_wizard(wizards[tag])
		_wizards.append(wizard)
		_wizards_by_tag[tag] = wizard
	_books = books


func is_loaded() -> bool:
	return not _creatures.is_empty()


func creature(tag: String) -> _CREATURE_TYPE:
	return _creatures.get(tag)


func spell(tag: String) -> _SPELL_TYPE:
	return _spells.get(tag)


func ability(tag: String) -> _ABILITY_TYPE:
	return _abilities.get(tag)


func wizard(tag: String) -> _WIZARD_TYPE:
	return _wizards_by_tag.get(tag)


func wizards() -> Array:
	return _wizards.duplicate()


func gods() -> PackedStringArray:
	return GODS


## The god's book up to a wizard level, like sacengine `getSpells` (state.d:29512): entries of a higher
## level are left out. The default 1 is the book the game has used so far (F112). A book without
## "levels" (an older cache) gives every entry.
func book(god: String, max_level := 1) -> Dictionary:
	var creatures: Array[_CREATURE_TYPE] = []
	var spells: Array[_SPELL_TYPE] = []
	var structures: Array[_SPELL_TYPE] = []
	var entry: Dictionary = _books.get(god, {})
	var levels: Dictionary = entry.get("levels", {})
	for tag in entry.get("creatures", []):
		if _creatures.has(tag) and int(levels.get(tag, 0)) <= max_level:
			creatures.append(_creatures[tag])
	for tag in entry.get("spells", []):
		if _spells.has(tag) and int(levels.get(tag, 0)) <= max_level:
			spells.append(_spells[tag])
	for tag in entry.get("structures", []):
		if _spells.has(tag) and int(levels.get(tag, 0)) <= max_level:
			structures.append(_spells[tag])
	return {"creatures": creatures, "spells": spells, "structures": structures}


## Wizard level at which `tag` enters the god's book (computeDefaultSpells), or -1 if it is not in it.
func creature_level(god: String, tag: String) -> int:
	var levels: Dictionary = _books.get(god, {}).get("levels", {})
	return int(levels.get(tag, -1))


func _read_json(file_name: String) -> Dictionary:
	var path := DATA_DIR + file_name
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	print("GameData: no se pudo leer %s." % path)
	return {}


func _make_creature(row: Dictionary) -> _CREATURE_TYPE:
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
	return type


func _make_spell(row: Dictionary, structure: bool) -> _SPELL_TYPE:
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
	type.damage_range = float(row.get("damage_range", 0.0))
	type.effect_range = float(row.get("effect_range", 0.0))
	type.duration = float(row.get("duration", 0.0))
	type.flags = int(row.get("flags", 0))
	type.flags1 = int(row.get("flags1", 0))
	type.flags2 = int(row.get("flags2", 0))
	type.is_structure = structure
	type.structures = PackedStringArray(row.get("structures", []))
	return type


func _make_ability(row: Dictionary) -> _ABILITY_TYPE:
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
	return type


func _make_wizard(row: Dictionary) -> _WIZARD_TYPE:
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
	type.idle_animation = row.get("idle_animation", {}) if row.get("idle_animation", {}) is Dictionary else {}
	type.run_animation = row.get("run_animation", {}) if row.get("run_animation", {}) is Dictionary else {}
	type.walk_animation = row.get("walk_animation", {}) if row.get("walk_animation", {}) is Dictionary else {}
	type.death_frames = PackedInt32Array(row.get("death_frames", []))
	type.corpse_rise_frames = int(row.get("corpse_rise_frames", 0))
	type.float_to_stance_frames = int(row.get("float_to_stance_frames", 0))
	return type
