extends Node

## RFC-040 040a, the acceptance test: editing data/catalog/creatures/<tag>.tres changes what the game reads.
## Rewrites one creature file with another health, reloads GameData the way the game does (GameCatalog scan), checks
## the new number, then restores the file byte for byte. Prints CATALOG EDIT PASS or CATALOG EDIT FAIL.
## "$GODOT" --headless --path game res://debug/catalog_edit_cases.tscn

const TAG := "EHTH"
const BUMP := 12345


func _ready() -> void:
	var ok := _run()
	print("CATALOG EDIT PASS" if ok else "CATALOG EDIT FAIL")
	get_tree().quit(0 if ok else 1)


func _run() -> bool:
	var path: String = GameData.creature(TAG).resource_path
	var original := FileAccess.get_file_as_string(path)
	var before: int = GameData.creature(TAG).health
	print("CATALOG EDIT %s health before = %d, books = %d gods" % [TAG, before, GameData.book("pyro").size()])
	if before <= 0 or original.is_empty() or not GameData.is_loaded() or GameData.wizards().is_empty():
		return false
	var edited := original.replace("health = %d\n" % before, "health = %d\n" % (before + BUMP))
	if edited == original:
		print("CATALOG EDIT cannot find the health line in %s" % path)
		return false
	_write(path, edited)
	GameData.reload(true)
	var after: int = GameData.creature(TAG).health
	print("CATALOG EDIT %s health after = %d (expected %d)" % [TAG, after, before + BUMP])
	_write(path, original)
	GameData.reload(true)
	var restored: int = GameData.creature(TAG).health
	print("CATALOG EDIT %s health restored = %d" % [TAG, restored])
	return after == before + BUMP and restored == before and FileAccess.get_file_as_string(path) == original


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
