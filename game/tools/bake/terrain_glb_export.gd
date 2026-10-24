extends SceneTree

## No necesita el juego original; usa los modelos y datos ya importados en assets/original (versionados).
## Writes a map's ground (High Noon, or `--map=<tag>`) as assets/original/maps/<tag>/terrain.glb (RFC-035c). Run it once: from then on the glb is
## the source of truth (edit it in Blender) and terrain.res is derived from it by tools/terrain_import.gd on import.
## The file holds the vertex and index order of terrain.res, the visual normals and COLOR (tile id and local uv,
## alpha 0 on cliff walls), plus the flat data normals. Refuses to overwrite an existing glb without --force.
## "$GODOT" --headless --path game --script res://tools/bake/terrain_glb_export.gd [-- --out=res://path/terrain.glb] [--force]
## Needs the project imported once (tiles.png is read as an Image). Then import again so the editor builds the scene.

const GlbImport := preload("res://tools/terrain_import.gd")


func _initialize() -> void:
	var map := MapCatalog.active()
	var out := OriginalAssets.map(String(map.tag), "terrain.glb")
	var force := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.substr(6)
		elif argument == "--force":
			force = true
	if FileAccess.file_exists(out) and not force:
		push_error("%s already exists and is now the source of truth. Pass --force to overwrite it." % out)
		quit(1)
		return
	var data := map.terrain
	if data == null:
		push_error("The map '%s' has no terrain in its MapDefinition." % map.tag)
		quit(1)
		return
	var error := export_data(data, out)
	if error != OK:
		push_error("Could not write %s (error %d)." % [out, error])
		quit(1)
		return
	print("terrain_glb: written %s (%d vertices, %d indices)" % [out, data.vertices.size(), data.indices.size()])
	quit(0)


## MapTerrainData -> .glb, written by hand so the file is the exact inverse of tools/terrain_import.gd:
##  - POSITION = data.vertices; indices = data.indices with each triangle's 2nd and 3rd index swapped (glTF is
##    counter-clockwise; Godot's importer and the post-import both swap them back);
##  - NORMAL = the smooth visual normal Terrain shows, COLOR_0 = tile id and local uv (alpha 0 on walls);
##  - _FLAT_NORMAL = data.normals, which the post-import reads back into MapTerrainData.
## Also used by debug/suite/terrain_bake_cases.gd for its edited copies.
static func export_data(data: MapTerrainData, out: String) -> Error:
	var terrain := Terrain.new()
	terrain.shape = TerrainShape.with_data(data)
	terrain.add_child(terrain.shape)
	var arrays := terrain.bake_arrays()
	terrain.free()
	if arrays.is_empty():
		return ERR_INVALID_DATA
	var swapped := data.indices.duplicate()
	for k in range(0, swapped.size(), 3):
		swapped[k + 1] = data.indices[k + 2]
		swapped[k + 2] = data.indices[k + 1]
	var parts := [
		data.vertices.to_byte_array(),
		(arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).to_byte_array(),
		(arrays[Mesh.ARRAY_COLOR] as PackedColorArray).to_byte_array(),
		data.normals.to_byte_array(),
		swapped.to_byte_array()]
	var bin := PackedByteArray()
	var views := []
	for part in parts:
		views.append({"buffer": 0, "byteOffset": bin.size(), "byteLength": part.size()})
		bin.append_array(part)
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for v in data.vertices:
		low = low.min(v)
		high = high.max(v)
	var count := data.vertices.size()
	var accessors := [
		{"bufferView": 0, "componentType": GlbImport.COMPONENT_FLOAT, "count": count, "type": "VEC3", "min": [low.x, low.y, low.z], "max": [high.x, high.y, high.z]},
		{"bufferView": 1, "componentType": GlbImport.COMPONENT_FLOAT, "count": count, "type": "VEC3"},
		{"bufferView": 2, "componentType": GlbImport.COMPONENT_FLOAT, "count": count, "type": "VEC4"},
		{"bufferView": 3, "componentType": GlbImport.COMPONENT_FLOAT, "count": count, "type": "VEC3"},
		{"bufferView": 4, "componentType": GlbImport.COMPONENT_UINT, "count": data.indices.size(), "type": "SCALAR"}]
	var document := {
		"asset": {"version": "2.0", "generator": "terrain_glb_export.gd"},
		"scene": 0, "scenes": [{"nodes": [0]}],
		"nodes": [{"name": "Terrain", "mesh": 0}],
		"meshes": [{"name": "Terrain", "primitives": [{"mode": 4, "indices": 4,
				"attributes": {"POSITION": 0, "NORMAL": 1, "COLOR_0": 2, "_FLAT_NORMAL": 3}}]}],
		"accessors": accessors, "bufferViews": views, "buffers": [{"byteLength": bin.size()}]}
	var json := JSON.stringify(document).to_utf8_buffer()
	while json.size() % 4 != 0:
		json.append(0x20)
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_32(GlbImport.GLB_MAGIC)
	file.store_32(2)
	file.store_32(12 + 8 + json.size() + 8 + bin.size())
	file.store_32(json.size())
	file.store_32(GlbImport.CHUNK_JSON)
	file.store_buffer(json)
	file.store_32(bin.size())
	file.store_32(GlbImport.CHUNK_BIN)
	file.store_buffer(bin)
	file.close()
	return OK
