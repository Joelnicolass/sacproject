extends SceneTree

## Bakes High Noon's visual ground mesh into assets/original/maps/high_noon/terrain_mesh.res (RFC-035a).
## It runs the same code Terrain runs at load (Terrain.bake_mesh), so the file equals the mesh built at runtime.
## Idempotent: when the file already holds the same arrays nothing is written.
## "$GODOT" --headless --path game --script res://tools/bake_terrain_mesh.gd [-- --out=res://path/terrain_mesh.res]
## Needs the project imported once (tiles.png is read as an Image, like at runtime).

const TERRAIN_SCRIPT := "res://scenes/world/terrain.gd"


func _initialize() -> void:
	var out := OriginalAssets.map("high_noon", "terrain_mesh.res")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.substr(6)
	var data := load(OriginalAssets.HIGH_NOON_TERRAIN) as MapTerrainData
	if data == null:
		push_error("Missing %s." % OriginalAssets.HIGH_NOON_TERRAIN)
		quit(1)
		return
	var terrain := MeshInstance3D.new()
	terrain.set_script(load(TERRAIN_SCRIPT))
	terrain.set("data", data)
	var baked: ArrayMesh = terrain.call("bake_mesh")
	terrain.free()
	if baked == null:
		push_error("Terrain could not build the mesh (invalid data).")
		quit(1)
		return
	var old := load(out) as ArrayMesh if ResourceLoader.exists(out) else null
	if old != null and _same_arrays(old, baked) and old.get_meta("smooth_ground", null) == baked.get_meta("smooth_ground"):
		print("terrain_mesh: 0 written, 1 unchanged (%d vertices)" % data.vertices.size())
		quit(0)
		return
	var error := ResourceSaver.save(baked, out)
	if error != OK:
		push_error("Could not write %s (error %d)." % [out, error])
		quit(1)
		return
	print("terrain_mesh: 1 written, 0 unchanged (%d vertices) -> %s" % [data.vertices.size(), out])
	quit(0)


func _same_arrays(a: ArrayMesh, b: ArrayMesh) -> bool:
	if a.get_surface_count() != b.get_surface_count():
		return false
	for surface in a.get_surface_count():
		var left := a.surface_get_arrays(surface)
		var right := b.surface_get_arrays(surface)
		for slot in Mesh.ARRAY_MAX:
			if left[slot] != right[slot]:
				return false
	return true
