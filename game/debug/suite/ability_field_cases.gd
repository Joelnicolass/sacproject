extends RefCounted

## 055e e6 case of rules_suite: the named fields of the 63 AbilityType and the level + position of the book entries give the same
## decisions the flag words, `amount2`, `args` and `spell_order` gave. For every ability it compares, decision by decision, LegacyAbilityBits
## (the old logic over the frozen bits of ability_bits_055e6.txt) with the type: needs a target, aims at the dead, counts in the AI rater,
## what the rater adds, the worth, the poison `ires` and `freg`, and that the .tres equal what AbilityBits bakes from the same bits. For every
## creature and spell of the catalog and the creature template it compares the book key and the casting-time bonus at every wizard level
## with book_order_055e6.txt, and the order of the full book of each god. Prints ABILITY FIELDS compared=<n> differ=<n> and, for each
## difference, the old and the new value.

const BITS_PATH := "res://debug/suite/ability_bits_055e6.txt"
const ORDER_PATH := "res://debug/suite/book_order_055e6.txt"
const LEGACY := preload("res://debug/suite/legacy_ability_bits.gd")
const ABILITY_BITS := preload("res://tools/bake/ability_bits.gd")
const ABILITIES_DIR := "res://data/catalog/abilities/"
const FOLDERS := {"creature": "res://data/catalog/creatures/", "spell": "res://data/catalog/spells/", "template": "res://data/templates/"}
const GODS := ["james", "stratos", "persephone", "charnel", "pyro"]
const BOOLS := ["targets_wizards", "targets_souls", "targets_creatures", "targets_corpses", "targets_structures", "targets_ground"]
const MANA := 500

var _compared := 0
var _lines := PackedStringArray()


func run(_host: Node) -> Dictionary:
	var abilities := _read_rows(BITS_PATH)
	for row: Dictionary in abilities:
		var ability := load(ABILITIES_DIR + str(row["file"]) + ".tres") as AbilityType
		if ability == null:
			_differ(str(row["file"]), "exists", "csv row", "no ability")
			continue
		_ability(str(row["file"]), row, ability)
	for file: String in DirAccess.get_files_at(ABILITIES_DIR):
		if file.ends_with(".tres") and not _has_file(abilities, file.get_basename()):
			_differ(file.get_basename(), "exists", "no csv row", "ability")
	var orders := _read_rows(ORDER_PATH)
	var legacy_keys := {}
	for row: Dictionary in orders:
		var entry := _entry_of(row)
		if entry == null:
			_differ(str(row["file"]), "exists", "csv row", "no entry")
			continue
		legacy_keys[entry] = int(row["spell_order"])
		_entry(str(row["kind"]) + "/" + str(row["file"]), int(row["spell_order"]), entry)
	for god: String in GODS:
		_book(god, legacy_keys)
	print("ABILITY FIELDS compared=%d differ=%d abilities=%d entries=%d" % [_compared, _lines.size(), abilities.size(), orders.size()])
	for line: String in _lines:
		print("ABILITY FIELDS   " + line)
	return {"ability_fields": {"ok": abilities.size() == 63 and orders.size() == 122 and _lines.is_empty(), "compared": _compared,
		"differ": _lines.size(), "notes": _lines}}


