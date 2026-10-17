@tool
extends MeshInstance3D

@export var cache_path: String = "res://cache/high_noon_terrain.bin"
## Folder with atlas.png (16x16 MAPT grid) and edge.png: a god's themes/ folder. The light map is the map's own.
@export_dir var tileset_dir: String = OriginalAssets.THEMES_DIR + "james"
## The map sits around x/z 930-1620, far from where the editor camera opens. In the editor only,
## the parent is shifted so the map shows at the origin. Children keep their real coordinates,
## and the shift is taken off while the scene is saved.
@export var editor_preview_recenter := true:
	set(value):
		editor_preview_recenter = value
		_apply_preview_offset()

## Ground normals averaged per grid vertex, weighted by triangle area, like sacmap.d generateNormals,
## so the slopes read as one surface. Off: one flat normal per triangle, as the cache stores them.
## The cliff walls keep their flat normal either way.
@export var smooth_ground := true:
	set(value):
		smooth_ground = value
		_refresh_normals()

@export_group("Light map")
## Light left on the ground where the map's baked light is black (pits, map border).
@export_range(0.0, 2.0, 0.01) var light_base := 0.3:
	set(value):
		light_base = value
		_apply_light_levels()
## How much the baked light adds on top of light_base. Ground brightness = base + light * gain.
@export_range(0.0, 4.0, 0.01) var light_gain := 0.55:
	set(value):
		light_gain = value
		_apply_light_levels()

const MISSING_TEXT := "Falta el terreno de High Noon."
const CELL := 10.0
const GRID := 256

## Ground triangles only (walls left out), three vertices each.
var _ground := PackedVector3Array()
## Two ground triangle ids per 10 m cell, -1 when the cell has fewer (sacmap.d getTriangles).
var _cell_triangles := PackedInt32Array()
var _lowest_ground := 0.0
var _cell_counts := PackedByteArray()
## Kept so smooth_ground swaps normals without reading cache/ again.
var _mesh_arrays := []
var _flat_normals := PackedVector3Array()
var _smooth_normals := PackedVector3Array()
## The atlas x light map material, and the biome's PBR ground when a look layer gives one.
var _classic_material: ShaderMaterial
var _ground_override: Material


## The mesh and the ground material are rebuilt from cache/ on every load, also in the editor
## preview. Not stored: a saved scene must not carry the original map or its textures (RULES.md).
func _validate_property(property: Dictionary) -> void:
	if property.name == "mesh" or property.name == "material_override":
		property.usage &= ~PROPERTY_USAGE_STORAGE
		property.usage |= PROPERTY_USAGE_READ_ONLY


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_set_preview_offset(Vector3.ZERO)
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_apply_preview_offset()


func _ready() -> void:
	add_to_group("terrain")
	var built := _load_mesh()
	_apply_preview_offset()
	var missing := get_node_or_null("Missing")
	if missing:
		missing.visible = not built
	if not built:
		print(MISSING_TEXT)


func _apply_preview_offset() -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return
	var offset := Vector3.ZERO
	if editor_preview_recenter and mesh:
		var center := mesh.get_aabb().get_center()
		offset = Vector3(-center.x, 0.0, -center.z)
	_set_preview_offset(offset)


func _set_preview_offset(offset: Vector3) -> void:
	var world_root := get_parent() as Node3D
	if Engine.is_editor_hint() and world_root:
		world_root.position = offset


