extends SceneTree

## RFC-033 (033c) parity audit of the static models: for every prop, the mesh the game now loads from
## assets/original/props/<name>.glb (BodyCatalog.mesh) equals the one it used to build, vertex by vertex:
##   - the baked cache/baked/props/<name>.res (what BodyCatalog loaded before), and
##   - ObjMesh.build() of the OBJ in cache/look (what the retired bake_bodies.gd baked from).
## Per prop: surfaces, surface names, triangle corners (position in mm, uv, normal), winding, shared materials.
## Deleted in 033i, together with cache/.
##   bash agent/harness/godot_run.sh "$GODOT" --headless --path game --script res://tools/audit_original_props.gd
## The .glb.import has meshes/force_disable_compression=true: without it Godot stores positions on a 16 bit grid over
## the mesh box (0.3 mm on a 14 m building, 27 mm on the 1.1 km sky bubble) and the speckle of body_gallery changes.
## The file itself is compared with `python3 tools/import_props.py --verify`. Exits 1 when a prop is beyond LIMIT_MM.

const CATALOG := "res://cache/look/persephone/catalog.json"
const BAKED := "res://cache/baked/props/"
const LIMIT_MM := 0.01

var _failed := 0


func _initialize() -> void:
	var obj = load("res://scenes/world/obj_mesh.gd")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var items: Array = []
	for item: Dictionary in catalog.get("structures", []):
		items.append([str(item["name"]), str(item["mesh"]), false])
	for item: Dictionary in catalog.get("plants", []):
		items.append([str(item["name"]), str(item["mesh"]), true])
	var worst_pos := 0.0
	var worst_uv := 0.0
	var worst_normal := 0.0
	var worst_name := ""
	var checked := 0
	var surfaces_total := 0
	var shared := {}
	for item: Array in items:
		var name: String = item[0]
		var glb := BodyCatalog._prop_mesh(name)  # mesh() returns null headless: the dedicated never loads meshes
		if glb == null:
			_fail("%s: _prop_mesh is null" % name)
			continue
		var options := {obj.FOLIAGE: true} if item[2] else {}
		var fresh: ArrayMesh = obj.build(item[1], options)
		var baked := ResourceLoader.load(BAKED + name + ".res") as Mesh
		if fresh == null or baked == null:
			_fail("%s: reference missing (OBJ %s, baked %s)" % [name, fresh != null, baked != null])
			continue
		checked += 1
		surfaces_total += glb.get_surface_count()
		if BodyCatalog._prop_mesh(name) != glb:
			_fail("%s: the mesh is not shared between calls" % name)
		for i in glb.get_surface_count():
			var mat := glb.surface_get_material(i)
			if mat == null or (mat as StandardMaterial3D).albedo_texture == null:
				_fail("%s surface %d: no textured material" % [name, i])
			elif shared.has(mat.albedo_texture.resource_path) and shared[mat.albedo_texture.resource_path] != mat:
				_fail("%s surface %d: a second material for %s" % [name, i, mat.albedo_texture.resource_path])
			else:
				shared[mat.albedo_texture.resource_path] = mat
			if fresh and i < fresh.get_surface_count() and glb.surface_get_name(i) != fresh.surface_get_name(i):
				_fail("%s surface %d: name '%s' vs '%s'" % [name, i, glb.surface_get_name(i), fresh.surface_get_name(i)])
		for reference: Mesh in [fresh, baked]:
			var diff := _compare(name, glb, reference)
			if diff.is_empty():
				continue
			if diff.has("error"):
				_fail("%s: %s" % [name, diff["error"]])
				continue
			if float(diff["pos"]) > worst_pos:
				worst_pos = float(diff["pos"])
				worst_name = name
			worst_uv = maxf(worst_uv, float(diff["uv"]))
			worst_normal = maxf(worst_normal, float(diff["normal"]))
			if float(diff["pos"]) > LIMIT_MM or float(diff["uv"]) > 0.01 or float(diff["normal"]) > 0.05:
				_fail("%s vs %s: pos %.4f mm, uv %.5f, normal %.4f, size %s" % [name, "obj" if reference == fresh else "baked", diff["pos"], diff["uv"], diff["normal"], glb.get_aabb().size])
	print("audit_original_props: %d/%d props, %d surfaces, %d distinct textured materials, max position error %.5f mm (%s), max uv error %s, max normal error %s, %d failed" % [
		checked, items.size(), surfaces_total, shared.size(), worst_pos, worst_name, snappedf(worst_uv, 1e-9), snappedf(worst_normal, 1e-9), _failed])
	quit(1 if _failed > 0 else 0)


