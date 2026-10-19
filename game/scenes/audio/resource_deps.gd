class_name ResourceDeps
extends RefCounted

## RFC-052 (F361, F368): the files a .tres depends on, read from the file without loading it. Its own script (no autoload
## named) so a `--script` tool (debug/suite/catalog_cases.gd, which validates data/audio/) can use it: SoundLibrary names
## GameData, which a `--script` run does not have.


## True when every file `path` depends on exists. A baked set names streams of assets/original/audio/, which a clone may
## not have.
static func all_exist(path: String) -> bool:
	for dep_path in paths(path):
		if dep_path.is_empty() or not ResourceLoader.exists(dep_path):
			return false
	return true


## The res:// paths `path` depends on (ext_resources). A uid the project does not know gives an empty entry.
static func paths(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	for dependency in ResourceLoader.get_dependencies(path):
		var dep_path := ""
		for part in dependency.split("::"):
			if part.begins_with("res://"):
				dep_path = part
		if dep_path.is_empty() and dependency.begins_with("uid://"):
			var id := ResourceUID.text_to_id(dependency.get_slice("::", 0))
			dep_path = ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else ""
		out.append(dep_path)
	return out