func _load_mesh() -> bool:
	if not FileAccess.file_exists(cache_path):
		return false
	var file := FileAccess.open(cache_path, FileAccess.READ)
	if file == null:
		return false
	if file.get_buffer(4) != "HNTR".to_utf8_buffer():
		return false
	var version := file.get_16()
	file.get_16()
	file.get_16()
	if version != 1:
		return false
	var vertex_count := file.get_32()
	var index_count := file.get_32()
	if vertex_count == 0 or index_count == 0:
		return false
	var vertices := PackedVector3Array()
	vertices.resize(vertex_count)
	var normals := PackedVector3Array()
	normals.resize(vertex_count)
	for i in vertex_count:
		vertices[i] = Vector3(file.get_float(), file.get_float(), file.get_float())
	for i in vertex_count:
		normals[i] = Vector3(file.get_float(), file.get_float(), file.get_float())
	var indices := PackedInt32Array()
	indices.resize(index_count)
	for i in index_count:
		indices[i] = file.get_32()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var colors := PackedColorArray()
	colors.resize(vertex_count)
	var tiles := _tile_ids()
	var triangle := 0
	var walls := 0
	while triangle < index_count:
		var a := indices[triangle]
		var b := indices[triangle + 1]
		var c := indices[triangle + 2]
		var cell_x := mini(mini(int(round(vertices[a].x / 10.0)), int(round(vertices[b].x / 10.0))), int(round(vertices[c].x / 10.0)))
		var cell_z := mini(mini(int(round(vertices[a].z / 10.0)), int(round(vertices[b].z / 10.0))), int(round(vertices[c].z / 10.0)))
		cell_x = clampi(cell_x, 0, 255)
		cell_z = clampi(cell_z, 0, 255)
		var tile := 0
		if not tiles.is_empty():
			tile = tiles[cell_z * 256 + cell_x]
		if absf(_flat_cross(vertices[a], vertices[b], Vector2(vertices[c].x, vertices[c].z))) < 0.01:
			_color_wall(colors, [a, b, c], tile, walls % 2 == 0)
			walls += 1
			triangle += 3
			continue
		for id in [a, b, c]:
			var local_x := clampf(vertices[id].x / 10.0 - float(cell_x), 0.02, 0.98)
			var local_z := clampf(vertices[id].z / 10.0 - float(cell_z), 0.02, 0.98)
			colors[id] = Color(float(tile) / 255.0, local_x, local_z)
		triangle += 3
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh_arrays = arrays
	_flat_normals = normals
	_smooth_normals = _smooth_ground_normals(vertices, indices, normals)
	_build_mesh()
	_index_ground(vertices, indices)
	_apply_ground_texture()
	_add_collision()
	return true


func _build_mesh() -> void:
	_mesh_arrays[Mesh.ARRAY_NORMAL] = _smooth_normals if smooth_ground else _flat_normals
	var built := ArrayMesh.new()
	built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _mesh_arrays)
	mesh = built


## smooth_ground changed: swap the normals and rebuild the mesh. Collision and the ground index
## are made from the positions, which do not change.
func _refresh_normals() -> void:
	if _mesh_arrays.is_empty():
		return
	_build_mesh()


