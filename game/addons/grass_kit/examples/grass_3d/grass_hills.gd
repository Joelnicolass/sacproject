@tool
extends StaticBody3D

## The example's ground: rolling hills and one steep mound, a mesh and a height map collider built
## from the same heights. `dig()` lowers a crater in both, the way a game's terrain changes in
## play. This is the example's own terrain, not part of the kit: a game's ground is whatever it
## already has with collision.

## Side of the square of hills (m), centred on the origin.
@export var size := 160.0
@export var ground_color := Color(0.26, 0.3, 0.13)

var _heights := PackedFloat32Array()
var _side := 0
var _mesh: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	_side = int(size) + 1
	_heights.resize(_side * _side)
	for z in _side:
		for x in _side:
			_heights[z * _side + x] = _height_of(x - size * 0.5, z - size * 0.5)
	_mesh = MeshInstance3D.new()
	add_child(_mesh, false, Node.INTERNAL_MODE_BACK)
	_shape = CollisionShape3D.new()
	add_child(_shape, false, Node.INTERNAL_MODE_BACK)
	_rebuild()


## The ground's height at (x, z), between the grid points.
func height_at(x: float, z: float) -> float:
	var gx := clampf(x + size * 0.5, 0.0, size - 0.001)
	var gz := clampf(z + size * 0.5, 0.0, size - 0.001)
	var x0 := int(gx)
	var z0 := int(gz)
	var tx := gx - x0
	var tz := gz - z0
	var h00 := _heights[z0 * _side + x0]
	var h10 := _heights[z0 * _side + x0 + 1]
	var h01 := _heights[(z0 + 1) * _side + x0]
	var h11 := _heights[(z0 + 1) * _side + x0 + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


## Lowers a bowl `depth` deep and `radius` wide around (x, z).
func dig(x: float, z: float, radius: float, depth: float) -> void:
	for gz in _side:
		for gx in _side:
			var d := Vector2(gx - size * 0.5 - x, gz - size * 0.5 - z).length()
			if d < radius:
				var bowl := cos(d / radius * PI * 0.5)
				_heights[gz * _side + gx] -= depth * bowl * bowl
	_rebuild()


func _height_of(x: float, z: float) -> float:
	var h := 3.0 * sin(x * 0.045) * cos(z * 0.038) + 1.2 * sin((x + z) * 0.11)
	# A steep mound: about 60°, too steep for grass on its sides.
	var mound := Vector2(x - 30.0, z + 25.0).length()
	h += 12.0 * maxf(0.0, 1.0 - mound / 7.0)
	return h


func _rebuild() -> void:
	var shape := HeightMapShape3D.new()
	shape.map_width = _side
	shape.map_depth = _side
	shape.map_data = _heights
	_shape.shape = shape
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size * 0.5
	for z in _side - 1:
		for x in _side - 1:
			var a := Vector3(x - half, _heights[z * _side + x], z - half)
			var b := Vector3(x + 1 - half, _heights[z * _side + x + 1], z - half)
			var c := Vector3(x - half, _heights[(z + 1) * _side + x], z + 1 - half)
			var d := Vector3(x + 1 - half, _heights[(z + 1) * _side + x + 1], z + 1 - half)
			for p in [a, b, c, b, d, c]:
				tool.add_vertex(p)
	tool.generate_normals()
	var material := ShaderMaterial.new()
	material.shader = preload("grass_hills.gdshader")
	material.set_shader_parameter(&"ground_color", ground_color)
	tool.set_material(material)
	_mesh.mesh = tool.commit()
