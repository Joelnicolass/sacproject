@tool
extends RefCounted

## The outline of the brush on the relief under the mouse, drawn straight through RenderingServer (no node in the scene,
## nothing saved): the brush's shape at its reach and, fainter, where its hard core ends, each point lifted LIFT_M above
## the lattice so the line reads over the ground. Not: where the mouse points (GroundPick), the brush's numbers.

const GroundPick := preload("res://addons/terrain_tools/brush/ground_pick.gd")
const LIFT_M := 1.5
## Metres between two points of the outline.
const SPACING_M := 4.0
const REACH_COLOR := Color(0.35, 0.75, 1.0)
const CORE_COLOR := Color(0.35, 0.75, 1.0, 0.45)

var _mesh := RenderingServer.mesh_create()
var _instance := RenderingServer.instance_create()
var _material := StandardMaterial3D.new()


func _init() -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = true
	RenderingServer.instance_set_base(_instance, _mesh)
	RenderingServer.instance_geometry_set_cast_shadows_setting(_instance, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	RenderingServer.instance_set_visible(_instance, false)


## Draws the outline of `brush` around `center` (x, z in the Terrain's frame) over `heights` (TerrainGrid.COUNT values),
## in the world `scenario`, placed by the Terrain's `frame`.
func draw(scenario: RID, frame: Transform3D, center: Vector2, brush: TerrainBrush, heights: PackedFloat32Array) -> void:
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	_outline(points, colors, _corners(brush.shape, brush.size_m), center, heights, REACH_COLOR)
	if brush.falloff > 0.0 and brush.falloff < 1.0:
		_outline(points, colors, _corners(brush.shape, brush.size_m * (1.0 - brush.falloff)), center, heights, CORE_COLOR)
	RenderingServer.mesh_clear(_mesh)
	if points.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = colors
	RenderingServer.mesh_add_surface_from_arrays(_mesh, RenderingServer.PRIMITIVE_LINES, arrays)
	RenderingServer.mesh_surface_set_material(_mesh, 0, _material.get_rid())
	RenderingServer.instance_set_scenario(_instance, scenario)
	RenderingServer.instance_set_transform(_instance, frame)
	RenderingServer.instance_set_visible(_instance, true)


func hide() -> void:
	RenderingServer.instance_set_visible(_instance, false)


## Frees what RenderingServer holds (the plugin calls it when it leaves the editor).
func release() -> void:
	RenderingServer.free_rid(_instance)
	RenderingServer.free_rid(_mesh)


## The corners of the shape's outline at `reach_m`, around the origin (the shapes of BrushRules).
static func _corners(shape: TerrainBrush.Shape, reach_m: float) -> PackedVector2Array:
	var corners := PackedVector2Array()
	match shape:
		TerrainBrush.Shape.SQUARE:
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				corners.append(corner * reach_m)
		TerrainBrush.Shape.CROSS:
			var arm := BrushRules.CROSS_ARM
			for corner: Vector2 in [Vector2(arm, -1), Vector2(arm, -arm), Vector2(1, -arm), Vector2(1, arm), Vector2(arm, arm),
					Vector2(arm, 1), Vector2(-arm, 1), Vector2(-arm, arm), Vector2(-1, arm), Vector2(-1, -arm), Vector2(-arm, -arm),
					Vector2(-arm, -1)]:
				corners.append(corner * reach_m)
		_:
			var count := maxi(16, ceili(TAU * reach_m / SPACING_M))
			for k in count:
				corners.append(Vector2.from_angle(TAU * k / count) * reach_m)
	return corners


## Appends the closed outline through `corners` (each edge cut every SPACING_M) as line pairs on the relief.
static func _outline(points: PackedVector3Array, colors: PackedColorArray, corners: PackedVector2Array, center: Vector2,
		heights: PackedFloat32Array, color: Color) -> void:
	var trail := PackedVector3Array()
	for k in corners.size():
		var from := center + corners[k]
		var to := center + corners[(k + 1) % corners.size()]
		var steps := maxi(1, ceili(from.distance_to(to) / SPACING_M))
		for step in steps:
			var at := from.lerp(to, float(step) / steps)
			var ground := GroundPick.height_at(heights, at.x, at.y)
			trail.append(Vector3(at.x, (ground if not is_nan(ground) else 0.0) + LIFT_M, at.y))
	for k in trail.size():
		points.append(trail[k])
		points.append(trail[(k + 1) % trail.size()])
		colors.append(color)
		colors.append(color)
