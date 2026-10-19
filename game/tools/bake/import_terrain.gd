extends SceneTree

## Turns a map's terrain bin (High Noon, or `--map=<tag>`: RFC-050) into the `terrain_path` of its MapDefinition (RFC-033, 033f).
## Source: the HNTR v1 bin that `python3 tools/import/import_map.py [--map=Name] --terrain-bin=F` builds from the .scp (a temporary file outside the
## repo; nothing in the repo). Same float32 and int32 values as the bin, so Terrain builds the same mesh. Idempotent: when
## terrain.res already holds the same arrays nothing is written. Run once; the result is versioned.
## "$GODOT" --headless --path game --script res://tools/bake/import_terrain.gd -- --bin=F [--map=<tag>] [--out=res://path/terrain.res]


func _initialize() -> void:
	var source := ""
	var out := MapCatalog.active().terrain_path
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--bin="):
			source = argument.substr(6)
		elif argument.begins_with("--out="):
			out = argument.substr(6)
	if source.is_empty():
		push_error("Falta --bin=<terrain.bin> (python3 tools/import/import_map.py --terrain-bin=F).")
		quit(2)
		return
	var data := _read_bin(source)
	if data == null:
		push_error("No se pudo leer %s (HNTR v1)." % source)
		quit(1)
		return
	var old := load(out) as MapTerrainData if ResourceLoader.exists(out) else null
	if old != null and old.vertices == data.vertices and old.normals == data.normals and old.indices == data.indices:
		print("terrain: 0 written, 1 unchanged")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	var error := ResourceSaver.save(data, out)
	if error != OK:
		push_error("No se pudo escribir %s (%d)" % [out, error])
		quit(1)
		return
	print("terrain: 1 written (%d vertices, %d indices)" % [data.vertices.size(), data.indices.size()])
	quit(0)


func _read_bin(path: String) -> MapTerrainData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	if file.get_buffer(4) != "HNTR".to_utf8_buffer():
		return null
	var version := file.get_16()
	file.get_16()
	file.get_16()
	if version != 1:
		return null
	var vertex_count := file.get_32()
	var index_count := file.get_32()
	if vertex_count == 0 or index_count == 0:
		return null
	var data := MapTerrainData.new()
	data.vertices.resize(vertex_count)
	data.normals.resize(vertex_count)
	for i in vertex_count:
		data.vertices[i] = Vector3(file.get_float(), file.get_float(), file.get_float())
	for i in vertex_count:
		data.normals[i] = Vector3(file.get_float(), file.get_float(), file.get_float())
	data.indices.resize(index_count)
	for i in index_count:
		data.indices[i] = file.get_32()
	return data