## sacmap.d generateNormals: each ground position gets the sum of the unnormalized cross products of
## the triangles that touch it (so bigger faces weigh more), normalized. Walls (zero area seen from
## above) and every vertex a wall touches keep the cache normal, so the cliff edge stays sharp.
func _smooth_ground_normals(vertices: PackedVector3Array, indices: PackedInt32Array, flat: PackedVector3Array) -> PackedVector3Array:
	var sums := {}
	var wall_vertex := {}
	for t in range(0, indices.size(), 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		if absf(_flat_cross(vertices[a], vertices[b], Vector2(vertices[c].x, vertices[c].z))) < 0.01:
			wall_vertex[a] = true
			wall_vertex[b] = true
			wall_vertex[c] = true
			continue
		var cross := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		if cross.y < 0.0:
			cross = -cross
		for id in [a, b, c]:
			var key := _position_key(vertices[id])
			sums[key] = (sums[key] if sums.has(key) else Vector3.ZERO) + cross
	var result := flat.duplicate()
	for id in vertices.size():
		if wall_vertex.has(id):
			continue
		var key := _position_key(vertices[id])
		if sums.has(key) and (sums[key] as Vector3).length_squared() > 0.0:
			result[id] = (sums[key] as Vector3).normalized()
	return result


func _position_key(v: Vector3) -> Vector3i:
	return Vector3i(roundi(v.x * 100.0), roundi(v.y * 100.0), roundi(v.z * 100.0))


## sacmap.d appendEdgeWall texcoords: top_a (0,0), top_b (1,0), bot_b (1,1), bot_a (0,1).
## export_high_noon_terrain.py writes each wall as (top_a, bot_b, top_b), (bot_b, top_a, bot_a).
## Alpha 0 marks the wall for sacrifice_ground.gdshader: EDGE texture, or the cell's tile without one.
func _color_wall(colors: PackedColorArray, ids: Array, tile: int, first: bool) -> void:
	var uvs := [Vector2(0, 0), Vector2(1, 1), Vector2(1, 0)] if first else [Vector2(1, 1), Vector2(0, 0), Vector2(0, 1)]
	for k in 3:
		colors[ids[k]] = Color(float(tile) / 255.0, uvs[k].x, uvs[k].y, 0.0)


func has_ground_data() -> bool:
	return not _ground.is_empty()


## sacmap.d isOnGround: true when a land triangle lies under (x, z). Holes and the map rim have none.
func is_on_ground(x: float, z: float) -> bool:
	return _triangle_at(x, z) >= 0


## Land height under (x, z) in world units, NAN over a hole (sacmap.d getGroundHeight).
func ground_height(x: float, z: float) -> float:
	var id := _triangle_at(x, z)
	if id < 0:
		return NAN
	var plane := Plane(_ground[id * 3], _ground[id * 3 + 1], _ground[id * 3 + 2])
	return (plane.d - plane.normal.x * x - plane.normal.z * z) / plane.normal.y


func lowest_ground() -> float:
	return _lowest_ground


## How many land triangles each 10 m cell has: 0 a hole or the rim, 1 half a cell, 2 a full one. 256x256,
## row-major (z * 256 + x), read from the same index as is_on_ground. NavGrid builds its free nodes from it.
func ground_cell_counts() -> PackedByteArray:
	if _cell_counts.size() != GRID * GRID:
		_cell_counts = PackedByteArray()
		_cell_counts.resize(GRID * GRID)
		for cell in GRID * GRID:
			var count := 0
			if _cell_triangles.size() == GRID * GRID * 2:
				count = int(_cell_triangles[cell * 2] >= 0) + int(_cell_triangles[cell * 2 + 1] >= 0)
			_cell_counts[cell] = count
	return _cell_counts


func _index_ground(vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	_ground = PackedVector3Array()
	_cell_triangles = PackedInt32Array()
	_cell_triangles.resize(GRID * GRID * 2)
	_cell_triangles.fill(-1)
	_cell_counts = PackedByteArray()
	_lowest_ground = INF
	var triangle := 0
	while triangle < indices.size():
		var a := vertices[indices[triangle]]
		var b := vertices[indices[triangle + 1]]
		var c := vertices[indices[triangle + 2]]
		triangle += 3
		if absf(_flat_cross(a, b, Vector2(c.x, c.z))) < 0.01:
			continue
		var cell_x := clampi(int(round(minf(minf(a.x, b.x), c.x) / CELL)), 0, GRID - 1)
		var cell_z := clampi(int(round(minf(minf(a.z, b.z), c.z) / CELL)), 0, GRID - 1)
		var slot := (cell_z * GRID + cell_x) * 2
		if _cell_triangles[slot] >= 0:
			slot += 1
		if _cell_triangles[slot] >= 0:
			continue
		_cell_triangles[slot] = _ground.size() / 3
		_ground.append_array([a, b, c])
		_lowest_ground = minf(_lowest_ground, minf(minf(a.y, b.y), c.y))
	if _ground.is_empty():
		_lowest_ground = 0.0


func _triangle_at(x: float, z: float) -> int:
	if _ground.is_empty():
		return -1
	var cell_x := int(floor(x / CELL))
	var cell_z := int(floor(z / CELL))
	if cell_x < 0 or cell_z < 0 or cell_x >= GRID or cell_z >= GRID:
		return -1
	var at := Vector2(x, z)
	for k in 2:
		var id := _cell_triangles[(cell_z * GRID + cell_x) * 2 + k]
		if id < 0:
			continue
		if _inside(id, at):
			return id
	return -1


## Edges count as inside, like sacmap.d isInside (cross >= 0), with either winding.
func _inside(id: int, at: Vector2) -> bool:
	var a := _ground[id * 3]
	var b := _ground[id * 3 + 1]
	var c := _ground[id * 3 + 2]
	var s0 := _flat_cross(a, b, at)
	var s1 := _flat_cross(b, c, at)
	var s2 := _flat_cross(c, a, at)
	var tol := 0.0001
	return (s0 >= -tol and s1 >= -tol and s2 >= -tol) or (s0 <= tol and s1 <= tol and s2 <= tol)


func _flat_cross(a: Vector3, b: Vector3, at: Vector2) -> float:
	return (b.x - a.x) * (at.y - a.z) - (b.z - a.z) * (at.x - a.x)


## The original tile id of each 10 m cell, 256x256 row-major (empty without the cache).
func tile_ids() -> PackedByteArray:
	return _tile_ids()


## The classic atlas x light map material (null until the cache is loaded), also while a look layer
## shows its own ground: the classic grass paints it and bakes its colors from it.
func classic_material() -> ShaderMaterial:
	return _classic_material


## A look layer's ground material replaces the classic one until `clear_ground_override`.
## The mesh, heights and collision do not change.
func set_ground_override(material: Material) -> void:
	_ground_override = material
	material_override = _ground_override if _ground_override else _classic_material


func clear_ground_override() -> void:
	set_ground_override(null)


func _tile_ids() -> PackedByteArray:
	var path := "res://cache/look/tiles.png"
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return PackedByteArray()
	var ids := PackedByteArray()
	ids.resize(256 * 256)
	for y in 256:
		for x in 256:
			ids[y * 256 + x] = int(image.get_pixel(x, y).r8)
	return ids


func _load_png(path: String) -> ImageTexture:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	return ImageTexture.create_from_image(image)


## atlas.png and edge.png of a god: imported as Image (exact pixels, no mipmaps, no compression).
func _load_image_texture(path: String) -> ImageTexture:
	if not ResourceLoader.exists(path):
		return null
	var image := load(path) as Image
	return ImageTexture.create_from_image(image) if image else null


func set_tileset_dir(dir: String) -> void:
	tileset_dir = dir
	if mesh:
		_apply_ground_texture()


func _apply_ground_texture() -> void:
	var atlas := _load_image_texture(tileset_dir.path_join("atlas.png"))
	var light := _load_png("res://cache/look/light.png")
	if atlas == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scenes/world/sacrifice_ground.gdshader")
	mat.set_shader_parameter("atlas", atlas)
	var edge := _load_image_texture(tileset_dir.path_join("edge.png"))
	if edge:
		mat.set_shader_parameter("edge", edge)
		mat.set_shader_parameter("has_edge", true)
	if light:
		mat.set_shader_parameter("lightmap", light)
	_classic_material = mat
	material_override = _ground_override if _ground_override else _classic_material
	_apply_light_levels()


## The material is rebuilt from cache/ and is not editable, so the two levels live on the node.
func _apply_light_levels() -> void:
	var mat := _classic_material
	if mat == null:
		return
	mat.set_shader_parameter("light_base", light_base)
	mat.set_shader_parameter("light_gain", light_gain)


func _add_collision() -> void:
	if Engine.is_editor_hint():
		return
	var existing := get_node_or_null("Collision")
	if existing:
		existing.free()
	var body := StaticBody3D.new()
	body.name = "Collision"
	var shape_node := CollisionShape3D.new()
	shape_node.shape = mesh.create_trimesh_shape()
	body.add_child(shape_node)
	add_child(body)
