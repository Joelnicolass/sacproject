extends SceneTree

## Writes the Soul Wind's funnel mesh (scenes/spells/carrier/soul_wind_funnel.res): a twisted whirlwind 3 m tall, narrow at the foot
## and wide at the top, 32 sides by 32 rings, its texture coordinates repeated twice around and twice up. It needs no original game:
## the shape is a formula. Run it once; the result is versioned and the scene only holds the file.
##   "$GODOT" --headless --path game --script res://tools/bake/make_soul_wind_funnel.gd

const OUT := "res://scenes/spells/carrier/soul_wind_funnel.res"
const SIDES := 32
const RINGS := 32
const HEIGHT_M := 3.0
const RADIUS_M := 1.5
const REPEAT := 2.0


func _initialize() -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in RINGS + 1:
		var along := float(i) / RINGS
		var wrap_radius := RADIUS_M * (along + 0.05 * sin(TAU * i / RINGS))
		var ring_radius := wrap_radius + 0.5 * RADIUS_M * pow(along, 4.0)
		var turn := PI * i / RINGS
		for j in SIDES + 1:
			var angle := TAU * j / SIDES
			var flat_x := ring_radius * cos(angle) + 0.5 * wrap_radius * cos(turn)
			var flat_y := ring_radius * sin(angle) + 0.5 * wrap_radius * sin(turn)
			vertices.append(Vector3(flat_x, HEIGHT_M * along, -flat_y))
			uvs.append(Vector2(REPEAT * float(j) / SIDES, -REPEAT * along))
	for i in RINGS:
		for j in SIDES:
			var a := i * (SIDES + 1) + j
			var b := (i + 1) * (SIDES + 1) + j
			indices.append_array([a, b + 1, b, a, a + 1, b + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.resource_name = "soul_wind_funnel"
	var error := ResourceSaver.save(mesh, OUT)
	print(
		(
			"soul_wind_funnel: %s (%d vertices) -> %s"
			% ["saved" if error == OK else "FAILED %d" % error, vertices.size(), OUT]
		)
	)
	quit(0 if error == OK else 1)
