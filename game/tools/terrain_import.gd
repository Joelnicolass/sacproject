@tool
extends EditorScenePostImport

## Post-import of assets/original/maps/<map>/terrain.glb (RFC-035c). The glb is the source of truth for the ground:
##  1. reads the glb buffers directly (no ImporterMesh, so vertex and index order are exactly the file's);
##  2. validates the 10 m grid and fails the import naming the bad cell;
##  3. writes terrain.res (MapTerrainData) next to the glb, only when it changed;
##  4. returns the mesh instance as the scene root, its mesh rebuilt by Terrain from the data, with a trimesh Collision child (faces in index order).
## The static helpers are shared with tools/bake/terrain_glb_export.gd and debug/suite/terrain_bake_cases.gd.

const TERRAIN_SCRIPT := "res://scenes/map/terrain/terrain.gd"
const GLB_MAGIC := 0x46546C67
const CHUNK_JSON := 0x4E4F534A
const CHUNK_BIN := 0x004E4942
const COMPONENT_UBYTE := 5121
const COMPONENT_USHORT := 5123
const COMPONENT_UINT := 5125
const COMPONENT_FLOAT := 5126
const CELL := 10.0
const GRID_TOLERANCE := 1e-3
const WALL_AREA := 0.01
const MAX_GROUND_PER_CELL := 2


func _post_import(scene: Node) -> Object:
	var source := get_source_file()
	var read := read_glb(source)
	if read.has("error"):
		push_error("terrain import %s: %s" % [source, read["error"]])
		return null
	var data: MapTerrainData = read["data"]
	var problem := validate(data)
	if problem != "":
		push_error("terrain import %s: %s" % [source, problem])
		return null
	_write_data(data, source.get_base_dir().path_join("terrain.res"))
	var terrain := _find_mesh_instance(scene)
	if terrain == null:
		push_error("terrain import %s: the glb has no mesh instance." % source)
		return null
	if terrain != scene:
		terrain.get_parent().remove_child(terrain)
		terrain.owner = null
		scene.free()
	terrain.name = "Terrain"
	terrain.transform = Transform3D.IDENTITY
	# The importer may convert or reorder COLOR_0 (tile id + uv): the glb only supplies positions. The visual mesh is
	# the one Terrain builds from the data at runtime, so it is identical by construction.
	var visual := _runtime_mesh(data, _tiles_for(source))
	if visual == null:
		push_error("terrain import %s: could not build the visual mesh (is tiles.png imported yet?)." % source)
		return null
	terrain.mesh = visual
	_add_collision(terrain, data)
	return terrain


## terrain.res is derived: it is rewritten only when its arrays differ, so a re-import without edits leaves git clean.
func _write_data(data: MapTerrainData, out: String) -> void:
	var old: MapTerrainData = null
	if ResourceLoader.exists(out):
		old = ResourceLoader.load(out, "", ResourceLoader.CACHE_MODE_IGNORE) as MapTerrainData
	if old != null and old.vertices == data.vertices and old.normals == data.normals and old.indices == data.indices:
		return
	var error := ResourceSaver.save(data, out)
	if error != OK:
		push_error("terrain import: could not write %s (error %d)." % [out, error])


## Terrain's own arrays (tile COLOR, smooth normals) through terrain.gd, so there is a single code path.
func _runtime_mesh(data: MapTerrainData, tiles_path: String) -> ArrayMesh:
	var builder := MeshInstance3D.new()
	builder.set_script(load(TERRAIN_SCRIPT))
	builder.set("data", data)
	builder.set("tiles_path", tiles_path)
	var arrays: Array = []
	if not tiles_path.is_empty() and load(tiles_path) != null:
		arrays = builder.call("bake_arrays")  # dynamic: a post-import script; it names no class_name it may run before (load + set_script)
	var smooth: bool = builder.get("smooth_ground")
	builder.free()
	if arrays.is_empty():
		return null
	var built := ArrayMesh.new()
	built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	built.set_meta("smooth_ground", smooth)
	return built


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null


func _add_collision(terrain: MeshInstance3D, data: MapTerrainData) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	var shape_node := CollisionShape3D.new()
	shape_node.name = "Shape"
	shape_node.shape = collision_shape(data)
	terrain.add_child(body)
	body.owner = terrain
	body.add_child(shape_node)
	shape_node.owner = terrain


## The ground trimesh, made by the same call Terrain's runtime mesh used (Mesh.create_trimesh_shape), so it is
## what the collision was before the glb.
static func collision_shape(data: MapTerrainData) -> ConcavePolygonShape3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.vertices
	arrays[Mesh.ARRAY_INDEX] = data.indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh.create_trimesh_shape()


