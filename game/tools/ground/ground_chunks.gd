@tool
extends RefCounted

## Step 3 of the ground import: cuts the soup in square chunks of the map and makes the two things a chunk becomes: its rows in
## the MeshGroundData (welded vertices and indices, sorted by chunk, plus the bucket cache) and the mesh that draws it. Chunks
## and the triangles in them are always in the same order, so a re-import without edits writes the same bytes. Static helpers.

const RULES := preload("res://scenes/map/terrain/mesh/mesh_ground_rules.gd")
const DATA := preload("res://scenes/map/terrain/mesh/mesh_ground_data.gd")
## Two corners closer than this (in each axis, metres) are one vertex of the ground data.
const WELD_M := 0.0001
## The same for the drawn mesh: position (metres), normal and uv, so a smooth slope shares its vertices and a crease does not.
const DRAW_WELD_M := 0.001
const NORMAL_STEPS := 127.0


## The chunks that hold triangles: [{"key": Vector2i (chunk x, z), "tris": Array of triangle ids}], by z then x.
static func group(soup: Dictionary, chunk_m: float) -> Array:
	var pos: PackedVector3Array = soup["pos"]
	var by_key := {}
	for t in (soup["mat"] as PackedInt32Array).size():
		var centroid := (pos[t * 3] + pos[t * 3 + 1] + pos[t * 3 + 2]) / 3.0
		var key := Vector2i(floori(centroid.x / chunk_m), floori(centroid.z / chunk_m))
		if not by_key.has(key):
			by_key[key] = []
		(by_key[key] as Array).append(t)
	var keys := by_key.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var groups: Array = []
	for key: Vector2i in keys:
		groups.append({"key": key, "tris": by_key[key]})
	return groups


## A MeshGroundData (as an Object: this script runs before the class cache may exist) made from the groups.
static func build_data(soup: Dictionary, groups: Array, bounds: Rect2, options: Dictionary) -> Object:
	var pos: PackedVector3Array = soup["pos"]
	var vertex_of := {}
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var rows := PackedInt32Array()
	for group_info: Dictionary in groups:
		var first := indices.size() / 3
		for t: int in group_info["tris"]:
			var ids: Array[int] = []
			for corner in 3:
				var point := pos[t * 3 + corner]
				var key := Vector3i(roundi(point.x / WELD_M), roundi(point.y / WELD_M), roundi(point.z / WELD_M))
				if not vertex_of.has(key):
					vertex_of[key] = vertices.size()
					vertices.append(point)
				ids.append(vertex_of[key])
			if ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2]:
				indices.append_array(PackedInt32Array(ids))
		var key_chunk: Vector2i = group_info["key"]
		rows.append_array(PackedInt32Array([key_chunk.x, key_chunk.y, first, indices.size() / 3 - first]))
	var buckets: Dictionary = RULES.build_buckets(vertices, indices, bounds, float(options["bucket_m"]), float(options["walkable_deg"]))
	var data: Object = DATA.new()
	data.set("vertices", vertices)
	data.set("indices", indices)
	data.set("bounds", bounds)
	data.set("chunk_m", float(options["chunk_m"]))
	data.set("bucket_m", float(options["bucket_m"]))
	data.set("deform_cell_m", float(options["deform_cell_m"]))
	data.set("walkable_deg", float(options["walkable_deg"]))
	data.set("chunks", rows)
	data.set("bucket_dims", buckets["dims"])
	data.set("bucket_start", buckets["start"])
	data.set("bucket_tris", buckets["tris"])
	data.set("lowest_m", float(buckets["lowest"]))
	return data


## One mesh per group, in the same order: [{"name": "Chunk_x_z", "mesh": ArrayMesh}]. One surface per material in the chunk.
static func build_meshes(soup: Dictionary, groups: Array, make_lods: bool) -> Array:
	var materials: Array = soup["materials"]
	var mat: PackedInt32Array = soup["mat"]
	var made: Array = []
	for group_info: Dictionary in groups:
		var by_material := {}
		for t: int in group_info["tris"]:
			if not by_material.has(mat[t]):
				by_material[mat[t]] = []
			(by_material[mat[t]] as Array).append(t)
		var importer_mesh := ImporterMesh.new()
		var material_ids := by_material.keys()
		material_ids.sort()
		for material_id: int in material_ids:
			var no_shapes: Array[Array] = []
			importer_mesh.add_surface(Mesh.PRIMITIVE_TRIANGLES, _draw_arrays(soup, by_material[material_id]), no_shapes, {}, materials[material_id] as Material)
		if make_lods:
			importer_mesh.call("generate_lods", 25.0, 60.0, [])  # NOT VERIFIED in 4.7.2: a wrong signature only logs an error
		var key: Vector2i = group_info["key"]
		made.append({"name": "Chunk_%d_%d" % [key.x, key.y], "mesh": importer_mesh.get_mesh()})
	return made


## The surface arrays of some triangles, vertices shared where position, normal and uv agree.
static func _draw_arrays(soup: Dictionary, tris: Array) -> Array:
	var pos: PackedVector3Array = soup["pos"]
	var nrm: PackedVector3Array = soup["nrm"]
	var uv: PackedVector2Array = soup["uv"]
	var slot_of := {}
	var out_pos := PackedVector3Array()
	var out_nrm := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var out_index := PackedInt32Array()
	for t: int in tris:
		for corner in 3:
			var c := t * 3 + corner
			var key := "%d,%d,%d|%d,%d,%d|%d,%d" % [roundi(pos[c].x / DRAW_WELD_M), roundi(pos[c].y / DRAW_WELD_M), roundi(pos[c].z / DRAW_WELD_M),
					roundi(nrm[c].x * NORMAL_STEPS), roundi(nrm[c].y * NORMAL_STEPS), roundi(nrm[c].z * NORMAL_STEPS),
					roundi(uv[c].x / DRAW_WELD_M), roundi(uv[c].y / DRAW_WELD_M)]
			if not slot_of.has(key):
				slot_of[key] = out_pos.size()
				out_pos.append(pos[c])
				out_nrm.append(nrm[c])
				out_uv.append(uv[c])
			out_index.append(slot_of[key])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_pos
	arrays[Mesh.ARRAY_NORMAL] = out_nrm
	arrays[Mesh.ARRAY_TEX_UV] = out_uv
	arrays[Mesh.ARRAY_INDEX] = out_index
	return arrays
