extends SceneTree

## RFC-036 036c: every type of data/catalog/ equals the one built from the original JSON, field by field.
## Same builder as tools/bake_catalog.gd, so a number that does not come back identical from the text .tres is named here
## (R3 of the RFC: floats in text, dictionary order). Prints CATALOG PASS or CATALOG FAIL.
## "$GODOT" --headless --path game --script res://debug/catalog_cases.gd
## No autoloads: the catalog is loaded by path and the builder preloaded.

const _BUILDER := preload("res://tools/catalog_builder.gd")
const CATALOG_PATH := "res://data/catalog/game_catalog.tres"
const MAX_REPORTED := 40

var _failures := 0


func _initialize() -> void:
	var catalog: Resource = load(CATALOG_PATH) if ResourceLoader.exists(CATALOG_PATH) else null
	if catalog == null:
		print("CATALOG FAIL: %s is missing; run tools/bake_catalog.gd" % CATALOG_PATH)
		quit(1)
		return
	var dir: String = _BUILDER.DATA_DIR
	var books: Dictionary = _BUILDER.read_json(dir + "books.json")
	var structures: Dictionary = _BUILDER.structure_tags(books)
	var creatures: Dictionary = _BUILDER.read_json(dir + "creatures.json")
	var spells: Dictionary = _BUILDER.read_json(dir + "spells.json")
	var wizards: Dictionary = _BUILDER.read_json(dir + "wizards.json")
	var abilities: Dictionary = _BUILDER.read_json(dir + "abilities.json")
	var buildings: Dictionary = _BUILDER.read_json(dir + "buildings.json")
	var sizes: Dictionary = _BUILDER.read_json(_BUILDER.SIZES_PATH)

	var expected: Array[Resource] = []
	for tag in creatures:
		expected.append(_BUILDER.make_creature(creatures[tag]))
	_compare_list("creatures", catalog.creatures, expected)
	expected = []
	for tag in spells:
		expected.append(_BUILDER.make_spell(spells[tag], structures.has(tag)))
	_compare_list("spells", catalog.spells, expected)
	expected = []
	for tag in wizards:
		expected.append(_BUILDER.make_wizard(wizards[tag]))
	_compare_list("wizards", catalog.wizards, expected)
	expected = []
	for tag in abilities:
		expected.append(_BUILDER.make_ability(abilities[tag]))
	_compare_list("abilities", catalog.abilities, expected)
	expected = []
	for tag in buildings:
		expected.append(_BUILDER.make_building(tag, buildings[tag]))
	_compare_list("buildings", catalog.buildings, expected)
	expected = []
	for kind in ["bodies", "props"]:
		var group: Dictionary = sizes.get(kind, {})
		for tag in group:
			expected.append(_BUILDER.make_body_size(tag, group[tag], kind == "props"))
	_compare_list("body_sizes", catalog.body_sizes, expected)

	_compare_value("books", catalog.books, books)
	# The records the consumers read must be the JSON ones: MapBuilding.bldg and BodyCatalog.info start from them.
	for building in catalog.buildings:
		_compare_value("building record " + building.tag, building.to_record(), buildings.get(building.tag, {}))
	for size in catalog.body_sizes:
		var group: Dictionary = sizes.get("props" if size.is_prop else "bodies", {})
		_compare_value("body record " + size.tag, size.to_record(), group.get(size.tag, {}))

	print("CATALOG creatures %d spells %d wizards %d abilities %d buildings %d body sizes %d books %d" % [
		catalog.creatures.size(), catalog.spells.size(), catalog.wizards.size(), catalog.abilities.size(),
		catalog.buildings.size(), catalog.body_sizes.size(), catalog.books.size()])
	print("CATALOG PASS" if _failures == 0 else "CATALOG FAIL (%d differences)" % _failures)
	quit(0 if _failures == 0 else 1)


func _compare_list(kind: String, saved: Array, built: Array) -> void:
	if saved.size() != built.size():
		_report("%s: %d saved, %d in the JSON" % [kind, saved.size(), built.size()])
		return
	for i in saved.size():
		var a: Resource = saved[i]
		var b: Resource = built[i]
		if a == null:
			_report("%s[%d]: null" % [kind, i])
			continue
		if a.get_script() != b.get_script():
			_report("%s[%d]: another script" % [kind, i])
			continue
		for property in b.get_property_list():
			if not (property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var name: String = property["name"]
			_compare_value("%s %s.%s" % [kind, b.get("tag"), name], a.get(name), b.get(name))


## Strict: same type, same value, same key order in dictionaries.
func _compare_value(path: String, saved: Variant, built: Variant) -> void:
	if typeof(saved) != typeof(built):
		_report("%s: type %s vs %s" % [path, type_string(typeof(saved)), type_string(typeof(built))])
		return
	if saved is Dictionary:
		# Text .tres sorts dictionary keys on save; only the key set must match.
		var saved_keys: Array = saved.keys()
		var built_keys: Array = built.keys()
		saved_keys.sort()
		built_keys.sort()
		if saved_keys != built_keys:
			_report("%s: keys %s vs %s" % [path, saved_keys, built_keys])
			return
		for key in built_keys:
			_compare_value("%s.%s" % [path, key], saved[key], built[key])
	elif saved is Array:
		if saved.size() != built.size():
			_report("%s: size %d vs %d" % [path, saved.size(), built.size()])
			return
		for i in built.size():
			_compare_value("%s[%d]" % [path, i], saved[i], built[i])
	elif saved is float:
		if var_to_bytes(saved) != var_to_bytes(built):
			_report("%s: %.17g vs %.17g" % [path, saved, built])
	elif saved != built:
		_report("%s: %s vs %s" % [path, saved, built])


func _report(message: String) -> void:
	_failures += 1
	if _failures <= MAX_REPORTED:
		print("CATALOG diff: " + message)
