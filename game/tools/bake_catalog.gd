extends SceneTree

## One-time tool (RFC-036 036c): writes the game's catalog as .tres. From then on the .tres are the source of truth and
## nothing reads creatures.json, spells.json, wizards.json, abilities.json, books.json, buildings.json or sizes.json at
## runtime; those files are only this tool's input.
##   data/catalog/creatures/<tag>.tres    CreatureType
##   data/catalog/spells/<tag>.tres       SpellType
##   data/catalog/wizards/<tag>.tres      WizardType
##   data/catalog/abilities/<tag>.tres    AbilityType
##   data/catalog/buildings/<tag>.tres    BuildingType
##   data/catalog/body_sizes/<tag>.tres   BodySize
##   data/catalog/game_catalog.tres       GameCatalog: the lists (in the JSON order) and the books
## The values are built by tools/catalog_builder.gd, the same code debug/catalog_cases.gd uses to prove the .tres say what
## the JSON says. File names are the tags; two tags that differ only by case get a numeric suffix (macOS is case-insensitive).
## Idempotent: it refuses to run when the catalog exists (the .tres may have been edited). --force overwrites.
## "$GODOT" --headless --path game --script res://tools/bake_catalog.gd [-- --force]
## Import the project before (so the class names are registered) and again after (so the editor knows the new files).
## No autoloads here: everything is preloaded by path.

const _BUILDER := preload("res://tools/catalog_builder.gd")
const _CATALOG := preload("res://scenes/data/game_catalog.gd")

const OUT_DIR := "res://data/catalog/"
const CATALOG_PATH := OUT_DIR + "game_catalog.tres"

var _failures: Array[String] = []


func _initialize() -> void:
	var force := OS.get_cmdline_user_args().has("--force")
	if FileAccess.file_exists(CATALOG_PATH) and not force:
		print("bake_catalog: %s exists; the .tres may have been edited. Use -- --force to overwrite." % CATALOG_PATH)
		quit(0)
		return
	var dir := _BUILDER.DATA_DIR
	var books := _BUILDER.read_json(dir + "books.json")
	var creatures := _BUILDER.read_json(dir + "creatures.json")
	var spells := _BUILDER.read_json(dir + "spells.json")
	var abilities := _BUILDER.read_json(dir + "abilities.json")
	var wizards := _BUILDER.read_json(dir + "wizards.json")
	var buildings := _BUILDER.read_json(dir + "buildings.json")
	var sizes := _BUILDER.read_json(_BUILDER.SIZES_PATH)
	if creatures.is_empty() or spells.is_empty() or wizards.is_empty() or abilities.is_empty() \
			or books.is_empty() or buildings.is_empty() or sizes.is_empty():
		push_error("bake_catalog: missing or empty JSON under %s or %s." % [dir, _BUILDER.SIZES_PATH])
		quit(1)
		return
	var catalog = _CATALOG.new()
	var structures: Dictionary = _BUILDER.structure_tags(books)
	var taken := {}
	for tag in creatures:
		catalog.creatures.append(_save(_BUILDER.make_creature(creatures[tag]), "creatures", tag, taken))
	for tag in spells:
		catalog.spells.append(_save(_BUILDER.make_spell(spells[tag], structures.has(tag)), "spells", tag, taken))
	for tag in wizards:
		catalog.wizards.append(_save(_BUILDER.make_wizard(wizards[tag]), "wizards", tag, taken))
	for tag in abilities:
		catalog.abilities.append(_save(_BUILDER.make_ability(abilities[tag]), "abilities", tag, taken))
	for tag in buildings:
		catalog.buildings.append(_save(_BUILDER.make_building(tag, buildings[tag]), "buildings", tag, taken))
	for kind in ["bodies", "props"]:
		var group: Dictionary = sizes.get(kind, {})
		for tag in group:
			catalog.body_sizes.append(_save(_BUILDER.make_body_size(tag, group[tag], kind == "props"), "body_sizes", tag, taken))
	catalog.books = books
	var status := ResourceSaver.save(catalog, CATALOG_PATH)
	if status != OK:
		_failures.append("%s (error %d)" % [CATALOG_PATH, status])
	print("bake_catalog: creatures %d spells %d wizards %d abilities %d buildings %d body sizes %d" % [
		catalog.creatures.size(), catalog.spells.size(), catalog.wizards.size(), catalog.abilities.size(),
		catalog.buildings.size(), catalog.body_sizes.size()])
	for failure in _failures:
		push_error("bake_catalog: could not save " + failure)
	print("bake_catalog: %s" % ("FAIL" if not _failures.is_empty() else "done"))
	quit(1 if not _failures.is_empty() else 0)


## Saves `type` as data/catalog/<folder>/<tag>.tres and returns it, now backed by that file (so the catalog references it).
func _save(type: Resource, folder: String, tag: String, taken: Dictionary) -> Resource:
	var directory := OUT_DIR + folder + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path := directory + _file_name(tag, folder, taken) + ".tres"
	var status := ResourceSaver.save(type, path, ResourceSaver.FLAG_CHANGE_PATH)
	if status != OK:
		_failures.append("%s (error %d)" % [path, status])
	return type


## The tag as a file name; a case-insensitive repeat inside the same folder gets _2, _3…
func _file_name(tag: String, folder: String, taken: Dictionary) -> String:
	var base := tag.validate_filename()
	var name := base
	var n := 1
	while taken.has(folder + "/" + name.to_lower()):
		n += 1
		name = "%s_%d" % [base, n]
	taken[folder + "/" + name.to_lower()] = true
	return name
