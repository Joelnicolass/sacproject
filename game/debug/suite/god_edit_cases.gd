extends Node

## RFC-042 042a, the acceptance test: editing data/gods/<god>.tres changes the book the game offers.
## Takes one creature the god's book unlocks only at a high level (it has an unlock line but no row), adds it to the
## `creatures` list of the file, reloads GameData the way the game does, checks that the pickable book has it, then
## restores the file byte for byte. Also checks the order of the gods (the biome draw and the AI draw index into it).
## Prints GOD EDIT PASS or GOD EDIT FAIL.
## "$GODOT" --headless --path game res://debug/suite/god_edit_cases.tscn

const GOD := "pyro"
const ORDER: PackedStringArray = ["persephone", "pyro", "james", "stratos", "charnel"]


func _ready() -> void:
	var ok := _run()
	print("GOD EDIT PASS" if ok else "GOD EDIT FAIL")
	get_tree().quit(0 if ok else 1)


func _run() -> bool:
	if GameData.gods() != ORDER:
		print("GOD EDIT gods() = %s, expected %s" % [str(GameData.gods()), str(ORDER)])
		return false
	var god := GameData.god(GOD)
	var path := god.resource_path
	var original := FileAccess.get_file_as_string(path)
	var extra: CreatureType = null
	var listed := {}
	for creature in god.book.creatures:
		listed[creature.tag] = true
	for creature in GameData.all_creatures():
		if not listed.has(creature.tag) and creature.resource_path.begins_with("res://data/catalog/creatures/"):
			extra = creature
			break
	if extra == null or original.is_empty():
		print("GOD EDIT nothing to add to the book of %s" % GOD)
		return false
	var edited := _append_to_creatures(original, extra.resource_path)
	if edited.is_empty():
		print("GOD EDIT cannot find the creatures line of the book in %s" % path)
		return false
	var before := _tags(GameData.book(GOD, 9).get("creatures", []))
	_write(path, edited)
	GameData.reload(true)
	var after := _tags(GameData.book(GOD, 9).get("creatures", []))
	print("GOD EDIT %s book at level 9: %d creatures, adding %s" % [GOD, before.size(), extra.tag])
	_write(path, original)
	GameData.reload(true)
	var restored := _tags(GameData.book(GOD, 9).get("creatures", []))
	print("GOD EDIT after the edit: %d (has %s: %s); restored: %d" % [after.size(), extra.tag, str(after.has(extra.tag)), restored.size()])
	return not before.has(extra.tag) and after.has(extra.tag) and after.size() == before.size() + 1 \
		and restored == before and FileAccess.get_file_as_string(path) == original


## The GodBook's `creatures = Array[...]([...])` line with one more creature at the end: the file gets an ext_resource for it.
func _append_to_creatures(text: String, creature_path: String) -> String:
	var found := RegEx.create_from_string('\\ncreatures = (Array\\[[^\\n]*\\]\\(\\[[^\\n]*)\\]\\)').search(text)
	var header_end := text.find("\n")
	if found == null or header_end < 0:
		return ""
	var edited := text.substr(0, found.get_start(1)) + found.get_string(1) + ', ExtResource("added_by_test")])' + text.substr(found.get_end(0))
	return edited.insert(header_end + 1, '[ext_resource type="Resource" path="%s" id="added_by_test"]\n' % creature_path)


func _tags(types: Array) -> PackedStringArray:
	var tags := PackedStringArray()
	for type in types:
		tags.append(type.tag)
	return tags


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
