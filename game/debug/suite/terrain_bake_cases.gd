extends SceneTree

## RFC-035c: terrain.glb round trip. Prints one line per check and TERRAIN_BAKE PASS / TERRAIN_BAKE FAIL.
##  - the glb read by the post-import equals the frozen reference terrain.res array by array, and its trimesh faces equal the ones the
##    runtime mesh gives (so sim, heights and collision are the ones of today);
##  - the imported scene shows the glb mesh (same vertices/indices as the runtime mesh) and carries the Collision;
##  - a vertex moved 3 m in X fails validation naming its cell;
##  - lifting a triangle 5 m in Y through a glb changes ground_height there by 5 m.
## "$GODOT" --headless --path game --script res://debug/suite/terrain_bake_cases.gd
## Needs terrain.glb imported once (godot --headless --path game --import) and git showing terrain.res unchanged.

const TERRAIN_SCRIPT := "res://scenes/map/terrain/terrain.gd"
const WORLD_SCENE := "res://scenes/match/high_noon.tscn"
const GlbImport := preload("res://tools/terrain_import.gd")
const GlbExport := preload("res://tools/bake/terrain_glb_export.gd")
const REFERENCE := "res://debug/map/terrain_reference.res"
const EDIT_X := 3.0
const LIFT_Y := 5.0

var _failed := 0


func _initialize() -> void:
	var glb := OriginalAssets.map("high_noon", "terrain.glb")
	var current := load(OriginalAssets.HIGH_NOON_TERRAIN) as MapTerrainData
	# debug/map/terrain_reference.res is a frozen copy of the committed (original) terrain.res: neither the import
	# nor the glb may drift from it.
	var reference := load(REFERENCE) as MapTerrainData
	_check("reference_loads", reference != null)
	if reference == null:
		_finish()
		return
	_check("terrain_res_unchanged", current != null and current.vertices == reference.vertices \
			and current.normals == reference.normals and current.indices == reference.indices)
	current = reference
	_check("glb_exists", FileAccess.file_exists(glb), glb)
	_check("terrain_res_loads", current != null)
	if current == null or not FileAccess.file_exists(glb):
		_finish()
		return
	var read := GlbImport.read_glb(glb)
	_check("glb_reads", read.has("data"), str(read.get("error", "")))
	if not read.has("data"):
		_finish()
		return
	var data: MapTerrainData = read["data"]
	_check("data_vertices", data.vertices == current.vertices)
	_check("data_normals", data.normals == current.normals)
	_check("data_indices", data.indices == current.indices)
	_check("grid_valid", GlbImport.validate(data) == "", GlbImport.validate(data))
	await _round_trip(current)
	await _scene_instance(current)
	await _edits(current)
	_finish()


## The mesh Terrain builds at runtime from terrain.res: its trimesh is what the sim and the collision had so far.
func _round_trip(current: MapTerrainData) -> void:
	var terrain := await _built_terrain(current)
	var built := terrain.mesh as ArrayMesh
	_check("runtime_mesh_built", built != null)
	if built != null:
		var expected := built.create_trimesh_shape().get_faces()
		_check("faces_from_data", GlbImport.collision_shape(current).get_faces() == expected)
	terrain.free()


func _scene_instance(current: MapTerrainData) -> void:
	var glb := OriginalAssets.map("high_noon", "terrain.glb")
	var world: Node = (load(WORLD_SCENE) as PackedScene).instantiate()
	var scene_terrain := world.get_node_or_null("Terrain") as MeshInstance3D
	_check("scene_terrain_found", scene_terrain != null)
	if scene_terrain == null:
		world.free()
		return
	_check("scene_terrain_is_glb", scene_terrain.scene_file_path == glb, scene_terrain.scene_file_path)
	_check("scene_script_data", scene_terrain.has_method("ground_height") and scene_terrain.get("data") != null)
	var shape_node := scene_terrain.get_node_or_null("Collision/Shape") as CollisionShape3D
	_check("scene_collision_found", shape_node != null and shape_node.shape is ConcavePolygonShape3D)
	if shape_node != null:
		var expected := GlbImport.collision_shape(current).get_faces()
		_check("scene_collision_faces", (shape_node.shape as ConcavePolygonShape3D).get_faces() == expected)
	var mesh := scene_terrain.mesh as ArrayMesh
	_check("scene_mesh_found", mesh != null and mesh.get_surface_count() == 1)
	if mesh != null and mesh.get_surface_count() == 1:
		var terrain := await _built_terrain(current)
		var left := mesh.surface_get_arrays(0)
		var right := (terrain.mesh as ArrayMesh).surface_get_arrays(0)
		for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_INDEX]:
			_check("scene_mesh_slot_%d" % slot, left[slot] == right[slot])
		terrain.free()
	world.free()


