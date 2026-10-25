class_name ResourceDeps
extends RefCounted

## The files a .tres depends on, read from the file without loading it (the catalog validator uses it to check
## data/audio/). It only reads dependency lists; it loads and plays nothing.


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
