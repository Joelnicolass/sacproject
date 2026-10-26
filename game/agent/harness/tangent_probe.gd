extends SceneTree

## RFC-067 P6: prints a few vertices (normal, tangent, uv) of one surface of a saved mesh, to see why its tangents fail.
##   Godot --headless --path . --script res://agent/harness/tangent_probe.gd -- res://scenes/props/meshes/pct6.res 46


func _initialize() -> void:
	create_timer(30.0).timeout.connect(quit.bind(2))
	var args := OS.get_cmdline_user_args()
	var mesh := load(args[0]) as ArrayMesh
	var surface := int(args[1])
	var arrays := mesh.surface_get_arrays(surface)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	print("TANGENT_PROBE surfaces=%d format=%d material=%s verts=%d" % [mesh.get_surface_count(), mesh.surface_get_format(surface),
		mesh.surface_get_material(surface).resource_path if mesh.surface_get_material(surface) else "-", verts.size()])
	for v in mini(8, verts.size()):
		print("v%d pos=%s n=%s t=%s uv=%s" % [v, verts[v], normals[v], Vector4(tangents[v * 4], tangents[v * 4 + 1], tangents[v * 4 + 2], tangents[v * 4 + 3]), uvs[v] if uvs.size() > v else "-"])
	quit()
