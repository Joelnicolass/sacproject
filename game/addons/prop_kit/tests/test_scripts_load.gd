extends "res://addons/prop_kit/tests/prop_test.gd"

## Every script and resource of the kit loads (a parse error fails here, not in a game).


func test_every_script_compiles() -> void:
	var stack := ["res://addons/prop_kit"]
	var seen := 0
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			stack.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd") or file.ends_with(".tres") or file.ends_with(".tscn"):
				var path := dir.path_join(file)
				var res := load(path)
				check(res != null, "%s loads" % path)
				if res is GDScript:
					check((res as GDScript).can_instantiate() or (res as GDScript).is_abstract(), "%s compiles" % path)
				seen += 1
	check(seen > 20, "found the kit's files (%d)" % seen)
