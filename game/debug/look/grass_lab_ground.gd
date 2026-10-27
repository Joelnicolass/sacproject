class_name GrassLabGround
extends TerrainMesh

## Lab ground (debug only): a flat-ish square patch cut from the real map's heights (so the grass has the same
## heights as in the map), at map coordinates, with the ground look given by the rig's `TerrainLayer` like the real
## terrain (it is a TerrainMesh: `set_ground` / `clear_ground`). Its `shape` holds the heights and ground roles (all open).

@export var center := Vector2(1500.0, 1500.0)
@export var half_size_m := 65.0
@export var step_m := 2.5
## The ground numbers of High Noon (a Terrain child of this node).
@export var shape: Terrain

var _material_plain := StandardMaterial3D.new()


## Replaces TerrainMesh's: the patch is built here, not from the whole map.
func _ready() -> void:
	_material_plain.albedo_color = Color(0.25, 0.35, 0.12)
	if shape == null or not shape.is_loaded():
		push_error("Falta el terreno de High Noon (scenes/map/maps/high_noon/heights.png).")
		return
	mesh = _patch_mesh()
	material_override = _material_plain


func _height(x: float, z: float) -> float:
	var found := shape.height_at(x, z)
	return 0.0 if is_nan(found) else found


func _patch_mesh() -> ArrayMesh:
	var count := int(2.0 * half_size_m / step_m)
	var origin := center - Vector2.ONE * half_size_m
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for z in count + 1:
		for x in count + 1:
			var px := origin.x + x * step_m
			var pz := origin.y + z * step_m
			vertices.append(Vector3(px, _height(px, pz), pz))
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
