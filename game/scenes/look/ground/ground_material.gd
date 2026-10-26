class_name GroundMaterial
extends RefCounted

## Turns a god's `GodGround`, a map's ground roles and its baked light into the uniforms of `ground.gdshader`, so the terrain
## knows nothing of roles. Everything built here is runtime-only (texture arrays, noise): none of it is stored in a scene.
## What it does NOT do: choose which ground a map wears (TerrainLayer does) or pack the textures (GroundTextures does).

const SHADER := preload("res://scenes/look/ground/ground.gdshader")


## `roles`: the map's ground_roles.png (TerrainMesh.ground_roles); `light`: its baked light (TerrainMesh.light_map). Either may be null.
static func build(ground: GodGround, roles: Texture2D, light: Texture2D, preset: LookQuality) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("ground_roles", roles)
	mat.set_shader_parameter("lightmap", light)
	mat.set_shader_parameter("ground_noise", GroundTextures.noise())
	update(mat, ground, preset)
	return mat


## Pushes the ground's tunables, its texture arrays and the preset's switches. The arrays are cached per GodGround.
static func update(mat: ShaderMaterial, ground: GodGround, preset: LookQuality) -> void:
	mat.set_shader_parameter("role_albedo", GroundTextures.array_of(ground, GroundTextures.Kind.ALBEDO))
	mat.set_shader_parameter("role_normal", GroundTextures.array_of(ground, GroundTextures.Kind.NORMAL))
	mat.set_shader_parameter("role_orm", GroundTextures.array_of(ground, GroundTextures.Kind.ORM))
	mat.set_shader_parameter("role_detail", GroundTextures.array_of(ground, GroundTextures.Kind.DETAIL))
	mat.set_shader_parameter("use_maps", preset == null or preset.ground_layers >= 4)
	mat.set_shader_parameter("use_triplanar", preset == null or preset.ground_triplanar)
	mat.set_shader_parameter("use_stochastic", preset != null and preset.ground_stochastic)
	mat.set_shader_parameter("use_macro", preset == null or preset.ground_macro)
	var layout := PackedVector4Array()
	var tint := PackedVector4Array()
	var relief := PackedVector4Array()
	var takes := Vector4(90, 90, 90, 90)
	var contrast := Vector4.ZERO
	var stochastic := Vector4.ZERO
	var roles := ground.roles()
	for i in roles.size():
		var role := roles[i]
		if role == null:
			layout.append(Vector4(10.0, 1.0, 0.0, 1.0))
			tint.append(Vector4(1, 1, 1, 1))
			relief.append(Vector4.ZERO)
			continue
		var grain := role.detail_strength if role.detail != null else 0.0
		layout.append(Vector4(role.tile_m, float(role.variants_per_side), grain, role.detail_repeat))
		tint.append(Vector4(role.tint.r, role.tint.g, role.tint.b, role.roughness))
		relief.append(Vector4(role.normal_strength, _flag(GroundTextures.has_map(role, GroundTextures.Kind.NORMAL)),
				_flag(GroundTextures.has_map(role, GroundTextures.Kind.ORM)), _flag(role.triplanar)))
		takes[i] = role.takes_slope_deg
		contrast[i] = role.height_contrast
		stochastic[i] = _flag(role.stochastic)
	mat.set_shader_parameter("role_layout", layout)
	mat.set_shader_parameter("role_tint", tint)
	mat.set_shader_parameter("role_relief", relief)
	mat.set_shader_parameter("role_takes_slope", takes)
	mat.set_shader_parameter("role_height_contrast", contrast)
	mat.set_shader_parameter("role_stochastic", stochastic)
	mat.set_shader_parameter("blend_depth", ground.blend_depth)
	mat.set_shader_parameter("edge_noise", ground.edge_noise)
	mat.set_shader_parameter("macro_strength", ground.macro_strength)
	mat.set_shader_parameter("light_base", ground.light_base)
	mat.set_shader_parameter("light_gain", ground.light_gain)
	mat.set_shader_parameter("edge", ground.edge)
	mat.set_shader_parameter("has_edge", ground.edge != null)


## Gives the ground the average colour of the grass where the grass grows (see `grass_paint.gdshaderinc`). amount 0 removes it.
## Works on any ground material that includes it.
static func set_grass_paint(mat: ShaderMaterial, color: Color, amount: float, layers: Vector4, reference: float, wave_dir: Vector2, wave_scale: float, wave_speed: float, wave_strength: float, slope_start := 10.0, slope_end := 36.0) -> void:
	mat.set_shader_parameter("grass_wave_noise", GroundTextures.noise())
	mat.set_shader_parameter("grass_paint_color", Vector3(color.r, color.g, color.b))
	mat.set_shader_parameter("grass_paint_amount", amount)
	mat.set_shader_parameter("grass_paint_layers", layers)
	mat.set_shader_parameter("grass_paint_ref", reference)
	mat.set_shader_parameter("grass_paint_slope", Vector2(slope_start, slope_end))
	mat.set_shader_parameter("grass_wave_dir", wave_dir)
	mat.set_shader_parameter("grass_wave_scale_m", wave_scale)
	mat.set_shader_parameter("grass_wave_speed", wave_speed)
	mat.set_shader_parameter("grass_wave_strength", wave_strength)


## The seamless noises shared by the ground and the grass (wind, patches).
static func shared_noise() -> ImageTexture:
	return GroundTextures.noise()


## RGBA8, one slot per channel: tile id -> slot via a TileLayerMap, for the grass of the classic ground.
## WORKAROUND: kept until the grass reads the map's ground_roles.png (plan 062, cut 3), then removed with TileLayerMap.
static func splat_texture(tiles: TileLayerMap, tile_ids: PackedByteArray) -> ImageTexture:
	var side := TerrainGrid.SIDE
	var data := PackedByteArray()
	data.resize(TerrainGrid.COUNT * 4)
	data.fill(0)
	if tiles != null and tile_ids.size() == TerrainGrid.COUNT:
		for cell in tile_ids.size():
			var slot := tiles.slot_of(tile_ids[cell])
			if slot < 4:
				data[cell * 4 + slot] = 255
	return ImageTexture.create_from_image(Image.create_from_data(side, side, false, Image.FORMAT_RGBA8, data))


static func _flag(on: bool) -> float:
	return 1.0 if on else 0.0
