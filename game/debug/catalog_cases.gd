extends SceneTree

## RFC-040 040b: the catalog is valid, whatever the balance is. It does NOT compare against the original JSON: changing
## a number in a data/catalog/<folder>/<tag>.tres is allowed. It checks that the content is coherent.
##   - every file is a type of its folder, named after its tag (a case-only repeat gets _2, _3...)
##   - no duplicate tags in a folder
##   - every tag that books and abilities mention exists
##   - every creature and wizard has its BodySize
##   - the numbers are sane (health > 0, costs >= 0, ...)
## Failures name the file: "creatures/xyz.tres: health = -5". Prints CATALOG PASS or CATALOG FAIL.
## "$GODOT" --headless --path game --script res://debug/catalog_cases.gd
## No autoloads: the catalog is read through GameCatalog, the same scan the game does.

const MAX_REPORTED := 60
## References the original data itself leaves dangling ("tsg@" is in no table of the original game).
const KNOWN_DANGLING: PackedStringArray = ["tsg@"]
## Property -> minimum, per type. A strict minimum (">") is a key ending in ">".
const CREATURE_RANGES := {
	"health>": 0, "regeneration_per_s": 0, "drain": 0, "running_speed": 0, "flying_speed": 0, "melee_strength": 0,
	"melee_accuracy": 0, "melee_evasion": 0, "ranged_accuracy": 0, "aggressiveness": 0, "sight_range": 0,
	"melee_resistance": 0, "direct_spell_resistance": 0, "splash_spell_resistance": 0, "direct_ranged_resistance": 0,
	"splash_ranged_resistance": 0, "mana": 0, "mana_cost": 0, "souls": 0, "cooldown_s": 0, "casting_time_s": 0,
}
const SPELL_RANGES := {
	"mana_cost": 0, "cast_range": 0, "cooldown_s": 0, "casting_time_s": 0, "speed": 0, "damage_range": 0,
	"effect_range": 0, "duration": 0,
}
const WIZARD_RANGES := {
	"health>": 0, "mana": 0, "running_speed": 0, "regeneration_per_s": 0, "melee_resistance": 0,
	"direct_spell_resistance": 0, "splash_spell_resistance": 0, "direct_ranged_resistance": 0,
	"splash_ranged_resistance": 0,
}
const BUILDING_RANGES := {"max_health": 0}
const BODY_RANGES := {"height": 0, "radius": 0, "reach": 0}

var _failures := 0
var _catalog: GameCatalog


func _initialize() -> void:
	_catalog = GameCatalog.shared(true)
	var tables := {
		"creatures": _catalog.creatures, "spells": _catalog.spells, "wizards": _catalog.wizards,
		"abilities": _catalog.abilities, "buildings": _catalog.buildings, "body_sizes": _catalog.body_sizes,
	}
	var tags := {}
	for folder: String in tables:
		tags[folder] = _check_folder(folder, tables[folder])
	_check_ranges("creatures", _catalog.creatures, CREATURE_RANGES)
	_check_ranges("spells", _catalog.spells, SPELL_RANGES)
	_check_ranges("abilities", _catalog.abilities, SPELL_RANGES)
	_check_ranges("wizards", _catalog.wizards, WIZARD_RANGES)
	_check_ranges("buildings", _catalog.buildings, BUILDING_RANGES)
	_check_ranges("body_sizes", _catalog.body_sizes, BODY_RANGES)
	_check_references(tags)
	_check_books(tags)
	_check_bodies(tags)
	print("CATALOG creatures %d spells %d wizards %d abilities %d buildings %d body sizes %d books %d" % [
		_catalog.creatures.size(), _catalog.spells.size(), _catalog.wizards.size(), _catalog.abilities.size(),
		_catalog.buildings.size(), _catalog.body_sizes.size(), _catalog.books.size()])
	print("CATALOG PASS" if _failures == 0 else "CATALOG FAIL (%d problems)" % _failures)
	quit(0 if _failures == 0 else 1)


