extends SceneTree

## Writes the Tornado's two meshes: funnel_rings.res (the wall: 128 rings of 64 sides, UV = (around, t along one half of the axis)) and
## funnel_edge.res (the ragged edge: 4 vertices per ring, UV2.x = which of the four, UV.x = the left or right of a frame, UV.y = t, COLOR.a
## 0 for the first ring). They hold topology only: TornadoLook gives the shader the seven points of the axis and their radii, and it puts
## every vertex in place. It needs no original game. Run it once; the result is versioned and the scene only holds the files.
##   "$GODOT" --headless --path game --script res://tools/bake/make_tornado_funnel.gd
## Ref: sacengine SacTornado.ensureMeshes (sacobject.d:3638-3688).

const DIR := "res://scenes/spells/tornado/"
const RINGS := 128
const SIDES := 64
## The shader moves the vertices far from here: the box says where the funnel can be (500 m up, 350 m to each side).
const BOUNDS := AABB(Vector3(-400.0, -50.0, -400.0), Vector3(800.0, 600.0, 800.0))


func _initialize() -> void:
	var ok := _save(_wall(), "funnel_rings.res") and _save(_edge(), "funnel_edge.res")
	quit(0 if ok else 1)


func _wall() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for r in RINGS:
		for k in SIDES:
			vertices.append(Vector3.ZERO)
			uvs.append(Vector2(float(k) / (SIDES - 1), float(r) / (RINGS - 1)))
	for r in RINGS - 1:
		for k in SIDES - 1:
			var a := r * SIDES + k
			indices.append_array([a + SIDES, a, a + SIDES + 1, a, a + SIDES + 1, a + 1])
	return _mesh({Mesh.ARRAY_VERTEX: vertices, Mesh.ARRAY_TEX_UV: uvs, Mesh.ARRAY_INDEX: indices})


func _edge() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for i in RINGS - 2:
		var t := float(i + 2) / (RINGS - 1)
		for slot in 4:
			vertices.append(Vector3.ZERO)
			uvs.append(Vector2(0.0 if slot == 0 or slot == 3 else 1.0, 1.0 - t))
			uv2s.append(Vector2(slot, t))
			colors.append(Color(1, 1, 1, 0.0 if i == 0 else 1.0))
	for i in RINGS - 3:
		var a := 4 * i
		indices.append_array([a, a + 1, a + 4, a + 1, a + 5, a + 4, a + 2, a + 3, a + 6, a + 3, a + 7, a + 6])
	return _mesh({Mesh.ARRAY_VERTEX: vertices, Mesh.ARRAY_TEX_UV: uvs, Mesh.ARRAY_TEX_UV2: uv2s, Mesh.ARRAY_COLOR: colors, Mesh.ARRAY_INDEX: indices})


func _mesh(data: Dictionary) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	for key in data:
		arrays[key] = data[key]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = BOUNDS
	return mesh


func _save(mesh: ArrayMesh, file: String) -> bool:
	mesh.resource_name = file.get_basename()
	var error := ResourceSaver.save(mesh, DIR + file)
	print("%s: %s (%d vertices)" % [file, "saved" if error == OK else "FAILED %d" % error, mesh.surface_get_array_len(0)])
	return error == OK
