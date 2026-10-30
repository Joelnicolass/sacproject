@tool
class_name GrassLayer
extends LookLayer

## Grass layer of the rig: GrassKit's GrassField3D (`field`) around the body the camera follows.
## It hands the field what only Sacrifice knows: the god's look (`LookProfile.grass`), the preset's
## grass knobs (`LookQuality.grass_*`), the weather's wind, the player's «Pasto» switch, and the
## ground: heights from `Terrain.height_at` (followed live as the terrain moves), where grass grows
## and how tall from the map's ground roles (grass_bake.gdshader) and the colour of the god's ground
## seen from above. All of it is derived when the layer loads and never saved. It also lets the
## ground meet the far grass (the ground's grass paint, `GroundMaterial.set_grass_paint`).
## Nothing is drawn headless or on a dedicated server (the rig is freed there). In the editor the
## field follows the viewport camera.

## Bodies of this group bend the grass around them (UnitBody and WizardBody join it).
const TRAMPLE_GROUP := &"tramples_grass"
const BAKE_SHADER := preload("res://scenes/look/grass/grass_bake.gdshader")
## The ground's colour, seen from above (1.25 m per texel on a 2560 m map): the roots take the
## colour of the ground right where they stand.
const COLOR_TEXELS := 2048

## The grass (GrassKit). Its look, quality, ground and `enabled` are set from here.
@export var field: GrassField3D
## The match's atmosphere: the weather multiplies the field's wind (WeatherState.wind_mul).
@export var atmosphere: Atmosphere

@export_group("Ground")
## Metres per texel of the ground's heights: a quarter of the terrain's 10 m cells keeps the roots
## within a few cm of the ground.
@export_range(0.5, 10.0, 0.25, "suffix:m") var texel_size := 2.5
## Slope (deg) where GrassKit starts thinning the grass and where there is none.
@export var slope_fade := Vector2(60.0, 85.0)
## Density per kind of ground (x..w = open, earth, rock, path).
@export var density_by_role := Vector4(1.0, 0.35, 0.0, 0.3)
## Height per kind of ground (1 = the look's height).
@export var height_by_role := Vector4(1.0, 0.5, 0.0, 0.0)
## Slope (deg) where the grass starts getting shorter and where it is `slope_height_floor` tall.
@export var slope_range := Vector2(10.0, 40.0)
@export_range(0.2, 1.0, 0.01) var slope_height_floor := 0.55
## Slope (deg) where a hillside starts and where it is full: hillsides get `hill_density` grass on
## every kind of ground where grass grows at all.
@export var hill_slope := Vector2(10.0, 36.0)
@export_range(0.0, 1.0, 0.01) var hill_density := 0.9

@export_group("Ground paint")
## How much the ground takes the grass's colour where grass grows (0 = never; how much under the
## blades is the look's `under_grass`).
@export_range(0.0, 1.0, 0.01) var paint_amount := 1.0
## Share of it per kind of ground (x..w = open, earth, rock, path).
@export var paint_by_role := Vector4(1.0, 0.75, 0.0, 0.65)
## Slope (deg) where the paint starts to fade and where it is gone.
@export var paint_slope := Vector2(10.0, 36.0)
## How strong the wind's pale bands are on the painted ground.
@export_range(0.0, 1.0, 0.01) var paint_waves := 0.12

var _rig: LookRig
var _preset: LookQuality
## The terrain the field's ground was built from, and the material its colour was rendered from.
var _terrain: Terrain
var _colored_from: Material
var _colored_look: GrassLook
var _quality_key := ""
var _base_wind := 0.0
var _generation := 0


func _ready() -> void:
	visibility_changed.connect(_refresh)
	if field != null and field.wind != null and not Engine.is_editor_hint():
		# The weather writes this copy; the .tres stays as approved.
		field.wind = field.wind.duplicate() as GrassWind
	if field != null and field.wind != null:
		_base_wind = field.wind.strength
	if atmosphere != null and not Engine.is_editor_hint():
		atmosphere.changed.connect(_on_atmosphere)
	set_process(not Engine.is_editor_hint())


func apply_look(profile: LookProfile, rig: LookRig) -> void:
	if _rig != rig:
		if _rig and _rig.grass_toggled.is_connected(_on_grass_toggled):
			_rig.grass_toggled.disconnect(_on_grass_toggled)
		if rig and not rig.grass_toggled.is_connected(_on_grass_toggled):
			rig.grass_toggled.connect(_on_grass_toggled)
	_rig = rig
	_preset = rig.quality_preset if rig else null
	if field != null:
		field.look = profile.grass if profile else null
	_refresh()


