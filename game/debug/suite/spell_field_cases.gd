extends RefCounted

## 055e e1 case of rules_suite: the named fields of the 53 SpellType give the same AI decisions the flag words gave. For every spell it
## compares, decision by decision, LegacySpellBits (the old logic over the frozen bits of spell_bits_055e.csv) with AiSpellEval and the
## fields: rating_fn, wants_acc, the attack and support phases, only-on-self, the kind it lands on (wizard, creature, Manahoar,
## structure, nothing), the side rule of can_cast_on over every (free fount, relation, fount structure), and what the AI rater adds for
## it. Plus: the .tres equal what SpellBits bakes from the CSV, and the first Shrine, Convert and Desecrate of the five books are the ones
## the bits chose. Prints SPELL FIELDS compared=<n> differ=<n> and, for each difference, the old and the new value.

const CSV_PATH := "res://debug/suite/spell_bits_055e.csv"
const LEGACY := preload("res://debug/suite/legacy_spell_bits.gd")
const SPELL_BITS := preload("res://tools/bake/spell_bits.gd")
const SPELLS_DIR := "res://data/catalog/spells/"
const GODS := ["james", "stratos", "persephone", "charnel", "pyro"]
const KIND_BITS := {AiTrack.Kind.WIZ: 1, AiTrack.Kind.CRE: 4, AiTrack.Kind.MAHO: 4, AiTrack.Kind.STR: 0x10, AiTrack.Kind.NONE: 0}
const BOOLS := ["targets_wizards", "targets_souls", "targets_creatures", "targets_corpses", "targets_structures", "only_free_manafounts",
	"only_allies", "never_allies", "targets_ground"]

var _compared := 0
var _lines := PackedStringArray()


func run(_host: Node) -> Dictionary:
	var rows := _read_rows()
	for tag: String in rows:
		var spell := GameData.spell(tag)
		if spell == null:
			_differ(tag, "exists", "csv row", "no spell")
			continue
		_decisions(tag, rows[tag], spell)
	for file in DirAccess.get_files_at(SPELLS_DIR):
		if file.ends_with(".tres") and not rows.has(file.get_basename()):
			_differ(file.get_basename(), "exists", "no csv row", "spell")
	for god: String in GODS:
		_tower(god, rows)
	print("SPELL FIELDS compared=%d differ=%d spells=%d" % [_compared, _lines.size(), rows.size()])
	for line in _lines:
		print("SPELL FIELDS   " + line)
	return {"spell_fields": {"ok": rows.size() == 53 and _lines.is_empty(), "compared": _compared, "differ": _lines.size(), "notes": _lines}}


func _read_rows() -> Dictionary:
	var rows := {}
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return rows
	var header := file.get_csv_line()
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size() != header.size():
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = cells[i] if header[i] == "tag" else (float(cells[i]) if header[i] == "effect_range_m" else int(cells[i]))
		rows[row["tag"]] = row
	return rows


func _decisions(tag: String, row: Dictionary, spell: SpellType) -> void:
	_same(tag, "wants_acc", LEGACY.wants_acc(row), AiSpellEval.wants_acc(spell))
	_same(tag, "rating_fn", LEGACY.rating_fn(row), AiSpellEval.rating_fn(spell))
	_same(tag, "attack_phase", LEGACY.accepts(row, LEGACY.ATTACK_MASK), AiSpellEval.casts_in(spell, SpellType.AiPhase.ATTACK))
	_same(tag, "support_phase", LEGACY.accepts(row, LEGACY.SUPPORT_MASK), AiSpellEval.casts_in(spell, SpellType.AiPhase.SUPPORT))
	_same(tag, "only_on_self", LEGACY.only_on_self(row), spell.ai_only_on_self)
	_same(tag, "worth", int(row["amount2"]), spell.ai_worth)
	_same(tag, "max_targets", int(row["count"]), spell.max_targets)
	for kind: int in KIND_BITS:
		var track := AiTrack.new()
		track.kind = kind
		_same(tag, "lands_on_kind%d" % kind, LEGACY.lands_on(row, int(KIND_BITS[kind])), AiSpellEval.lands_on(spell, track))
	for free_fount in [false, true]:
		for relation in 4:
			for fount_structure in [false, true]:
				_same(tag, "can_cast_on_%s_%d_%s" % [free_fount, relation, fount_structure], LEGACY.can_cast_on(row, free_fount, relation, fount_structure),
					AiSpellEval.side_allows(spell, free_fount, relation, fount_structure))
	_rater(tag, row, spell)
	_baked(tag, row, spell)


## What fill_from_object adds for the spell in a wizard's book: the old amount2 * range * (1 - cost/mana) * k, or nothing.
func _rater(tag: String, row: Dictionary, spell: SpellType) -> void:
	var mana := 500.0
	var bits_worth: float = LEGACY.rater_worth(row, spell.cast_range_m, float(spell.mana_cost), mana, AiRater.ABILITY_K)
	var acc := AiRater.fill_from_object(AiRater.WIZARD_STATS, int(mana), [], [spell])
	var expected := PackedFloat32Array([0.0])
	if bits_worth >= 0.0:
		expected[0] = expected[0] + bits_worth
	_same(tag, "rater", expected[0], acc[AiRater.RATE_ABILITY])


## The .tres hold what SpellBits bakes from the frozen bits: the builder and the data say the same.
func _baked(tag: String, row: Dictionary, spell: SpellType) -> void:
	var made := SpellType.new()
	SPELL_BITS.apply(made, {"tag": tag, "flags": row["flags"], "flags1": row["flags1"], "amount2": row["amount2"], "effect_range": row["effect_range_m"]})
	for field: String in BOOLS + ["ai_use", "ai_phase", "ai_only_on_self", "ai_worth"]:
		_same(tag, "baked_" + field, made.get(field), spell.get(field))


## The Shrine, Convert and Desecrate the AI of each god finds in its structures: the first with the fount bit, then `ccas`, then `ucas`.
func _tower(god: String, rows: Dictionary) -> void:
	var old_shrine := ""
	var old_convert := ""
	var old_desecrate := ""
	var shrine: SpellType
	var convert: SpellType
	var desecrate: SpellType
	for spell: SpellType in GameData.book(god, 9)["structures"]:
		var row: Dictionary = rows.get(spell.tag, {})
		if row.is_empty():
			continue
		if old_shrine.is_empty() and (int(row["flags"]) & (1 << 11)) != 0:
			old_shrine = spell.tag
		if spell.tag == "ccas":
			old_convert = spell.tag
		if spell.tag == "ucas":
			old_desecrate = spell.tag
		if shrine == null and spell.only_free_manafounts:
			shrine = spell
		if spell.ai_use == SpellType.AiUse.CONVERT:
			convert = spell
		if spell.ai_use == SpellType.AiUse.DESECRATE:
			desecrate = spell
	_same(god, "tower_shrine", old_shrine, shrine.tag if shrine != null else "")
	_same(god, "tower_convert", old_convert, convert.tag if convert != null else "")
	_same(god, "tower_desecrate", old_desecrate, desecrate.tag if desecrate != null else "")


func _same(tag: String, decision: String, bits_value: Variant, field_value: Variant) -> void:
	_compared += 1
	if typeof(bits_value) == typeof(field_value) and bits_value == field_value:
		return
	_differ(tag, decision, bits_value, field_value)


func _differ(tag: String, decision: String, bits_value: Variant, field_value: Variant) -> void:
	_lines.append("%s_%s: bits=%s fields=%s" % [tag, decision, str(bits_value), str(field_value)])
