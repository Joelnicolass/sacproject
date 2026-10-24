class_name WallLook
extends MeshInstance3D

## The body of a Firewall or a Wailing Wall: the unit strip (wall_strip.obj) drawn with the wall shader, which stretches it from the wall's
## ends, thickness and height. Every frame it hands the shader where the ends are and how tall the wall stands now; once it lays down the
## land height along the wall (129 samples) so the strip follows the ground. The material is the scene's own, copied per wall, so two walls
## do not share their ends. Presentation only, on every peer; it does not hurt anybody (WallTouch).
## Ref: sacengine makeWallMesh, Firewall.scale / height (renderer.d:2639-2671; state.d:3690-3697).

@export var wall: SpellWall
## Samples of the land (the strip has one section more than this minus one).
@export_range(2, 512) var samples := 129


func _ready() -> void:
	if wall == null or DisplayServer.get_name() == "headless":
		set_process(false)
		return
	var shader := (material_override as ShaderMaterial).duplicate() as ShaderMaterial
	material_override = shader
	var reach := 2.0 * wall.reach_m()
	shader.set_shader_parameter(&"reach", reach)
	shader.set_shader_parameter(&"thickness", wall.thickness_m())
	shader.set_shader_parameter(&"ground", _land_along(reach))
	custom_aabb = AABB(Vector3(-0.5 * reach, -10.0, -wall.thickness_m()), Vector3(reach, 40.0, 2.0 * wall.thickness_m()))


func _process(_delta: float) -> void:
	var shader := material_override as ShaderMaterial
	shader.set_shader_parameter(&"left", wall.left)
	shader.set_shader_parameter(&"right", wall.right)
	shader.set_shader_parameter(&"top", wall.top())


## The height of the land under each sample of the strip, over the wall's own height, as a texture of one row.
func _land_along(reach: float) -> ImageTexture:
	var image := Image.create(samples, 1, false, Image.FORMAT_RF)
	for i in samples:
		var t := (float(i) / float(samples - 1) - 0.5) * reach
		var at := wall.center + Vector3(wall.direction.x, 0.0, wall.direction.y) * t
		image.set_pixel(i, 0, Color(wall.ground_y(at.x, at.z) - wall.center.y, 0.0, 0.0))
	return ImageTexture.create_from_image(image)
