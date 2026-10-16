class_name GroundMaterial
extends RefCounted

## Dumps a `GroundSet` into the uniforms of `ground_pbr.gdshader`, so `terrain.gd` knows nothing of
## layers. Everything built here is runtime-only (zone mask from the cache, noise): none of it is
## stored in a scene.

const SHADER := preload("res://scenes/world/look/ground/ground_pbr.gdshader")
const NOISE_SIZE := 256
const LIGHT_MAP := "res://cache/look/light.png"

static var _noise: ImageTexture
static var _bump: ImageTexture


## `tile_ids`: one original tile id per 10 m cell, 256x256 row-major (`terrain.tile_ids()`).
static func build(ground: GroundSet, tile_ids: PackedByteArray, preset: LookQuality) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var count := mini(ground.layers.size(), GroundSet.MAX_LAYERS)
	for i in count:
		var layer := ground.layers[i]
		if layer == null:
			continue
		mat.set_shader_parameter("albedo_%d" % i, layer.albedo)
		mat.set_shader_parameter("normal_%d" % i, layer.normal)
		mat.set_shader_parameter("orm_%d" % i, layer.orm)
	bind_common(mat, ground, tile_ids)
	mat.set_shader_parameter("bump_tex", _bump_texture())
	update(mat, ground, preset)
	return mat


## The textures `ground_common.gdshaderinc` reads (zone splat, noise, light map). Call `update` after it.
static func bind_common(mat: ShaderMaterial, ground: GroundSet, tile_ids: PackedByteArray) -> void:
	mat.set_shader_parameter("splat", splat_texture(ground.tiles, tile_ids))
	mat.set_shader_parameter("noise_tex", _noise_texture())
	var light := _load_image_texture(LIGHT_MAP) if ground.lightmap_tint > 0.0 else null
	if light:
		mat.set_shader_parameter("lightmap", light)


## Pushes every tunable (set values and the preset's switches). Cheap: no texture is rebuilt.
static func update(mat: ShaderMaterial, ground: GroundSet, preset: LookQuality) -> void:
	var count := mini(ground.layers.size(), GroundSet.MAX_LAYERS)
	var allowed := count if preset == null else mini(count, preset.ground_layers)
	mat.set_shader_parameter("layer_count", maxi(1, allowed))
	mat.set_shader_parameter("use_triplanar", preset == null or preset.ground_triplanar)
	mat.set_shader_parameter("use_stochastic", preset != null and preset.ground_stochastic)
	mat.set_shader_parameter("use_macro", preset == null or preset.ground_macro)
	var scale := PackedFloat32Array([2.0, 2.0, 2.0, 2.0])
	var tint := PackedVector4Array([Vector4(1, 1, 1, 1), Vector4(1, 1, 1, 1), Vector4(1, 1, 1, 1), Vector4(1, 1, 1, 1)])
	var strength := PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
	var contrast := PackedFloat32Array([0.6, 0.6, 0.6, 0.6])
	var slope := PackedVector4Array([Vector4(0, 90, 6, 0), Vector4(0, 90, 6, 0), Vector4(0, 90, 6, 0), Vector4(0, 90, 6, 0)])
	var alt := PackedVector4Array([Vector4(-200, 200, 8, 0), Vector4(-200, 200, 8, 0), Vector4(-200, 200, 8, 0), Vector4(-200, 200, 8, 0)])
	var flags := PackedVector4Array([Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0)])
	for i in count:
		var layer := ground.layers[i]
		if layer == null:
			continue
		scale[i] = layer.uv_scale_m
		var linear := layer.tint.srgb_to_linear()
		tint[i] = Vector4(linear.r, linear.g, linear.b, 1.0)
		strength[i] = layer.normal_strength
		contrast[i] = layer.height_contrast
		slope[i] = Vector4(layer.slope_min_deg, layer.slope_max_deg, layer.slope_soft_deg, layer.tile_weight)
		alt[i] = Vector4(layer.altitude_min_m, layer.altitude_max_m, layer.altitude_soft_m, layer.patchiness)
		flags[i] = Vector4(1.0 if layer.triplanar else 0.0, 1.0 if layer.stochastic else 0.0, layer.roughness_offset, layer.priority)
	mat.set_shader_parameter("uv_scale_m", scale)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("normal_strength", strength)
	mat.set_shader_parameter("height_contrast", contrast)
	mat.set_shader_parameter("slope_rule", slope)
	mat.set_shader_parameter("alt_rule", alt)
	mat.set_shader_parameter("layer_flags", flags)
	mat.set_shader_parameter("blend_depth", ground.blend_depth)
	mat.set_shader_parameter("zone_edge_noise", ground.zone_edge_noise)
	mat.set_shader_parameter("macro_scale_m", ground.macro_scale_m)
	mat.set_shader_parameter("macro_strength", ground.macro_strength)
	mat.set_shader_parameter("macro_roughness", ground.macro_roughness)
	mat.set_shader_parameter("patch_scale_m", ground.patch_scale_m)
	mat.set_shader_parameter("patch_softness", ground.patch_softness)
	mat.set_shader_parameter("bump_height_m", ground.bump_height_m)
	mat.set_shader_parameter("bump_scale_m", ground.bump_scale_m)
	mat.set_shader_parameter("lightmap_tint", ground.lightmap_tint)