func _fail(message: String) -> void:
	_failed += 1
	if _failed <= 40:
		print("FAIL ", message)


## {pos (mm), uv, normal} maximum errors, or {error} when the shape differs. The importer reorders triangles and welds
## vertices, so each triangle of `got` is matched to the closest unused triangle of `want` with the same winding
## (corners rotated to the best fit) through a grid on the centroid; the error is the worst corner distance of the pairs.
func _compare(name: String, got: Mesh, want: Mesh) -> Dictionary:
	if got.get_surface_count() != want.get_surface_count():
		return {"error": "%d surfaces vs %d" % [got.get_surface_count(), want.get_surface_count()]}
	var out := {"pos": 0.0, "uv": 0.0, "normal": 0.0}
	for s in got.get_surface_count():
		var a := _triangles(got, s)
		var b := _triangles(want, s)
		if a.size() != b.size():
			return {"error": "surface %d: %d triangles vs %d" % [s, a.size(), b.size()]}
		var grid := {}
		for i in b.size():
			var cell := _cell(b[i])
			if not grid.has(cell):
				grid[cell] = []
			grid[cell].append(i)
		var used := {}
		for ta: Array in a:
			var best := -1
			var best_shift := 0
			var best_err := INF
			var home := _cell(ta)
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					for dz in range(-1, 2):
						var near: Array = grid.get(home + Vector3i(dx, dy, dz), [])
						for j: int in near:
							if used.has(j):
								continue
							var tb: Array = b[j]
							for shift in 3:
								var err := 0.0
								var attrs := 0.0
								for c in 3:
									err = maxf(err, (ta[c] - tb[(c + shift) % 3]).length())
									attrs += (ta[3 + c] - tb[3 + (c + shift) % 3]).length() + (ta[6 + c] - tb[6 + (c + shift) % 3]).length()
								if err + 0.005 * attrs < best_err:
									best_err = err + 0.005 * attrs
									best = j
									best_shift = shift
			if best < 0:
				return {"error": "surface %d: a triangle has no counterpart within 3 cells" % s}
			used[best] = true
			var tb: Array = b[best]
			for c in 3:
				out["pos"] = maxf(out["pos"], (ta[c] - tb[(c + best_shift) % 3]).length() * 1000.0)
				out["uv"] = maxf(out["uv"], (ta[3 + c] - tb[3 + (c + best_shift) % 3]).length())
				out["normal"] = maxf(out["normal"], (ta[6 + c] - tb[6 + (c + best_shift) % 3]).length())
	return out


func _cell(tri: Array) -> Vector3i:
	return Vector3i(((tri[0] + tri[1] + tri[2]) / 3.0 / 0.05).floor())


## The triangles of a surface as [p0, p1, p2, uv0, uv1, uv2, n0, n1, n2].
func _triangles(mesh: Mesh, surface: int) -> Array:
	var arrays := mesh.surface_get_arrays(surface)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		indices.resize(verts.size())
		for i in verts.size():
			indices[i] = i
	var out: Array = []
	for t in range(0, indices.size() - 2, 3):
		var ids := [indices[t], indices[t + 1], indices[t + 2]]
		var row: Array = []
		for k in 3:
			row.append(verts[ids[k]])
		for k in 3:
			row.append(uvs[ids[k]] if ids[k] < uvs.size() else Vector2.ZERO)
		for k in 3:
			row.append(normals[ids[k]] if ids[k] < normals.size() else Vector3.ZERO)
		out.append(row)
	return out
