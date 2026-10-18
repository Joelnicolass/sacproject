extends SceneTree

## RFC-035a: the baked ground mesh (terrain_mesh.res) equals the mesh Terrain builds at runtime, array by array,
## and the scene's Terrain shows the saved file. Prints one line per check and TERRAIN_BAKE PASS / TERRAIN_BAKE FAIL.
## "$GODOT" --headless --path game --script res://debug/terrain_bake_cases.gd
## Needs terrain_mesh.res (tools/bake_terrain_mesh.gd) and the project imported.

const TERRAIN_SCRIPT := "res://scenes/world/terrain.gd"
const WORLD_SCENE := "res://scenes/world/high_noon.tscn"
const ARRAY_NAMES := ["vertex", "normal", "tangent", "color", "uv", "uv2", "custom0", "custom1", "custom2", "custom3", "bones", "weights", "index"]

var _failed := 0


func _initialize() -> void:
	var path := OriginalAssets.map("high_noon", "terrain_mesh.res")
	var baked := load(path) as ArrayMesh if ResourceLoader.exists(path) else null
	_check("file_loads", baked != null, path)
	if baked == null:
		_finish()
		return
	# Runtime-built: a Terrain made from the script alone has no saved mesh, so it builds its own in _ready.
	var terrain := MeshInstance3D.new()
	terrain.set_script(load(TERRAIN_SCRIPT))
	terrain.set("data", load(OriginalAssets.HIGH_NOON_TERRAIN))
	root.add_child(terrain)
	await process_frame
	var built := terrain.mesh as ArrayMesh
	_check("runtime_mesh_built", built != null and built.resource_path.is_empty())
	if built != null:
		_compare(baked, built)
	_check("meta_smooth_ground", bool(baked.get_meta("smooth_ground", false)) == bool(terrain.get("smooth_ground")))
	terrain.queue_free()
	# The scene shows the saved file (not a rebuilt copy) and keeps the ground index of the data.
	var packed := load(WORLD_SCENE) as PackedScene
	var world: Node = packed.instantiate() if packed else null
	var scene_terrain: Node = world.get_node_or_null("Terrain") if world else null
	_check("scene_terrain_found", scene_terrain != null)
	if scene_terrain != null:
		_check("scene_mesh_is_file", scene_terrain.mesh != null and scene_terrain.mesh.resource_path == path, str(scene_terrain.mesh.resource_path if scene_terrain.mesh else "null"))
	if world:
		world.free()
	_finish()


func _compare(baked: ArrayMesh, built: ArrayMesh) -> void:
	_check("surface_count", baked.get_surface_count() == built.get_surface_count() and baked.get_surface_count() == 1)
	_check("aabb", baked.get_aabb().is_equal_approx(built.get_aabb()), "%s vs %s" % [baked.get_aabb(), built.get_aabb()])
	var left := baked.surface_get_arrays(0)
	var right := built.surface_get_arrays(0)
	for slot in Mesh.ARRAY_MAX:
		_check("array_%s" % ARRAY_NAMES[slot], left[slot] == right[slot])


func _check(label: String, ok: bool, detail := "") -> void:
	if not ok:
		_failed += 1
	print("%s %s%s" % ["PASS" if ok else "FAIL", label, (" " + detail) if detail != "" else ""])


func _finish() -> void:
	print("TERRAIN_BAKE %s" % ("PASS" if _failed == 0 else "FAIL"))
	quit(0 if _failed == 0 else 1)
