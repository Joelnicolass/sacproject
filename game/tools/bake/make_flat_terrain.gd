extends SceneTree

## RFC-044 044d: writes the ground of the test map (test_flat): a flat square of land in the middle of the 2560 m grid,
## nothing around it. A MapTerrainData like the importer's, so Terrain treats it as any other ground.
## "$GODOT" --headless --path game --script res://tools/bake/make_flat_terrain.gd [-- --out=res://...res --cells=60 --from=100 --height=10]
## Needs the project imported once (MapTerrainData is a global class). Idempotent: the same arguments write the same file.

const OUT := "res://scenes/map/maps/test_flat/terrain.res"
const CELL := 10.0


func _initialize() -> void:
	var out := OUT
	var cells := 60
	var from_cell := 100
	var height := 10.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.substr(6)
		elif argument.begins_with("--cells="):
			cells = int(argument.substr(8))
		elif argument.begins_with("--from="):
			from_cell = int(argument.substr(7))
		elif argument.begins_with("--height="):
			height = float(argument.substr(9))
	var data := MapTerrainData.new()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var side := cells + 1
	for row in side:
		for column in side:
			vertices.append(Vector3((from_cell + column) * CELL, height, (from_cell + row) * CELL))
			normals.append(Vector3.UP)
	for row in cells:
		for column in cells:
			var a := row * side + column
			var b := a + 1
			var c := a + side
			var d := c + 1
			# Clockwise seen from above: the front face looks up (Godot's winding), so the trimesh collides from above.
			indices.append_array([a, b, c, b, d, c])
	data.vertices = vertices
	data.normals = normals
	data.indices = indices
	var triangle_up := Plane(vertices[indices[0]], vertices[indices[1]], vertices[indices[2]]).normal.y
	if triangle_up <= 0.0:
		push_error("make_flat_terrain: the winding looks down; flip the indices.")
		quit(1)
		return
	var error := ResourceSaver.save(data, out)
	if error != OK:
		push_error("make_flat_terrain: could not write %s (error %d)." % [out, error])
		quit(1)
		return
	print("make_flat_terrain: %s (%d vertices, %d triangles)" % [out, vertices.size(), indices.size() / 3])
	quit(0)