## Checks the grid rules of the ground. Returns "" when valid, otherwise a message naming the first bad cell
## as "cell (x, z)" (10 m cells). Ground vertices must sit on multiples of 10 m in x/z (1e-3), and a cell holds at
## most 2 ground triangles. Walls are the zero-area triangles seen from above (vertical by definition); a wall vertex
## moved in x/z stops being vertical, so it is read as ground and fails the grid check.
static func validate(data: MapTerrainData) -> String:
	if data == null or not data.is_valid():
		return "the terrain is empty or its normals do not match its vertices."
	var vertices := data.vertices
	var indices := data.indices
	var per_cell := {}
	for t in range(0, indices.size(), 3):
		var a := vertices[indices[t]]
		var b := vertices[indices[t + 1]]
		var c := vertices[indices[t + 2]]
		if absf((b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x)) < WALL_AREA:
			continue
		for corner in [a, b, c]:
			var off_x := absf(corner.x - roundf(corner.x / CELL) * CELL)
			var off_z := absf(corner.z - roundf(corner.z / CELL) * CELL)
			if off_x > GRID_TOLERANCE or off_z > GRID_TOLERANCE:
				return "cell (%d, %d): vertex (%.4f, %.4f, %.4f) is off the 10 m grid. Only Y may change in Blender." % [
						roundi(corner.x / CELL), roundi(corner.z / CELL), corner.x, corner.y, corner.z]
		var cell := Vector2i(roundi(minf(minf(a.x, b.x), c.x) / CELL), roundi(minf(minf(a.z, b.z), c.z) / CELL))
		per_cell[cell] = int(per_cell.get(cell, 0)) + 1
		if per_cell[cell] > MAX_GROUND_PER_CELL:
			return "cell (%d, %d): has more than %d ground triangles. The topology cannot change." % [cell.x, cell.y, MAX_GROUND_PER_CELL]
	return ""


## Reads the ground out of a .glb: {"data": MapTerrainData} or {"error": String}. Triangles keep the order of the
## file, flipped back to Godot's winding (glTF is counter-clockwise; the file holds each triangle's 2nd and 3rd index
## swapped, and Godot's importer swaps them back too). Needs POSITION, NORMAL and indices (float accessors, triangles) and identity node transforms.
static func read_glb(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "cannot open %s." % path}
	var bytes := file.get_buffer(file.get_length())
	file.close()
	if bytes.size() < 20 or bytes.decode_u32(0) != GLB_MAGIC or bytes.decode_u32(4) != 2:
		return {"error": "not a binary glTF 2.0 file."}
	var json_text := ""
	var bin := PackedByteArray()
	var at := 12
	while at + 8 <= bytes.size():
		var length := bytes.decode_u32(at)
		var kind := bytes.decode_u32(at + 4)
		var chunk := bytes.slice(at + 8, at + 8 + length)
		if kind == CHUNK_JSON:
			json_text = chunk.get_string_from_utf8()
		elif kind == CHUNK_BIN and bin.is_empty():
			bin = chunk
		at += 8 + length
	var json = JSON.parse_string(json_text)
	if not (json is Dictionary) or bin.is_empty():
		return {"error": "the glb has no readable JSON or BIN chunk."}
	var nodes: Array = json.get("nodes", [])
	for node in nodes:
		if not _identity_transform(node):
			return {"error": "node '%s' has a transform. Apply location, rotation and scale in Blender." % str(node.get("name", "?"))}
	var mesh_ids: Array = []
	for node in nodes:
		if node.has("mesh") and not mesh_ids.has(int(node["mesh"])):
			mesh_ids.append(int(node["mesh"]))
	if mesh_ids.is_empty():
		return {"error": "the glb has no mesh node."}
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for mesh_id in mesh_ids:
		for primitive in json["meshes"][mesh_id].get("primitives", []):
			var base := vertices.size()
			var attributes: Dictionary = primitive.get("attributes", {})
			if int(primitive.get("mode", 4)) != 4 or not attributes.has("POSITION") or not attributes.has("NORMAL") or not primitive.has("indices"):
				return {"error": "every primitive needs triangles with POSITION, NORMAL and indices (export normals)."}
			var positions := _read_vec3(json, bin, int(attributes["POSITION"]))
			# The glb's NORMAL is the smooth visual normal; the data's flat normal rides in _FLAT_NORMAL
			# (Blender drops it on re-export, and then NORMAL is used).
			var primitive_normals := _read_vec3(json, bin, int(attributes.get("_FLAT_NORMAL", attributes["NORMAL"])))
			var primitive_indices := _read_indices(json, bin, int(primitive["indices"]))
			if positions.is_empty() or primitive_normals.size() != positions.size() or primitive_indices.is_empty() or primitive_indices.size() % 3 != 0:
				return {"error": "unsupported or inconsistent accessors in a primitive."}
			vertices.append_array(positions)
			normals.append_array(primitive_normals)
			for k in range(0, primitive_indices.size(), 3):
				var first := primitive_indices[k]
				var second := primitive_indices[k + 1]
				var third := primitive_indices[k + 2]
				if maxi(first, maxi(second, third)) >= positions.size():
					return {"error": "an index points past the vertex list."}
				indices.append(base + first)
				indices.append(base + third)
				indices.append(base + second)
	var data := MapTerrainData.new()
	data.vertices = vertices
	data.normals = normals
	data.indices = indices
	return {"data": data}


