class_name GrassLabGround
extends MeshInstance3D

## Lab ground (debug only): a flat-ish square patch cut from the derived height map (so the grass
## has the same heights as in the map), at map coordinates, with the ground look given by the
## rig's `TerrainLayer` like the real terrain. It offers the small part of `terrain.gd` that the
## look layers and the lab use: `tile_ids`, `has_ground_data`, `ground_height`, `set_ground_override`.

@export var center := Vector2(1500.0, 1500.0)
@export var half_size_m := 65.0
@export var step_m := 2.5
## The map's zone ids -> ground layers; every cell gets a tile that paints the first layer.
@export var tiles: TileLayerMap

var _height: Image
var _material_classic := StandardMaterial3D.new()


func _ready() -> void:
	add_to_group("terrain")
	_material_classic.albedo_color = Color(0.25, 0.35, 0.12)
	_height = _derive_height()
	if _height == null:
		push_error("Falta el terreno de High Noon (assets/original/maps/high_noon/terrain.res).")
		return
	mesh = _build()
	material_override = _material_classic


## The grass height as the game derives it: from a throw-away Terrain built from the map's data.
func _derive_height() -> Image:
	var data := load(MapCatalog.active().terrain_path) as MapTerrainData
	if data == null:
		return null
	var helper := MeshInstance3D.new()
	helper.set_script(load("res://scenes/map/terrain/terrain.gd"))
	helper.set("data", data)
	add_child(helper)
	helper.remove_from_group("terrain")
	var image := GrassHeight.from_terrain(helper)
	helper.free()
	return image


func has_ground_data() -> bool:
	return _height != null


func ground_height(x: float, z: float) -> float:
	if _height == null or _height.is_empty():
		return 0.0
	var tx := clampi(int(x / 2.5), 0, 1023)
	var tz := clampi(int(z / 2.5), 0, 1023)
	return _height.get_pixel(tx, tz).r


func tile_ids() -> PackedByteArray:
	var ids := PackedByteArray()
	ids.resize(256 * 256)
	var pick := 0
	if tiles:
		for id in tiles.slots.size():
			if tiles.slot_of(id) == 0:
				pick = id
				break
	ids.fill(pick)
	return ids


func set_ground_override(material: Material) -> void:
	material_override = material if material else _material_classic


func clear_ground_override() -> void:
	set_ground_override(null)


func _build() -> ArrayMesh:
	var count := int(2.0 * half_size_m / step_m)
	var origin := center - Vector2.ONE * half_size_m
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for z in count + 1:
		for x in count + 1:
			var px := origin.x + x * step_m
			var pz := origin.y + z * step_m
			vertices.append(Vector3(px, ground_height(px, pz), pz))
			colors.append(Color(0.0, 0.0, 0.0, 1.0))
	var indices := PackedInt32Array()
	var row := count + 1
	for z in count:
		for x in count:
			var a := z * row + x
			indices.append_array([a, a + 1, a + row, a + 1, a + row + 1, a + row])
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	for z in count + 1:
		for x in count + 1:
			var left := vertices[z * row + maxi(x - 1, 0)].y
			var right := vertices[z * row + mini(x + 1, count)].y
			var back := vertices[maxi(z - 1, 0) * row + x].y
			var front := vertices[mini(z + 1, count) * row + x].y
			normals[z * row + x] = Vector3(left - right, 2.0 * step_m, back - front).normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var patch := ArrayMesh.new()
	patch.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return patch