## Every .tres of the folder is a type of it, named after its tag; no tag twice. Returns {tag: true}.
func _check_folder(folder: String, types: Array) -> Dictionary:
	var files := GameCatalog.files_in(folder)
	if files.size() != types.size():
		_report("%s/: %d .tres files but %d usable types (a file is not a %s)" % [folder, files.size(), types.size(), folder])
	var seen := {}
	for type: Resource in types:
		var file := _file(type)
		if type.tag.is_empty():
			_report("%s/%s: tag is empty" % [folder, file])
			continue
		if seen.has(type.tag):
			_report("%s/%s: duplicate tag \"%s\" (also in %s)" % [folder, file, type.tag, seen[type.tag]])
		seen[type.tag] = file
		var base: String = type.tag.validate_filename()
		var stem: String = file.get_basename()
		if stem != base and not _is_case_repeat(stem, base):
			_report("%s/%s: tag = \"%s\", the file should be %s.tres" % [folder, file, type.tag, base])
	var tags := {}
	for tag: String in seen:
		tags[tag] = true
	return tags


## "name_2", "name_3"... for a tag whose lower-case form is already taken in the folder (macOS file names).
func _is_case_repeat(stem: String, base: String) -> bool:
	var at := stem.rfind("_")
	return at > 0 and stem.substr(0, at) == base and stem.substr(at + 1).is_valid_int()


func _check_ranges(folder: String, types: Array, ranges: Dictionary) -> void:
	for type: Resource in types:
		for key: String in ranges:
			var strict := key.ends_with(">")
			var property := key.trim_suffix(">")
			var value: float = type.get(property)
			if value < ranges[key] or (strict and value <= ranges[key]):
				_report("%s/%s: %s = %s" % [folder, _file(type), property, str(type.get(property))])


func _check_references(tags: Dictionary) -> void:
	var abilities: Dictionary = tags["abilities"]
	var spells: Dictionary = tags["spells"]
	for creature: CreatureType in _catalog.creatures:
		var names := {"ranged_attack_tag": [creature.ranged_attack_tag], "active_ability_tag": [creature.active_ability_tag],
				"passive_on_damage": [creature.passive_on_damage], "ability_tags": Array(creature.ability_tags),
				"passive_abilities": Array(creature.passive_abilities)}
		for property: String in names:
			for tag: String in names[property]:
				# A passive may also be a spell (eniv, zerf).
				if not tag.is_empty() and not abilities.has(tag) and not spells.has(tag) and not KNOWN_DANGLING.has(tag):
					_report("creatures/%s: %s = \"%s\" is not an ability or a spell" % [_file(creature), property, tag])


func _check_books(tags: Dictionary) -> void:
	if _catalog.books.is_empty():
		_report("books.tres: no books (missing or empty)")
		return
	for god: String in _catalog.books:
		var entry: Dictionary = _catalog.books[god]
		var places := {"creatures": "creatures", "spells": "spells", "structures": "spells"}
		for list: String in places:
			for tag: String in entry.get(list, []):
				if not tags[places[list]].has(tag):
					_report("books.tres: %s.%s has \"%s\", which is not in %s/" % [god, list, tag, places[list]])
		var levels: Dictionary = entry.get("levels", {})
		for tag: String in levels:
			if not tags["creatures"].has(tag) and not tags["spells"].has(tag):
				_report("books.tres: %s.levels has \"%s\", which is no creature or spell" % [god, tag])
			elif float(levels[tag]) < 0.0:
				_report("books.tres: %s.levels[%s] = %s" % [god, tag, str(levels[tag])])


func _check_bodies(tags: Dictionary) -> void:
	var sizes: Dictionary = tags["body_sizes"]
	for creature: CreatureType in _catalog.creatures:
		if not sizes.has(creature.model):
			_report("creatures/%s: model = \"%s\" has no body_sizes/ file" % [_file(creature), creature.model])
	for wizard: WizardType in _catalog.wizards:
		if not sizes.has(wizard.model):
			_report("wizards/%s: model = \"%s\" has no body_sizes/ file" % [_file(wizard), wizard.model])
	for size: BodySize in _catalog.body_sizes:
		if not size.box.is_empty() and size.box.size() != 6:
			_report("body_sizes/%s: box has %d numbers, it needs 6" % [_file(size), size.box.size()])
		if not size.upright_fix.is_empty() and size.upright_fix.size() != 3:
			_report("body_sizes/%s: upright_fix has %d numbers, it needs 3" % [_file(size), size.upright_fix.size()])


func _file(type: Resource) -> String:
	return type.resource_path.get_file()


func _report(message: String) -> void:
	_failures += 1
	if _failures <= MAX_REPORTED:
		print("CATALOG problem: " + message)
