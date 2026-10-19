extends RefCounted

## Reads OBJ files (the ones tools/import/import_props.py --bodies-from takes, sacengine saveObj). One surface per usemtl, named after its label.
## Godot draws clockwise faces; the winding is checked against the file normals.
## Materials come from OriginalMaterial (textures of assets/original/textures/), never from files beside the OBJ.

## sacengine saveObj writes the bodies as (x, z, -y). The map uses (x, z, y).
const MIRROR_Z := "mirror_z"
## Widgets (plants): every face drawn on both sides, like sacengine loadWIDG.
## Cards keep normals up; ground widgets (rocks, mounds) get smooth normals per side.
const FOLIAGE := "foliage"
## Area share of near-horizontal faces above which a widget lies on the ground.
const GROUND_WIDGET_RATIO := 0.7


static func build(path: String, options: Dictionary = {}) -> ArrayMesh:
	var parsed := parse(path, bool(options.get(MIRROR_Z, false)))
	if parsed.is_empty():
		return null
	var foliage := bool(options.get(FOLIAGE, false))
	var surfaces: Array = parsed["surfaces"]
	var flip := false
	if not foliage:
		flip = _needs_flip(surfaces, parsed["has_normals"])
	var ground := foliage and is_ground_widget(surfaces)
	var model := OriginalMaterial.model_of(path)
	var built := ArrayMesh.new()
	for surface: Dictionary in surfaces:
		var verts: PackedVector3Array = surface["v"]
		if verts.is_empty():
			continue
		var uvs: PackedVector2Array = surface["u"]
		var normals: PackedVector3Array = surface["n"]
		if flip:
			for i in range(0, verts.size(), 3):
				_swap(verts, i + 1, i + 2)
				_swap_uv(uvs, i + 1, i + 2)
				_swap(normals, i + 1, i + 2)
		if foliage:
			var sides := _both_sides(verts, uvs)
			verts = sides[0]
			uvs = sides[1]
			normals = _side_normals(verts) if ground else _filled(verts.size(), Vector3.UP)
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_NORMAL] = normals
		if not parsed["has_normals"] and not foliage:
			arrays[Mesh.ARRAY_NORMAL] = null
			arrays = _smooth(arrays)
		built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var label := str(surface["label"])
		var index := built.get_surface_count() - 1
		built.surface_set_name(index, label)
		var mat := OriginalMaterial.for_label(model, label)
		if mat:
			built.surface_set_material(index, mat)
	if built.get_surface_count() == 0:
		return null
	return built


static func parse(path: String, mirror_z: bool = false) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var sign_z := -1.0 if mirror_z else 1.0
	var positions: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	var surfaces: Array = []
	var current := -1
	for line in text.split("\n"):
		var parts := line.split(" ", false)
		if parts.is_empty():
			continue
		match parts[0]:
			"v":
				if parts.size() >= 4:
					positions.append(Vector3(parts[1].to_float(), parts[2].to_float(), parts[3].to_float() * sign_z))
			"vt":
				if parts.size() >= 3:
					uvs.append(Vector2(parts[1].to_float(), 1.0 - parts[2].to_float()))
			"vn":
				if parts.size() >= 4:
					normals.append(Vector3(parts[1].to_float(), parts[2].to_float(), parts[3].to_float() * sign_z))
			"usemtl":
				surfaces.append(_bucket(parts[1] if parts.size() > 1 else ""))
				current = surfaces.size() - 1
			"f":
				if parts.size() < 4:
					continue
				if current < 0:
					surfaces.append(_bucket(""))
					current = 0
				var surface: Dictionary = surfaces[current]
				for corner in [parts[1], parts[2], parts[3]]:
					var bits: PackedStringArray = corner.split("/")
					var vi := int(bits[0]) - 1
					var ti := -1
					var ni := -1
					if bits.size() >= 2 and bits[1] != "":
						ti = int(bits[1]) - 1
					if bits.size() >= 3 and bits[2] != "":
						ni = int(bits[2]) - 1
					surface["v"].append(positions[vi])
					surface["u"].append(uvs[ti] if ti >= 0 and ti < uvs.size() else Vector2.ZERO)
					surface["n"].append(normals[ni] if ni >= 0 and ni < normals.size() else Vector3.ZERO)
	if surfaces.is_empty():
		return {}
	return {"surfaces": surfaces, "has_normals": not normals.is_empty()}


