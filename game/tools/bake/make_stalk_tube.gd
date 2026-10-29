extends SceneTree

## Writes the Meanstalk's tube mesh (scenes/spells/stalks/stalk_tube.res): 31 segments by 24 sides
## of a unit ring, no height. The shader puts each ring on the curve of the stalk and scales it by
## the radius at its `t`, so this file only holds the topology: each vertex is the unit direction of
## its side (`VERTEX.xz`, also its normal) and its UV is (side / sides, t along the stalk). It needs
## no original game. Run it once; the result is versioned and the scene only holds the file.
##   "$GODOT" --headless --path game --script res://tools/bake/make_stalk_tube.gd

const OUT := "res://scenes/spells/stalks/stalk_tube.res"
const SEGMENTS := 31
const SIDES := 24
## The shader moves the vertices far from here: the box says where the stalk can be (a root, 60 m up
## and a bulge of 30 m).
const BOUNDS := AABB(Vector3(-40.0, -70.0, -40.0), Vector3(80.0, 140.0, 80.0))


func _initialize() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in SEGMENTS + 1:
		for j in SIDES + 1:
			var angle := TAU * j / SIDES
			var ring := Vector3(cos(angle), 0.0, sin(angle))
			vertices.append(ring)
			normals.append(ring)
			uvs.append(Vector2(float(j) / SIDES, float(i) / SEGMENTS))
	for i in SEGMENTS:
		for j in SIDES:
			var a := i * (SIDES + 1) + j
			var b := (i + 1) * (SIDES + 1) + j
			indices.append_array([a, b + 1, b, a, a + 1, b + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = BOUNDS
	mesh.resource_name = "stalk_tube"
	var error := ResourceSaver.save(mesh, OUT)
	print(
		(
			"stalk_tube: %s (%d vertices) -> %s"
			% ["saved" if error == OK else "FAILED %d" % error, vertices.size(), OUT]
		)
	)
	quit(0 if error == OK else 1)
