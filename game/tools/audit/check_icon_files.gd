extends SceneTree

## Compares OriginalAssets.icon_file (GDScript) with tools/import/import_ui.py icon_file (Python) on
## every icon tag, and checks that the file exists in assets/original/ui/icons/ for the tags that
## have art.
##   python3 tools/import/import_ui.py --icon-files=F
##   "$GODOT" --headless --path game --script res://tools/audit/check_icon_files.gd -- --list=F
## Exits 1 on any difference.


func _initialize() -> void:
	var list := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--list="):
			list = argument.substr(7)
	var text := FileAccess.get_file_as_string(list)
	var checked := 0
	var failed := 0
	var lower_seen := {}
	for line in text.split("\n", false):
		var parts := line.split("\t")
		checked += 1
		var file := OriginalAssets.icon_file(parts[0])
		if file != parts[1]:
			failed += 1
			print("DIFF %s: gd %s, py %s" % [parts[0], file, parts[1]])
		var key := file.to_lower()
		if lower_seen.has(key) and lower_seen[key] != parts[0]:
			failed += 1
			print("CLASH %s and %s" % [lower_seen[key], parts[0]])
		lower_seen[key] = parts[0]
	print("icon files: %d tags, %d failures" % [checked, failed])
	quit(1 if failed > 0 else 0)