static func _bucket(label: String) -> Dictionary:
	return {"label": label, "v": PackedVector3Array(), "n": PackedVector3Array(), "u": PackedVector2Array()}


## True when the triangles face away from the file normals (or, without normals,
## inward from the mesh center).
static func _needs_flip(surfaces: Array, has_normals: bool) -> bool:
	var center := Vector3.ZERO
	var count := 0
	if not has_normals:
		for surface: Dictionary in surfaces:
			for p: Vector3 in surface["v"]:
				center += p
				count += 1
		if count > 0:
			center /= float(count)
	var score := 0.0
	for surface: Dictionary in surfaces:
		var verts: PackedVector3Array = surface["v"]
		var normals: PackedVector3Array = surface["n"]
		for i in range(0, verts.size() - 2, 3):
			var a := verts[i]
			var b := verts[i + 1]
			var c := verts[i + 2]
			var face := (a - c).cross(a - b)
			if has_normals:
				score += face.dot(normals[i] + normals[i + 1] + normals[i + 2])
			else:
				score += face.dot((a + b + c) / 3.0 - center)
	return score < 0.0


static func is_ground_widget(surfaces: Array) -> bool:
	var flat := 0.0
	var total := 0.0
	for surface: Dictionary in surfaces:
		var verts: PackedVector3Array = surface["v"]
		for i in range(0, verts.size() - 2, 3):
			var face := (verts[i] - verts[i + 2]).cross(verts[i] - verts[i + 1])
			var area := face.length()
			total += area
			if area > 0.0 and absf(face.y) / area > 0.5:
				flat += area
	return total > 0.0 and flat / total >= GROUND_WIDGET_RATIO


## Original triangles followed by the same triangles with the opposite winding.
static func _both_sides(verts: PackedVector3Array, uvs: PackedVector2Array) -> Array:
	var back_verts := verts.duplicate()
	var back_uvs := uvs.duplicate()
	for i in range(0, back_verts.size(), 3):
		_swap(back_verts, i + 1, i + 2)
		_swap_uv(back_uvs, i + 1, i + 2)
	return [verts + back_verts, uvs + back_uvs]


## Smooth normals over the output of _both_sides; the front half and the back
## half never share a normal.
static func _side_normals(verts: PackedVector3Array) -> PackedVector3Array:
	var half := verts.size() / 2
	var faces := PackedVector3Array()
	for i in range(0, verts.size() - 2, 3):
		faces.append((verts[i] - verts[i + 2]).cross(verts[i] - verts[i + 1]))
	var sums := {}
	for i in verts.size():
		var key := _side_key(verts[i], i < half)
		sums[key] = sums.get(key, Vector3.ZERO) + faces[i / 3]
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in verts.size():
		var sum: Vector3 = sums[_side_key(verts[i], i < half)]
		normals[i] = sum.normalized() if sum.length_squared() > 0.0 else Vector3.UP
	return normals


static func _side_key(point: Vector3, front: bool) -> String:
	return "%s|%s" % [point.snapped(Vector3.ONE * 0.0001), front]


static func _filled(count: int, value: Vector3) -> PackedVector3Array:
	var values := PackedVector3Array()
	values.resize(count)
	values.fill(value)
	return values


static func _smooth(arrays: Array) -> Array:
	var tool := SurfaceTool.new()
	tool.create_from_arrays(arrays)
	tool.generate_normals()
	return tool.commit_to_arrays()


static func _swap(values: PackedVector3Array, i: int, j: int) -> void:
	var keep := values[i]
	values[i] = values[j]
	values[j] = keep


static func _swap_uv(values: PackedVector2Array, i: int, j: int) -> void:
	var keep := values[i]
	values[i] = values[j]
	values[j] = keep
