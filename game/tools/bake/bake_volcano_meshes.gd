extends SceneTree

## Writes the two meshes of the Volcano's look: volcano_lava_tube.res (the column of lava, 48 rings of 64 sides) and volcano_spatter_ring.res (the splash of lava on the ground, 24 rings of 64
## sides). They hold topology only: UV.x is the turn around the axis (0 to 1) and UV.y how far along the tube or out from the center
## (0 to 1), and the shader of each (volcano_lava / volcano_spatter.gdshader) puts every vertex in place from the
## knots and radii it holds as uniforms. It needs no original game. Run it once; the result is versioned and the scene only holds the files.
##   "$GODOT" --headless --path game --script res://tools/bake/bake_volcano_meshes.gd

const DIR := "res://scenes/spells/zones/"
const SIDES := 64
## The shaders move the vertices far from here: each box says where its mesh can be.
const LAVA_BOUNDS := AABB(Vector3(-150.0, -20.0, -150.0), Vector3(300.0, 340.0, 300.0))
const SPATTER_BOUNDS := AABB(Vector3(-30.0, -60.0, -30.0), Vector3(60.0, 120.0, 60.0))


func _initialize() -> void:
	var ok := _save(_tube(48, LAVA_BOUNDS), "volcano_lava_tube.res")
	ok = _save(_tube(24, SPATTER_BOUNDS), "volcano_spatter_ring.res") and ok
	quit(0 if ok else 1)


## `rings` + 1 rings of SIDES + 1 vertices; ring i is at UV.y = i / rings (the spatter has one ring more than the original's 24).
func _tube(rings: int, bounds: AABB) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in rings + 1:
		for j in SIDES + 1:
			vertices.append(Vector3.ZERO)
			uvs.append(Vector2(float(j) / SIDES, float(i) / rings))
			if i != 0 and j != SIDES:
				var a := (SIDES + 1) * i + j
				var up := (SIDES + 1) * (i - 1) + j
				indices.append_array([a, a + 1, up, a + 1, up + 1, up])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = bounds
	return mesh


func _save(mesh: ArrayMesh, file: String) -> bool:
	mesh.resource_name = file.get_basename()
	var error := ResourceSaver.save(mesh, DIR + file)
	print("%s: %s (%d vertices)" % [file, "saved" if error == OK else "FAILED %d" % error, mesh.surface_get_array_len(0)])
	return error == OK
