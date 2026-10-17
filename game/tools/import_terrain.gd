extends SceneTree

## Turns High Noon's terrain bin into assets/original/maps/high_noon/terrain.res (RFC-033, 033f).
## Source: cache/high_noon_terrain.bin (HNTR v1, written by tools/export_high_noon_terrain.py from the .scp).
## Same float32 and int32 values as the bin, so Terrain builds the same mesh. Idempotent: when terrain.res already holds
## the same arrays nothing is written. Run once; the result is versioned.
## "$GODOT" --headless --path game --script res://tools/import_terrain.gd

const SOURCE := "res://cache/high_noon_terrain.bin"


func _initialize() -> void:
	var out := OriginalAssets.map("high_noon", "terrain.res")
	var data := _read_bin(SOURCE)
	if data == null:
		push_error("No se pudo leer %s (HNTR v1)." % SOURCE)
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