func apply_quality(preset: LookQuality) -> void:
	_preset = preset
	_refresh()


func _on_grass_toggled(_enabled: bool) -> void:
	_refresh()


func _on_atmosphere(sample: AtmosphereSample) -> void:
	if field != null and field.wind != null:
		field.wind.strength = _base_wind * sample.wind


## The field centres on the body the camera follows (WorldCamera.follow).
func _process(_delta: float) -> void:
	if field == null or not field.enabled:
		return
	var camera := get_viewport().get_camera_3d()
	field.center = camera.get(&"follow") as Node3D if camera != null else null


func _refresh() -> void:
	if field == null:
		return
	var terrain := _rig.terrain if _rig else null
	var wanted := _wanted(terrain)
	if wanted:
		_apply_quality()
		if terrain != _terrain:
			_build_ground(terrain)
		elif _mesh_material(terrain) != _colored_from or field.look != _colored_look:
			_bake_color(terrain, field.ground)
	var on := wanted and field.ground != null and terrain == _terrain
	if field.enabled != on:
		field.enabled = on
	_paint(terrain, on)


func _wanted(terrain: Terrain) -> bool:
	return (
		field.look != null
		and is_visible_in_tree()
		and DisplayServer.get_name() != "headless"
		and _preset != null
		and _preset.grass_enabled
		and (_rig == null or _rig.grass_enabled)
		and terrain != null
		and terrain.ground_roles != null
		and _mesh_material(terrain) != null
	)


## The preset's grass knobs as GrassKit's quality; set again only when one of them changed (a new
## quality builds the field's meshes again).
func _apply_quality() -> void:
	var key := (
		"%s|%s|%s|%s"
		% [
			_preset.grass_radius_m,
			_preset.grass_near_radius_m,
			_preset.grass_density,
			_preset.grass_near_segments,
		]
	)
	if key != _quality_key or field.quality == null:
		_quality_key = key
		var quality := GrassQuality.new()
		quality.radius = _preset.grass_radius_m
		quality.near_radius = _preset.grass_near_radius_m
		quality.density = _preset.grass_density
		quality.segments = _preset.grass_near_segments
		field.quality = quality
	field.trample_group = TRAMPLE_GROUP if _preset.grass_trample else &""


## The field's ground from the terrain: heights now, then the roles' density and size and the
## ground's colour (a few frames of rendering). Follows the terrain from then on.
func _build_ground(terrain: Terrain) -> void:
	_generation += 1
	var generation := _generation
	_watch_terrain(terrain)
	field.ground = null
	var ground := GrassGround.new()
	ground.area = terrain.bounds()
	ground.texel_size = texel_size
	ground.slope_fade = slope_fade
	ground.set_heights_image(_heights_image(terrain, ground))
	var density := await _bake_roles(ground, 0)
	var size := await _bake_roles(ground, 1)
	if generation != _generation or not is_inside_tree():
		return
	ground.density_texture = density
	ground.size_texture = size
	if not await _bake_color(terrain, ground):
		return
	if generation != _generation or not is_inside_tree():
		return
	field.ground = ground
	_refresh()


## The colour of the god's ground seen from above, unlit and painted as it shows under the blades
## (so the roots have exactly the colour of the ground between them), into `ground`. False when a
## newer build replaced this one meanwhile.
func _bake_color(terrain: Terrain, ground: GrassGround) -> bool:
	var shown := _mesh_material(terrain)
	_colored_from = shown
	_colored_look = field.look
	var generation := _generation
	var probe := shown.duplicate() as ShaderMaterial
	_paint_material(probe, paint_amount, 0.0)
	# The field writes GrassKit's ground colours only once it draws, after this bake.
	GrassGlobals.write_bake_view(field.look, ground)
	var view := _ground_view(terrain, probe, ground.area.size.x)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	view.queue_free()
	if generation != _generation or not is_inside_tree():
		return false
	ground.color_texture = ImageTexture.create_from_image(image)
	_paint(terrain, field.enabled)
	return true