static func _identity_transform(node: Dictionary) -> bool:
	if node.has("matrix"):
		var identity := [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
		for i in 16:
			if absf(float(node["matrix"][i]) - float(identity[i])) > 1e-6:
				return false
	return _close(node.get("translation", [0, 0, 0]), [0, 0, 0]) \
			and _close(node.get("rotation", [0, 0, 0, 1]), [0, 0, 0, 1]) \
			and _close(node.get("scale", [1, 1, 1]), [1, 1, 1])


static func _close(values: Array, expected: Array) -> bool:
	for i in expected.size():
		if absf(float(values[i]) - float(expected[i])) > 1e-6:
			return false
	return true


## Byte range of an accessor: [start, element stride in bytes, count]. Empty when sparse or missing its buffer view.
static func _accessor_layout(json: Dictionary, accessor_id: int, element_size: int) -> Array:
	var accessor: Dictionary = json["accessors"][accessor_id]
	if accessor.has("sparse") or not accessor.has("bufferView"):
		return []
	var view: Dictionary = json["bufferViews"][int(accessor["bufferView"])]
	var stride := int(view.get("byteStride", 0))
	if stride == 0:
		stride = element_size
	return [int(view.get("byteOffset", 0)) + int(accessor.get("byteOffset", 0)), stride, int(accessor["count"])]


static func _read_vec3(json: Dictionary, bin: PackedByteArray, accessor_id: int) -> PackedVector3Array:
	var result := PackedVector3Array()
	var accessor: Dictionary = json["accessors"][accessor_id]
	var layout := _accessor_layout(json, accessor_id, 12)
	if layout.is_empty() or int(accessor["componentType"]) != COMPONENT_FLOAT or accessor["type"] != "VEC3":
		return result
	var start: int = layout[0]
	var stride: int = layout[1]
	var count: int = layout[2]
	if start + (count - 1) * stride + 12 > bin.size():
		return result
	result.resize(count)
	if stride == 12:
		var floats := bin.slice(start, start + count * 12).to_float32_array()
		for i in count:
			result[i] = Vector3(floats[i * 3], floats[i * 3 + 1], floats[i * 3 + 2])
	else:
		for i in count:
			var at := start + i * stride
			result[i] = Vector3(bin.decode_float(at), bin.decode_float(at + 4), bin.decode_float(at + 8))
	return result


static func _read_indices(json: Dictionary, bin: PackedByteArray, accessor_id: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var accessor: Dictionary = json["accessors"][accessor_id]
	var component := int(accessor["componentType"])
	var size := 4 if component == COMPONENT_UINT else (2 if component == COMPONENT_USHORT else 1)
	var layout := _accessor_layout(json, accessor_id, size)
	if layout.is_empty() or accessor["type"] != "SCALAR" or not [COMPONENT_UBYTE, COMPONENT_USHORT, COMPONENT_UINT].has(component):
		return result
	var start: int = layout[0]
	var stride: int = layout[1]
	var count: int = layout[2]
	if start + (count - 1) * stride + size > bin.size():
		return result
	if component == COMPONENT_UINT and stride == 4:
		return bin.slice(start, start + count * 4).to_int32_array()
	result.resize(count)
	for i in count:
		var at := start + i * stride
		if component == COMPONENT_UINT:
			result[i] = bin.decode_u32(at)
		elif component == COMPONENT_USHORT:
			result[i] = bin.decode_u16(at)
		else:
			result[i] = bin[at]
	return result


## The tile map of the map whose terrain lives next to `source`: its MapDefinition says it, else a tiles.png beside the
## glb. Import runs before any map is active (fresh clone, no cache), so the active map can't be asked.
func _tiles_for(source: String) -> String:
	var folder := source.get_base_dir()
	var catalog := load("res://data/maps/map_catalog.tres") as MapCatalog
	if catalog != null:
		for definition in catalog.maps:
			if definition != null and definition.terrain_path.get_base_dir() == folder and not definition.tiles_path.is_empty():
				return definition.tiles_path
	var beside := folder.path_join("tiles.png")
	return beside if ResourceLoader.exists(beside) else ""