func _read_rows(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return rows
	var header := file.get_csv_line()
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size() != header.size():
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = cells[i]
		rows.append(row)
	return rows


func _has_file(rows: Array[Dictionary], file: String) -> bool:
	for row: Dictionary in rows:
		if str(row["file"]) == file:
			return true
	return false


func _entry_of(row: Dictionary) -> Resource:
	var path: String = str(FOLDERS[str(row["kind"])]) + str(row["file"]) + ".tres"
	return load(path) as Resource


func _ability(label: String, row: Dictionary, ability: AbilityType) -> void:
	_same(label, "needs_target", LEGACY.needs_target(row), ability.needs_target())
	_same(label, "aims_at_dead", LEGACY.aims_at_dead(row), ability.aims_at_dead())
	_same(label, "counts_in_rater", LEGACY.counts_in_rater(row), ability.is_creature_attack())
	_same(label, "worth", int(row["amount2"]), ability.ai_worth)
	_same(label, "poison_ires", LEGACY.ires(row), ability.poison_resistance_debuff)
	_same(label, "poison_freg", LEGACY.freg(row), ability.poison_regen_factor)
	_rater(label, row, ability)
	_baked(label, row, ability)


## What fill_from_object adds for the ability of a creature: the old amount2 * range * (1 - cost/mana) * k, or nothing.
func _rater(label: String, row: Dictionary, ability: AbilityType) -> void:
	var stats: Dictionary = AiRater.WIZARD_STATS
	var no_spells: Array = []
	var expected := AiRater.fill_from_object(stats, MANA, [], no_spells)
	if LEGACY.counts_in_rater(row):
		AiRater.ability_acc(expected, float(int(row["amount2"])), ability.cast_range_m, float(ability.mana_cost), float(stats["melee_accuracy"]),
			float(stats["ranged_accuracy"]), float(MANA), float(stats["fly"]))
	var abilities: Array = [ability]
	var got := AiRater.fill_from_object(stats, MANA, abilities, no_spells)
	_same(label, "rater", expected[AiRater.RATE_ABILITY], got[AiRater.RATE_ABILITY])


## The .tres hold what AbilityBits bakes from the frozen bits: the builder and the data say the same.
func _baked(label: String, row: Dictionary, ability: AbilityType) -> void:
	var args := {}
	if str(row["ires"]) != "":
		args["ires"] = float(str(row["ires"]))
	if str(row["freg"]) != "":
		args["freg"] = float(str(row["freg"]))
	var made := AbilityType.new()
	ABILITY_BITS.apply(made, {"flags": int(row["flags"]), "flags1": int(row["flags1"]), "amount2": int(row["amount2"]), "args": args})
	for field: String in BOOLS + ["ai_attack", "ai_worth", "poison_resistance_debuff", "poison_regen_factor"]:
		_same(label, "baked_" + field, made.get(field), ability.get(field))


## The book key and the casting-time bonus of one creature, spell or template.
func _entry(label: String, spell_order: int, entry: Resource) -> void:
	@warning_ignore("integer_division")
	var old_level: int = spell_order / 100
	var position: int = spell_order % 100
	_same(label, "book_key", spell_order, BookOrder.key(entry))
	_same(label, "book_level", old_level, BookOrder.level(entry))
	_same(label, "book_slot", position, int(entry.get("book_slot")))
	for wizard_level in 10:
		_same(label, "cast_bonus_%d" % wizard_level, LEGACY.cast_bonus(spell_order, wizard_level), CastTime.bonus_levels(entry, wizard_level))


## The full book of a god (every level) sorted by the old spell_order and by BookOrder: the same entries in the same places.
func _book(god: String, legacy_keys: Dictionary) -> void:
	var rows: Dictionary = GameData.book(god, 9)
	var entries: Array[Resource] = []
	for list: String in ["creatures", "spells", "structures"]:
		for entry: Resource in rows.get(list, []):
			entries.append(entry)
	var old_order: Array[Resource] = entries.duplicate()
	old_order.sort_custom(func(a: Resource, b: Resource) -> bool: return int(legacy_keys.get(a, 0)) < int(legacy_keys.get(b, 0)))
	var new_order: Array[Resource] = entries.duplicate()
	new_order.sort_custom(func(a: Resource, b: Resource) -> bool: return BookOrder.key(a) < BookOrder.key(b))
	_same(god, "book_size", old_order.size(), new_order.size())
	for i in mini(old_order.size(), new_order.size()):
		_same(god, "book_slot_%d" % i, str(old_order[i].get("tag")), str(new_order[i].get("tag")))


func _same(label: String, decision: String, old_value: Variant, new_value: Variant) -> void:
	_compared += 1
	if typeof(old_value) == typeof(new_value) and old_value == new_value:
		return
	_differ(label, decision, old_value, new_value)


func _differ(label: String, decision: String, old_value: Variant, new_value: Variant) -> void:
	_lines.append("%s_%s: bits=%s fields=%s" % [label, decision, str(old_value), str(new_value)])