## RGBA8, one slot per channel: tile id -> slot via a TileLayerMap (the PBR ground reads it through its
## GroundSet, the classic ground and its grass directly, with no GroundSet at all).
static func splat_texture(tiles: TileLayerMap, tile_ids: PackedByteArray) -> ImageTexture:
	var side := 256
	var data := PackedByteArray()
	data.resize(side * side * 4)
	data.fill(0)
	if tiles != null and tile_ids.size() == side * side:
		for cell in tile_ids.size():
			var slot := tiles.slot_of(tile_ids[cell])
			if slot < 4:
				data[cell * 4 + slot] = 255
	return ImageTexture.create_from_image(Image.create_from_data(side, side, false, Image.FORMAT_RGBA8, data))


## Gives the ground the average color of the grass in the zones where grass grows (see
## `grass_paint.gdshaderinc`). amount 0 removes it. Works on any ground material that includes it.
static func set_grass_paint(mat: ShaderMaterial, color: Color, amount: float, layers: Vector4, reference: float, wave_dir: Vector2, wave_scale: float, wave_speed: float, wave_strength: float, slope_start := 10.0, slope_end := 36.0) -> void:
	mat.set_shader_parameter("grass_wave_noise", _noise_texture())
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
	return _noise_texture()


static func _noise_texture() -> ImageTexture:
	if _noise == null:
		_build_noise()
	return _noise


static func _bump_texture() -> ImageTexture:
	if _bump == null:
		_build_noise()
	return _bump


## Four uncorrelated seamless noises in RGBA, and the gradient of a fifth height noise in RG.
static func _build_noise() -> void:
	var side := NOISE_SIZE
	var cells := side * side
	var channels: Array[PackedByteArray] = []
	for c in 5:
		var generator := FastNoiseLite.new()
		generator.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		generator.frequency = 6.0 / float(side)
		generator.fractal_octaves = 4
		generator.seed = 7022 + c * 101
		var image := generator.get_seamless_image(side, side, false, false, 0.1, true)
		image.convert(Image.FORMAT_L8)
		channels.append(image.get_data())
	var rgba := PackedByteArray()
	rgba.resize(cells * 4)
	for i in cells:
		rgba[i * 4] = channels[0][i]
		rgba[i * 4 + 1] = channels[1][i]
		rgba[i * 4 + 2] = channels[2][i]
		rgba[i * 4 + 3] = channels[3][i]
	var noise_image := Image.create_from_data(side, side, false, Image.FORMAT_RGBA8, rgba)
	noise_image.generate_mipmaps()
	_noise = ImageTexture.create_from_image(noise_image)
	var height := channels[4]
	var gradient := PackedByteArray()
	gradient.resize(cells * 3)
	gradient.fill(0)
	for y in side:
		for x in side:
			var east := float(height[y * side + (x + 1) % side])
			var west := float(height[y * side + (x + side - 1) % side])
			var south := float(height[((y + 1) % side) * side + x])
			var north := float(height[((y + side - 1) % side) * side + x])
			# Height in 0..1: slope per texel = difference / 2 / 255; stored as 0.5 + slope * 8.
			var at := (y * side + x) * 3
			gradient[at] = clampi(roundi(127.5 + (east - west) / 2.0 / 255.0 * 8.0 * 255.0), 0, 255)
			gradient[at + 1] = clampi(roundi(127.5 + (south - north) / 2.0 / 255.0 * 8.0 * 255.0), 0, 255)
	var bump_image := Image.create_from_data(side, side, false, Image.FORMAT_RGB8, gradient)
	bump_image.generate_mipmaps()
	_bump = ImageTexture.create_from_image(bump_image)


static func _load_image_texture(path: String) -> ImageTexture:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	return ImageTexture.create_from_image(image)
