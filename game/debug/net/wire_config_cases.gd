extends RefCounted

## 055s case of rules_suite: the network wire of the replicated scenes did not change. It lists, for every scene of scenes/ that carries a
## MultiplayerSynchronizer (and the ones that inherit one), each replicated property with its scene, its node, its spawn flag and its mode,
## sorts the lines and prints their hash. Run it on the branch point and again after a cut: the hash must be the same.
## Also fails when a body or model scene (scenes/**/bodies/) carries a synchronizer or a spawner: a body scene is data, never a replicated node.
## Prints WIRE CONFIG sha256=<hex> props=<n> and WIRE CONFIG scenes=<n> bodies_with_sync=<n>.

const ROOT := "res://scenes"
## Scenes that inherit a replicated one and so carry its wire without naming a synchronizer.
const INHERITING: PackedStringArray = [
	"res://scenes/units/villager/villager.tscn",
	"res://scenes/sacrifice/carrier_doctor.tscn",
	"res://scenes/sacrifice/ritual_doctor.tscn",
]
const MAX_LINES := 12


func run(_host: Node) -> Dictionary:
	var paths := PackedStringArray()
	var in_bodies := PackedStringArray()
	_walk(ROOT, paths, in_bodies)
	for path in INHERITING:
		if not paths.has(path):
			paths.append(path)
	paths.sort()
	var lines := PackedStringArray()
	var scenes := 0
	for path in paths:
		var before := lines.size()
		_collect(path, lines)
		scenes += 1 if lines.size() > before else 0
	lines.sort()
	var digest := "\n".join(lines).sha256_text()
	print("WIRE CONFIG sha256=%s props=%d" % [digest, lines.size()])
	var leaks := PackedStringArray()
	for path in in_bodies:
		var text := FileAccess.get_file_as_string(path)
		if text.contains("MultiplayerSynchronizer") or text.contains("MultiplayerSpawner"):
			leaks.append(path)
	print("WIRE CONFIG scenes=%d bodies_with_sync=%d" % [scenes, leaks.size()])
	for path in leaks.slice(0, MAX_LINES):
		print("WIRE CONFIG   " + path)
	return {"wire_config": {"ok": not lines.is_empty() and leaks.is_empty(), "props": lines.size(), "scenes": scenes, "sha256": digest}}


## Every scene under `dir` that names a synchronizer goes to `paths`; the ones inside a bodies/ folder go to `in_bodies`.
func _walk(dir: String, paths: PackedStringArray, in_bodies: PackedStringArray) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_walk(dir + "/" + sub, paths, in_bodies)
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".tscn"):
			continue
		var path := dir + "/" + file
		if dir.contains("/bodies"):
			in_bodies.append(path)
		elif FileAccess.get_file_as_string(path).contains("MultiplayerSynchronizer"):
			paths.append(path)


## One line per replicated property of the scene `path`.
func _collect(path: String, lines: PackedStringArray) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		lines.append("%s|UNLOADABLE" % path)
		return
	var root := packed.instantiate()
	for found in root.find_children("*", "MultiplayerSynchronizer", true, false):
		var sync := found as MultiplayerSynchronizer
		var config := sync.replication_config
		if config == null:
			continue
		for property in config.get_properties():
			lines.append("%s|%s|root=%s|%s|spawn=%s|mode=%d" % [path.get_file(), root.get_path_to(sync), str(sync.root_path), str(property),
					config.property_get_spawn(property), config.property_get_replication_mode(property)])
	root.free()
