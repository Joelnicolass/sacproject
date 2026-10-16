extends SceneTree

## Headless probe for smooth ground (RFC-019a). Loads Terrain alone and counts, on the built mesh,
## ground positions, how many of them share one normal across all their vertices, and how many wall
## triangles keep a single flat normal. Then flips smooth_ground and counts again.
## Run: Godot --headless --path game --script res://debug/terrain_normals_probe.gd

const TERRAIN_SCRIPT := "res://scenes/world/terrain.gd"
const WALL_AREA := 0.01


func _initialize() -> void:
	var terrain := MeshInstance3D.new()
	terrain.set_script(load(TERRAIN_SCRIPT))
	root.add_child(terrain)
	await process_frame
	if terrain.mesh == null:
		print("ERROR sin terreno en cache/")
		quit(1)
		return
	var has_option := "smooth_ground" in terrain
	_report("smooth_ground=%s" % [terrain.get("smooth_ground") if has_option else "n/a"], terrain.mesh)
	if has_option:
		terrain.set("smooth_ground", not terrain.get("smooth_ground"))
		_report("smooth_ground=%s" % [terrain.get("smooth_ground")], terrain.mesh)
		terrain.set("smooth_ground", not terrain.get("smooth_ground"))
		_report("smooth_ground=%s (de vuelta)" % [terrain.get("smooth_ground")], terrain.mesh)
	quit(0)


func _report(label: String, mesh: ArrayMesh) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var by_position := {}
	var walls := 0
	var flat_walls := 0
	for t in range(0, indices.size(), 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		var area := (vertices[b].x - vertices[a].x) * (vertices[c].z - vertices[a].z) - (vertices[b].z - vertices[a].z) * (vertices[c].x - vertices[a].x)
		if absf(area) < WALL_AREA:
			walls += 1
			if normals[a].is_equal_approx(normals[b]) and normals[a].is_equal_approx(normals[c]):
				flat_walls += 1
			continue
		for id in [a, b, c]:
			var key := Vector3i(roundi(vertices[id].x * 100.0), roundi(vertices[id].y * 100.0), roundi(vertices[id].z * 100.0))
			if not by_position.has(key):
				by_position[key] = []
			by_position[key].append(normals[id])
	var single := 0
	for key in by_position:
		var list: Array = by_position[key]
		var same := true
		for n in list:
			if not (n as Vector3).is_equal_approx(list[0]):
				same = false
				break
		if same:
			single += 1
	print("%s: suelo posiciones %d con_normal_unica %d paredes_planas %d/%d" % [label, by_position.size(), single, flat_walls, walls])