## One pass of grass_bake.gdshader over the map (mode 0 density, 1 size), read back.
func _bake_roles(ground: GrassGround, mode: int) -> ImageTexture:
	var texels := ground.texture_size()
	var view := SubViewport.new()
	view.size = texels
	view.disable_3d = true
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := ColorRect.new()
	rect.size = Vector2(texels)
	var mat := ShaderMaterial.new()
	mat.shader = BAKE_SHADER
	mat.set_shader_parameter(&"mode", mode)
	mat.set_shader_parameter(&"ground_roles", _rig.terrain.ground_roles)
	mat.set_shader_parameter(&"ground_noise", GroundMaterial.shared_noise())
	mat.set_shader_parameter(&"roles_map_size", ground.area.size.x)
	mat.set_shader_parameter(&"height_tex", ground.ground_texture())
	mat.set_shader_parameter(&"height_texel_m", ground.area.size.x / float(texels.x))
	mat.set_shader_parameter(&"density_by_role", density_by_role)
	mat.set_shader_parameter(&"height_by_role", height_by_role)
	mat.set_shader_parameter(&"slope_range", slope_range)
	mat.set_shader_parameter(&"slope_height_floor", slope_height_floor)
	mat.set_shader_parameter(&"hill_slope", hill_slope)
	mat.set_shader_parameter(&"hill_density", hill_density)
	rect.material = mat
	view.add_child(rect)
	add_child(view, false, Node.INTERNAL_MODE_BACK)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	view.queue_free()
	return ImageTexture.create_from_image(image)


## The terrain mesh with `material` seen from straight above with an orthographic camera, unlit
## (albedo only), over the map. Image row 0 is z = 0 and column 0 is x = 0, like every map texture.
func _ground_view(terrain: Terrain, material: ShaderMaterial, map_m: float) -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(COLOR_TEXELS, COLOR_TEXELS)
	view.own_world_3d = true
	view.transparent_bg = false
	view.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var ground := MeshInstance3D.new()
	ground.mesh = terrain.mesh.mesh
	ground.material_override = material
	view.add_child(ground)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = map_m
	camera.near = 1.0
	camera.far = 4000.0
	camera.transform = Transform3D(
		Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)),
		Vector3(map_m * 0.5, 1500.0, map_m * 0.5)
	)
	view.add_child(camera)
	camera.current = true
	add_child(view, false, Node.INTERNAL_MODE_BACK)
	return view


## Follows `terrain`: a moved part of the ground gets new heights; a terrain derived again (the
## editor's brush, a reimport) builds the ground again.
func _watch_terrain(terrain: Terrain) -> void:
	if _terrain != null and is_instance_valid(_terrain):
		_terrain.changed.disconnect(_on_terrain_changed)
		_terrain.derived.disconnect(_on_terrain_derived)
	_terrain = terrain
	terrain.changed.connect(_on_terrain_changed)
	terrain.derived.connect(_on_terrain_derived)


func _on_terrain_changed(rect: Rect2) -> void:
	if field.ground != null and _terrain != null:
		field.ground.set_heights(rect.grow(texel_size), _terrain.height_at)


## The terrain's heights at the centre of every texel of `ground` (NAN over a hole), as GrassKit
## reads them in one go.
func _heights_image(terrain: Terrain, ground: GrassGround) -> Image:
	var size := ground.texture_size()
	var cell := ground.area.size / Vector2(size)
	var heights := PackedFloat32Array()
	heights.resize(size.x * size.y)
	for y in size.y:
		var z := ground.area.position.y + (y + 0.5) * cell.y
		for x in size.x:
			heights[y * size.x + x] = terrain.height_at(
				ground.area.position.x + (x + 0.5) * cell.x, z
			)
	return Image.create_from_data(size.x, size.y, false, Image.FORMAT_RF, heights.to_byte_array())


func _on_terrain_derived() -> void:
	_terrain = null
	_refresh()


## The ground takes the grass's colour while the field draws, and its own otherwise.
func _paint(terrain: Terrain, on: bool) -> void:
	var mat := _paintable(_mesh_material(terrain))
	if mat:
		_paint_material(mat, paint_amount if on else 0.0, paint_waves)


func _paint_material(mat: ShaderMaterial, amount: float, waves: float) -> void:
	GroundMaterial.set_grass_paint(mat, amount, paint_by_role, paint_slope, waves)


func _mesh_material(terrain: Terrain) -> ShaderMaterial:
	if terrain == null or terrain.mesh == null:
		return null
	return terrain.mesh.material_override as ShaderMaterial


func _paintable(mat: ShaderMaterial) -> ShaderMaterial:
	if mat == null or mat.shader == null:
		return null
	for uniform in mat.shader.get_shader_uniform_list():
		if uniform.name == "grass_paint_amount":
			return mat
	return null


func _exit_tree() -> void:
	_generation += 1
	if _rig:
		_paint(_rig.terrain, false)
