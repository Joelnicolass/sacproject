@tool
extends RefCounted

## Step 1 of the ground import: every mesh of the imported glb as one list of triangle corners in map space ("soup": three
## corners per triangle, each with its normal and uv, plus the material index of the triangle). It also moves the whole
## ground so it starts at x = 0, z = 0 (the map lives at x, z >= 0). Static helpers; the steps are driven by tools/ground_import.gd.
## The soup is a Dictionary of parallel arrays: "pos" (Vector3), "nrm" (Vector3), "uv" (Vector2), "mat" (int, one per
## triangle) and "materials" (Array of Material, the index "mat" points to).


## A soup with nothing in it yet.
static func empty() -> Dictionary:
	return {"pos": PackedVector3Array(), "nrm": PackedVector3Array(), "uv": PackedVector2Array(), "mat": PackedInt32Array(), "materials": []}


## The triangles of every mesh under `root` (transforms applied, Godot winding kept), as a soup.
static func read(root: Node) -> Dictionary:
	var soup := empty()
	_collect(root, Transform3D.IDENTITY, soup)
	return soup


## Moves the soup so its footprint starts at the origin; returns that footprint (x, z in metres). Height is untouched.
static func move_to_origin(soup: Dictionary) -> Rect2:
	var pos: PackedVector3Array = soup["pos"]
	if pos.is_empty():
		return Rect2()
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point in pos:
		low = Vector2(minf(low.x, point.x), minf(low.y, point.z))
		high = Vector2(maxf(high.x, point.x), maxf(high.y, point.z))
	var shift := Vector3(-low.x, 0.0, -low.y)
	for i in pos.size():
		pos[i] += shift
	soup["pos"] = pos
	return Rect2(Vector2.ZERO, high - low)


static func _collect(node: Node, parent: Transform3D, soup: Dictionary) -> void:
	var xf := parent * (node as Node3D).transform if node is Node3D else parent
	var meshes: Array = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh := (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			meshes.append([mesh.surface_get_arrays(surface), mesh.surface_get_material(surface)])
	elif node is ImporterMeshInstance3D and (node as ImporterMeshInstance3D).mesh != null:
		var importer_mesh := (node as ImporterMeshInstance3D).mesh
		for surface in importer_mesh.get_surface_count():
			meshes.append([importer_mesh.get_surface_arrays(surface), importer_mesh.get_surface_material(surface)])
	for entry: Array in meshes:
		_add_surface(entry[0] as Array, entry[1] as Material, xf, soup)
	for child in node.get_children():
		_collect(child, xf, soup)


static func _add_surface(arrays: Array, material: Material, xf: Transform3D, soup: Dictionary) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	else:
		indices.resize(vertices.size())
		for i in indices.size():
			indices[i] = i
	var materials: Array = soup["materials"]
	if not materials.has(material):
		materials.append(material)
	var material_id := materials.find(material)
	var normal_basis := xf.basis.inverse().transposed()
	var mirrored := xf.basis.determinant() < 0.0
	var pos: PackedVector3Array = soup["pos"]
	var nrm: PackedVector3Array = soup["nrm"]
	var uv: PackedVector2Array = soup["uv"]
	var mat: PackedInt32Array = soup["mat"]
	for first in range(0, indices.size() - 2, 3):
		var order := [0, 2, 1] if mirrored else [0, 1, 2]
		var corners: Array[Vector3] = []
		for k: int in order:
			corners.append(xf * vertices[indices[first + k]])
		var flat := (corners[2] - corners[0]).cross(corners[1] - corners[0]).normalized()
		for k: int in order:
			var id := indices[first + k]
			pos.append(xf * vertices[id])
			nrm.append((normal_basis * normals[id]).normalized() if id < normals.size() else flat)
			uv.append(uvs[id] if id < uvs.size() else Vector2.ZERO)
		mat.append(material_id)
	soup["pos"] = pos
	soup["nrm"] = nrm
	soup["uv"] = uv
	soup["mat"] = mat