func _edits(current: MapTerrainData) -> void:
	# A ground vertex moved in X, written to a glb and read back like the import does.
	var first := _first_ground_triangle(current)
	var moved := _copy(current)
	var vertex := current.indices[first * 3]
	var shifted := current.vertices[vertex]
	shifted.x += EDIT_X
	moved.vertices[vertex] = shifted
	var expected_cell := "cell (%d, %d)" % [roundi(shifted.x / 10.0), roundi(shifted.z / 10.0)]
	var problem := _through_glb(moved)
	_check("moved_vertex_fails", problem != "", problem)
	_check("moved_vertex_names_cell", problem.contains(expected_cell), "%s in: %s" % [expected_cell, problem])
	# A triangle lifted 5 m in Y keeps a valid grid and raises ground_height there by exactly that much.
	var a := current.vertices[current.indices[first * 3]]
	var b := current.vertices[current.indices[first * 3 + 1]]
	var c := current.vertices[current.indices[first * 3 + 2]]
	var probe := (a + b + c) / 3.0
	var lifted := _copy(current)
	for i in lifted.vertices.size():
		var p := lifted.vertices[i]
		if p == a or p == b or p == c:
			p.y += LIFT_Y
			lifted.vertices[i] = p
	_check("lifted_grid_valid", _through_glb(lifted, "user://terrain_bake_lifted.glb") == "")
	var after := await _terrain_from_glb("user://terrain_bake_lifted.glb")
	var before := await _built_terrain(current)
	var delta: float = after.ground_height(probe.x, probe.z) - before.ground_height(probe.x, probe.z)
	_check("lifted_height_delta", absf(delta - LIFT_Y) < 1e-3, "delta %.5f at (%.1f, %.1f)" % [delta, probe.x, probe.z])
	before.free()
	after.free()
	DirAccess.remove_absolute("user://terrain_bake_lifted.glb")
	DirAccess.remove_absolute("user://terrain_bake_moved.glb")


## Writes `data` to a temp glb and validates what the post-import would read from it. "" when valid.
func _through_glb(data: MapTerrainData, path := "user://terrain_bake_moved.glb") -> String:
	var error := GlbExport.export_data(data, path)
	if error != OK:
		return "export failed (%d)" % error
	var read := GlbImport.read_glb(path)
	if read.has("error"):
		return str(read["error"])
	return GlbImport.validate(read["data"])


func _terrain_from_glb(path: String) -> MeshInstance3D:
	var read := GlbImport.read_glb(path)
	return await _built_terrain(read["data"] if read.has("data") else null)


## A Terrain made from the script alone, built in _ready from `data` (no saved mesh).
func _built_terrain(data: MapTerrainData) -> MeshInstance3D:
	var terrain := MeshInstance3D.new()
	terrain.set_script(load(TERRAIN_SCRIPT))
	terrain.set("data", data)
	root.add_child(terrain)
	await process_frame
	return terrain


func _first_ground_triangle(data: MapTerrainData) -> int:
	for t in range(0, data.indices.size(), 3):
		var a := data.vertices[data.indices[t]]
		var b := data.vertices[data.indices[t + 1]]
		var c := data.vertices[data.indices[t + 2]]
		if absf((b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x)) >= 0.01:
			return t / 3
	return 0


func _copy(data: MapTerrainData) -> MapTerrainData:
	var copy := MapTerrainData.new()
	copy.vertices = data.vertices.duplicate()
	copy.normals = data.normals.duplicate()
	copy.indices = data.indices.duplicate()
	return copy


func _check(label: String, ok: bool, detail := "") -> void:
	if not ok:
		_failed += 1
	print("%s %s%s" % ["PASS" if ok else "FAIL", label, (" " + detail) if detail != "" else ""])


func _finish() -> void:
	print("TERRAIN_BAKE %s" % ("PASS" if _failed == 0 else "FAIL"))
	quit(0 if _failed == 0 else 1)
