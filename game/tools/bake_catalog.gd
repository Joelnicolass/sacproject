extends SceneTree

## Seed tool (RFC-036 036c, RFC-040 040a): writes the game's catalog as one .tres per type. From then on those files are the
## source of truth and the only thing the game reads: GameCatalog scans the folders, so there is no list to keep. The JSON
## files (creatures.json, spells.json, wizards.json, abilities.json, books.json, buildings.json, sizes.json) are only this
## tool's input.
##   data/catalog/creatures/<tag>.tres    CreatureType
##   data/catalog/spells/<tag>.tres       SpellType
##   data/catalog/wizards/<tag>.tres      WizardType
##   data/catalog/abilities/<tag>.tres    AbilityType
##   data/catalog/buildings/<tag>.tres    BuildingType
##   data/catalog/body_sizes/<tag>.tres   BodySize
##   data/catalog/books.tres              GodBooks: the god -> creatures/spells mapping
## The values are built by tools/catalog_builder.gd. File names are the tags; two tags that differ only by case get a
## numeric suffix (macOS is case-insensitive). It never embeds types in another file.
## Human edits are safe: without --force a file that already exists is left alone and only missing ones are written.
## --force overwrites everything with the JSON values.
## "$GODOT" --headless --path game --script res://tools/bake_catalog.gd [-- --force]
## Import the project before (so the class names are registered) and again after (so the editor knows the new files).
## No autoloads here: everything is preloaded by path.

const _BUILDER := preload("res://tools/catalog_builder.gd")
const _GOD_BOOKS := preload("res://scenes/data/god_books.gd")

const OUT_DIR := "res://data/catalog/"
const BOOKS_PATH := OUT_DIR + "books.tres"

var _force := false
var _written := 0
var _kept := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_force = OS.get_cmdline_user_args().has("--force")
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
	var structures: Dictionary = _BUILDER.structure_tags(books)
	var taken := {}
	for tag in creatures:
		_save(_BUILDER.make_creature(creatures[tag]), "creatures", tag, taken)
	for tag in spells:
		_save(_BUILDER.make_spell(spells[tag], structures.has(tag)), "spells", tag, taken)
	for tag in wizards:
		_save(_BUILDER.make_wizard(wizards[tag]), "wizards", tag, taken)
	for tag in abilities:
		_save(_BUILDER.make_ability(abilities[tag]), "abilities", tag, taken)
	for tag in buildings:
		_save(_BUILDER.make_building(tag, buildings[tag]), "buildings", tag, taken)
	for kind in ["bodies", "props"]:
		var group: Dictionary = sizes.get(kind, {})
		for tag in group:
			_save(_BUILDER.make_body_size(tag, group[tag], kind == "props"), "body_sizes", tag, taken)
	var god_books = _GOD_BOOKS.new()
	god_books.books = books
	_save_to(god_books, BOOKS_PATH)
	print("bake_catalog: wrote %d files, kept %d existing%s" % [_written, _kept, "" if _force else " (use -- --force to overwrite)"])
	for failure in _failures:
		push_error("bake_catalog: could not save " + failure)
	print("bake_catalog: %s" % ("FAIL" if not _failures.is_empty() else "done"))
	quit(1 if not _failures.is_empty() else 0)


## Saves `type` as data/catalog/<folder>/<tag>.tres.
func _save(type: Resource, folder: String, tag: String, taken: Dictionary) -> void:
	var directory := OUT_DIR + folder + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_save_to(type, directory + _file_name(tag, folder, taken) + ".tres")


func _save_to(resource: Resource, path: String) -> void:
	if FileAccess.file_exists(path) and not _force:
		_kept += 1
		return
	var status := ResourceSaver.save(resource, path)
	if status != OK:
		_failures.append("%s (error %d)" % [path, status])
	else:
		_written += 1


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
