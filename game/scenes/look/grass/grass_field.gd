@tool
class_name GrassField
extends LookLayer

## Grass layer of the rig: a ring of 16 m cells around the camera, every cell a
## `MultiMeshInstance3D` that points at the same MultiMesh (one for the near cells, one with fewer,
## wider blades for the far ones). Crossing a cell only moves the `transform` of the cells left
## behind: nothing is regenerated. `grass.gdshader` places, culls, bends and colors every blade, so
## the CPU does a handful of uniform writes per frame. Hiding the node, a profile without grass,
## a map without ground or a preset with grass off removes every cell.
## Everything built here (MultiMeshes, height texture, clearings, stamps) is runtime-only: the cells
## are internal children and never reach a saved scene. In a dedicated or headless process the
## rig is freed, so this never exists there. In the editor it follows the viewport camera.

const SHADER := preload("res://scenes/look/grass/grass.gdshader")
const BAKE_SHADER := preload("res://scenes/look/grass/grass_bake.gdshader")
const CELL_M := 16.0
const MAP_CELLS := 160
const HEIGHT_TEXELS := GrassHeight.SIZE
## The ground's color is baked finer (1.25 m per texel): in the distance fade a blade takes the color of
## the ground right where it stands, so what is left of it does not stand out from the ground's detail.
const GROUND_TEXELS := 2048
## The map's grass field (one per map).
const GROUP := &"grass_field"
const FAR_SEED := 7022
## Fraction of the radius where the grass is gone (see `fade_end` in grass.gdshader); cells are only
## made up to it.
const FADE_END := 0.85
## The far density starts at `near radius x FAR_START_FACTOR`; between the near radius and there the
## shader moves density and width with one smoothstep (`blend`).
const FAR_START_FACTOR := 2.2
## Tiers of the cells by distance. Every tier's MultiMesh is a prefix of the same blades, so a cell of
## tier i holds at least the density the shader asks for at the INNER edge of the tier (the density
## only goes down with the distance): if a ring held less, it would cut blades and the density LOD
## would come back. The values are the `blend` where each transition tier starts; after the last one
## there is the far tier (the constant far density, 3-vertex blades).
const TIER_BLEND := [0.0, 0.07, 0.18, 0.32, 0.48, 0.64, 0.8, 0.92]

@export_group("Follow")
## Editor only: the field follows the 3D viewport camera (turn off to freeze it).
@export var follow_editor_camera := true
## How fast the center of the field catches up with where the camera looks (per second).
@export_range(1.0, 30.0, 0.5) var center_follow_rate := 6.0

## The land height of this field's map (GrassHeight), derived the first time the field loads.
var _height_image: Image
var _height_texture: ImageTexture
## Side of the square map the height image covers, in metres (the surface's `bounds()` when it was made).
var _map_m := 0.0

var _rig: LookRig
var _grass: GrassSet
## The type as this biome draws it (the set's first type with its palette on top) and the two
## resources it came from, to tell a changed value from a changed choice.
var _type: GrassType
var _source_type: GrassType
var _palette: GrassPalette
## Luminance of the ground where grass grows (measured on the ground render): the paint's reference.
var _reference := 0.15
var _preset: LookQuality
var _material: ShaderMaterial
## One MultiMesh per tier (TIER_BLEND.size() transition tiers + the far one) and the distance where each starts.
var _tier_meshes: Array[MultiMesh] = []
var _tier_starts := PackedFloat32Array()
## Which cells exist and their tiers (shared with the other vegetation layers); `_cells` holds the nodes.
var _ring := CellRing.new(CELL_M, MAP_CELLS)
var _cells := {}
var _mask := GrassMask.new()
var _trample := GrassTrample.new()
var _center := Vector2.ZERO
var _has_center := false
var _active := false
var _clears_dirty := false
var _clear_timer := 0.0
var _map_origin := Vector3.INF
var _stamps_on := false
var _watching: Array[Resource] = []
var _bake_signature := ""
var _paint_signature := ""
var _generation := 0
var _mesh_key := ""


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(VegetationClear.FIELD_GROUP)
	visibility_changed.connect(_refresh)
	set_process(false)


func apply_look(profile: LookProfile, rig: LookRig) -> void:
	_rig = rig
	_preset = rig.quality_preset
	_set_grass(profile.grass if profile else null)


func apply_quality(preset: LookQuality) -> void:
	_preset = preset
	_refresh()


## `VegetationClear` nodes call this (through the group) when one moves, resizes or leaves.
func clears_changed() -> void:
	_clears_dirty = true


func _set_grass(grass_set: GrassSet) -> void:
	_unwatch()
	_grass = grass_set
	if _grass:
		_watch(_grass)
		for type in _grass.types:
			if type:
				_watch(type)
		if _grass.palette:
			_watch(_grass.palette)
	_refresh()


func _watch(resource: Resource) -> void:
	if not resource.changed.is_connected(_on_resource_changed):
		resource.changed.connect(_on_resource_changed)
		_watching.append(resource)


func _unwatch() -> void:
	for resource in _watching:
		if is_instance_valid(resource) and resource.changed.is_connected(_on_resource_changed):
			resource.changed.disconnect(_on_resource_changed)
	_watching.clear()


## Editing a GrassType, a GrassPalette or the GrassSet in the inspector shows live: values only, and
## the meshes again when the density changed. A different first type, palette or list rebuilds all.
func _on_resource_changed() -> void:
	if (
		not _active
		or _grass == null
		or _grass.primary() != _source_type
		or _grass.palette != _palette
	):
		_set_grass(_grass)
		return
	_type = _grass.resolved_type()
	_apply_type()
	_apply_preset()
	_push_paint(_ground_mesh())
	if _mesh_key_now() != _mesh_key:
		_build_meshes()
		for key in _cells:
			_assign_mesh(_cells[key])
	_clears_dirty = true
	if _signature() != _bake_signature:
		_refresh()
	elif _paint_signature_now() != _paint_signature and _ground_mesh() != null:
		# The roots carry the painted ground color: bake it again, the blades stay.
		_bake(_ground_mesh())


func _refresh() -> void:
	# Any bake still in flight belongs to the previous state: it must not reactivate the field.
	_generation += 1
	_free_cells()
	_active = false
	set_process(false)
	_has_center = false
	_trample.clear()
	_stamps_on = false
	_clear_paint()
	_source_type = _grass.primary() if _grass else null
	_palette = _grass.palette if _grass else null
	_type = _grass.resolved_type() if _grass else null
	if _type == null or not is_visible_in_tree():
		return
	if DisplayServer.get_name() == "headless":
		return
	# Grass is off unless a quality preset turns it on (the editor has no preset).
	if _preset == null or not _preset.grass_enabled:
		return
	var terrain := _ground_mesh()
	if (
		terrain == null
		or Terrain.of(self) == null
		or Terrain.of(self).ground_roles == null
		or terrain.material_override == null
	):
		return
	if not _load_height(terrain):
		return
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_push_paint(terrain)
	_material.set_shader_parameter("height_tex", _height_texture)
	_material.set_shader_parameter("map_size", _map_m)
	_material.set_shader_parameter("noise_tex", GroundMaterial.shared_noise())
	_map_origin = Vector3.INF
	_apply_type()
	_apply_preset()
	_build_meshes()
	_clears_dirty = true
	_bake(terrain)


## Bakes, once, what the grass shader needs per blade and would otherwise compute per vertex, the
## same for every biome: the zone data (where it grows, how tall, hillsides: grass_bake.gdshader, from
## the map's ground_roles.png and the height map) and the color of the ground, rendered from above from
## the terrain's own material with no light (so the roots have exactly the color the ground shows,
## whatever ground the biome has). Reads them back into plain textures and frees the viewports.
## Never saved.
func _bake(terrain: MeshInstance3D) -> void:
	_generation += 1
	var generation := _generation
	_bake_signature = _signature()
	_paint_signature = _paint_signature_now()
	var shown := terrain.material_override as ShaderMaterial
	if shown == null:
		return
	# A copy of the ground that can be painted or not without the player seeing it.
	var probe := shown.duplicate() as ShaderMaterial
	_probe_paint(probe, 0.0)
	var zone_view := _zone_view(0)
	var slope_view := _zone_view(1)
	var plain_view := _ground_view(terrain, probe)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var zone_image := zone_view.get_texture().get_image()
	var slope_image := slope_view.get_texture().get_image()
	var plain_image := plain_view.get_texture().get_image()
	zone_view.queue_free()
	slope_view.queue_free()
	plain_view.queue_free()
	if generation != _generation or not is_inside_tree():
		return
	_reference = _ground_luminance(plain_image, zone_image)
	_paint_into(probe)
	_probe_paint(probe, _type.paint_amount)
	var painted_view := _ground_view(terrain, probe)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ground_image := painted_view.get_texture().get_image()
	painted_view.queue_free()
	if generation != _generation or not is_inside_tree():
		return
	_push_paint(terrain)
	_material.set_shader_parameter("ground_data", ImageTexture.create_from_image(ground_image))
	_material.set_shader_parameter("zone_data", ImageTexture.create_from_image(zone_image))
	_material.set_shader_parameter("slope_data", ImageTexture.create_from_image(slope_image))
	_active = true
	set_process(true)


## The zone pass: a canvas shader over the map, 1024 px.
func _zone_view(mode: int) -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(HEIGHT_TEXELS, HEIGHT_TEXELS)
	view.disable_3d = true
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := ColorRect.new()
	rect.size = Vector2(HEIGHT_TEXELS, HEIGHT_TEXELS)
	var mat := ShaderMaterial.new()
	mat.shader = BAKE_SHADER
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("ground_roles", Terrain.of(self).ground_roles)
	mat.set_shader_parameter("ground_noise", GroundMaterial.shared_noise())
	mat.set_shader_parameter("height_tex", _height_texture)
	mat.set_shader_parameter("roles_map_size", _map_m)
	mat.set_shader_parameter("height_texel_m", _map_m / float(HEIGHT_TEXELS))
	mat.set_shader_parameter("density_by_role", _type.density_by_role)
	mat.set_shader_parameter("height_by_role", _type.height_by_role)
	mat.set_shader_parameter("slope_range", Vector2(_type.slope_start_deg, _type.slope_full_deg))
	mat.set_shader_parameter("slope_height_floor", _type.slope_height_floor)
	mat.set_shader_parameter(
		"hill_slope", Vector2(_type.paint_slope_start_deg, _type.paint_slope_end_deg)
	)
	mat.set_shader_parameter("hill_density", _type.hill_density)
	mat.set_shader_parameter("paint_amount", _type.paint_amount)
	mat.set_shader_parameter("paint_by_role", _type.paint_by_role)
	mat.set_shader_parameter(
		"paint_slope", Vector2(_type.paint_slope_start_deg, _type.paint_slope_end_deg)
	)
	rect.material = mat
	view.add_child(rect)
	add_child(view, false, Node.INTERNAL_MODE_BACK)
	return view


## The ground pass: the terrain mesh with `material` (the ground the biome shows) seen from straight
## above with an orthographic camera, unlit (albedo only), GROUND_TEXELS px over the map. Image row 0
## is z = 0 and column 0 is x = 0, like every map texture.
func _ground_view(terrain: MeshInstance3D, material: ShaderMaterial) -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(GROUND_TEXELS, GROUND_TEXELS)
	view.own_world_3d = true
	view.transparent_bg = false
	view.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var ground := MeshInstance3D.new()
	ground.mesh = terrain.mesh
	ground.material_override = material
	view.add_child(ground)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _map_m
	camera.near = 1.0
	camera.far = 4000.0
	camera.transform = Transform3D(
		Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)),
		Vector3(_map_m * 0.5, 1500.0, _map_m * 0.5)
	)
	view.add_child(camera)
	camera.current = true
	add_child(view, false, Node.INTERNAL_MODE_BACK)
	return view


## Paint of the probe copy: no wave bands (they move with time) and the given amount.
func _probe_paint(probe: ShaderMaterial, amount: float) -> void:
	probe.set_shader_parameter("grass_paint_amount", amount)
	probe.set_shader_parameter("grass_wave_strength", 0.0)


## Mean linear luminance of the ground (unpainted) where the grass grows: what the textured paint
## keeps the relief against. Copies of both images are halved to 64x64 first (the originals are the
## baked textures: shrinking them in place left the zone data at 40 m per texel).
func _ground_luminance(ground_full: Image, zone_full: Image) -> float:
	var ground := ground_full.duplicate() as Image
	var zone := zone_full.duplicate() as Image
	for image in [ground, zone]:
		image.convert(Image.FORMAT_RGBA8)
		while image.get_width() > 64:
			image.resize(image.get_width() / 2, image.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	var sum := 0.0
	var weight := 0.0
	for y in 64:
		for x in 64:
			var w := zone.get_pixel(x, y).b
			var c := ground.get_pixel(x, y).srgb_to_linear()
			sum += (c.r * 0.3 + c.g * 0.59 + c.b * 0.11) * w
			weight += w
	return clampf(sum / weight, 0.01, 1.0) if weight > 0.0 else 0.15


## What the baked textures depend on: a change rebakes them.
func _signature() -> String:
	return (
		"%s|%s|%s|%s|%s|%s|%s|%s"
		% [
			_type.density_by_role,
			_type.height_by_role,
			Vector2(_type.slope_start_deg, _type.slope_full_deg),
			_type.slope_height_floor,
			Vector2(_type.paint_slope_start_deg, _type.paint_slope_end_deg),
			_type.paint_amount,
			_type.paint_by_role,
			_type.hill_density
		]
	)


## What the painted ground color of the roots depends on (a palette edit changes it).
func _paint_signature_now() -> String:
	return "%s|%s|%s" % [_type.average_color(), _type.paint_amount, _type.paint_by_role]


## The ground takes the average color of the blades in the grass zones (and the bands of wind).
func _paint_into(mat: ShaderMaterial) -> void:
	var color := _type.average_color().srgb_to_linear()
	var wind := deg_to_rad(_type.wind_direction_deg)
	GroundMaterial.set_grass_paint(
		mat,
		color,
		_type.paint_amount,
		_type.paint_by_role,
		_reference,
		Vector2(cos(wind), sin(wind)),
		_type.wind_scale_m * 2.0,
		_type.wind_speed,
		_type.paint_waves,
		_type.paint_slope_start_deg,
		_type.paint_slope_end_deg
	)


## The ground the terrain shows takes the paint if its shader has it (the plain «no look» one has not).
func _push_paint(terrain: MeshInstance3D) -> void:
	var mat := _paintable(terrain.material_override if terrain else null)
	if mat:
		_paint_into(mat)


func _paintable(material: Variant) -> ShaderMaterial:
	var mat := material as ShaderMaterial
	if mat == null or mat.shader == null:
		return null
	for uniform in mat.shader.get_shader_uniform_list():
		if uniform.name == "grass_paint_amount":
			return mat
	return null


## Back to no paint on the ground the terrain shows (a profile change, the layer hidden, leaving the tree). A ground
## with amount 0 is the same as before the grass.
func _clear_paint() -> void:
	var terrain := _ground_mesh()
	if terrain == null or not is_instance_valid(terrain):
		return
	var shown := _paintable(terrain.material_override)
	if shown:
		shown.set_shader_parameter("grass_paint_amount", 0.0)


func _preset_value(property: StringName, fallback: Variant) -> Variant:
	if _preset == null:
		return fallback
	return _preset.get(property)


func _apply_type() -> void:
	var m := _material
	var t := _type
	m.set_shader_parameter("width_m", t.width_m)
	m.set_shader_parameter("tip_width", t.tip_width)
	m.set_shader_parameter("far_width_scale", t.far_width_scale)
	m.set_shader_parameter("far_height_scale", t.far_height_scale)
	m.set_shader_parameter("specular_amount", t.specular)
	m.set_shader_parameter("roughness_amount", t.roughness)
	m.set_shader_parameter("short_height_m", t.short_height_m)
	m.set_shader_parameter("tall_height_m", maxf(t.tall_height_m, t.short_height_m))
	m.set_shader_parameter("height_variation", t.height_variation)
	m.set_shader_parameter("lean", t.lean)
	m.set_shader_parameter("view_thicken", t.view_thicken)
	m.set_shader_parameter("open_scale_m", t.open_scale_m)
	m.set_shader_parameter("clear_falloff_m", t.clear_falloff_m)
	m.set_shader_parameter("near_fade_m", t.near_fade_m)
	m.set_shader_parameter("color_mid", t.color_mid)
	m.set_shader_parameter("color_tip", t.color_tip)
	m.set_shader_parameter("ground_mix", t.ground_mix)
	m.set_shader_parameter("clump_scale_m", t.clump_scale_m)
	m.set_shader_parameter("clump_tint", t.clump_tint)
	m.set_shader_parameter("clump_height", t.clump_height)
	m.set_shader_parameter("normal_roundness", t.normal_roundness)
	m.set_shader_parameter("translucency", t.translucency)
	m.set_shader_parameter("root_ao", t.root_ao)
	m.set_shader_parameter("root_ao_full_m", t.root_ao_full_m)
	m.set_shader_parameter("slope_color_mix", t.slope_color_mix)
	m.set_shader_parameter("slope_tip_keep", t.slope_tip_keep)
	m.set_shader_parameter("fade_start", t.fade_start)
	m.set_shader_parameter("color_fade_start", t.color_fade_start)
	m.set_shader_parameter("color_fade_end", t.color_fade_end)
	m.set_shader_parameter("min_blade_px", t.min_blade_px)
	m.set_shader_parameter("zone_full_far", t.zone_full_far)
	m.set_shader_parameter("slope_width_scale", t.slope_width_scale)
	m.set_shader_parameter("slope_lean_gain", t.slope_lean_gain)
	var wind := deg_to_rad(t.wind_direction_deg)
	m.set_shader_parameter("wind_dir", Vector2(cos(wind), sin(wind)))
	m.set_shader_parameter("wind_strength", t.wind_strength)
	m.set_shader_parameter("wind_speed", t.wind_speed)
	m.set_shader_parameter("wind_scale_m", t.wind_scale_m)
	m.set_shader_parameter("gust_lighten", t.gust_lighten)
	m.set_shader_parameter("paint_waves", t.paint_waves)
	_trample.recover_s = t.trample_recover_s
	_trample.radius_scale = t.trample_radius_scale


func _apply_preset() -> void:
	_material.set_shader_parameter("radius_m", float(_preset_value(&"grass_radius_m", 45.0)))
	_material.set_shader_parameter("fade_end", FADE_END)
	var near_r := float(_preset_value(&"grass_near_radius_m", 15.0))
	_material.set_shader_parameter("near_radius_m", near_r)
	_material.set_shader_parameter("far_start_m", near_r * FAR_START_FACTOR)
	_material.set_shader_parameter("use_clumps", bool(_preset_value(&"grass_clumps", true)))
	_material.set_shader_parameter("use_trample", bool(_preset_value(&"grass_trample", true)))


## Instances of the near MultiMesh per cell (the preset's detail scale) and of the far one (the type's
## constant far density: the preset does not lower it).
func _counts() -> Vector2i:
	var scale := float(_preset_value(&"grass_density_scale", 1.0))
	var near := maxi(roundi(_type.density_near * scale * CELL_M * CELL_M), 64)
	var far := mini(maxi(roundi(_type.density_far * CELL_M * CELL_M), 16), near)
	return Vector2i(near, far)


## What the meshes depend on: a change of it rebuilds them.
func _mesh_key_now() -> String:
	return (
		"%s|%s|%s"
		% [
			_counts(),
			int(_preset_value(&"grass_near_segments", 2)),
			_preset_value(&"grass_near_radius_m", 15.0)
		]
	)


## `blend` of the shader at a distance (the same smoothstep).
func _blend_at(distance: float, near_r: float) -> float:
	return smoothstep(near_r, near_r * FAR_START_FACTOR, distance)


## Distance at which `blend` has the given value (inverse of the smoothstep).
func _distance_at_blend(blend: float, near_r: float) -> float:
	var x := 0.5 - sin(asin(1.0 - 2.0 * clampf(blend, 0.0, 1.0)) / 3.0)
	return near_r + (FAR_START_FACTOR - 1.0) * near_r * x


func _build_meshes() -> void:
	var counts := _counts()
	var near_r := float(_preset_value(&"grass_near_radius_m", 15.0))
	var ratio := float(counts.y) / float(counts.x)
	var buffer := GrassBladeMesh.instance_buffer(counts.x, CELL_M, FAR_SEED)
	var segments := int(_preset_value(&"grass_near_segments", 2))
	var blade := GrassBladeMesh.build(segments)
	_tier_meshes.clear()
	_tier_starts.clear()
	for blend: float in TIER_BLEND:
		# The density of the shader at the inner edge of the tier (the most it will ask of it).
		var count := clampi(ceili(counts.x * pow(ratio, blend)), counts.y, counts.x)
		_tier_meshes.append(_multimesh(blade, count, buffer.slice(0, count * 16)))
		_tier_starts.append(0.0 if blend == 0.0 else _distance_at_blend(blend, near_r))
	_tier_meshes.append(
		_multimesh(GrassBladeMesh.build(1), counts.y, buffer.slice(0, counts.y * 16))
	)
	_tier_starts.append(near_r * FAR_START_FACTOR)
	_material.set_shader_parameter("far_ratio", ratio)
	_ring.tier_starts = _tier_starts
	_mesh_key = _mesh_key_now()
	_check_rings(counts, near_r)


## Invariant: the MultiMesh of every ring has at least the density the shader asks for at the inner
## edge of that ring (otherwise the ring cuts blades and the density LOD comes back).
func _check_rings(counts: Vector2i, near_r: float) -> void:
	var ratio := float(counts.y) / float(counts.x)
	for i in _tier_meshes.size():
		var wanted := float(counts.x) * pow(ratio, _blend_at(_tier_starts[i], near_r))
		if float(_tier_meshes[i].instance_count) < wanted - 1.0:
			push_warning(
				(
					"GrassField: ring %d has %d blades per cell and the shader asks for %.0f at its inner edge: the thinning shows again."
					% [i, _tier_meshes[i].instance_count, wanted]
				)
			)


func _multimesh(mesh: Mesh, count: int, buffer: PackedFloat32Array) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	multimesh.buffer = buffer
	return multimesh


func _process(delta: float) -> void:
	if not _active:
		return
	var camera := _camera()
	if camera == null:
		return
	if global_position != _map_origin:
		_map_origin = global_position
		_material.set_shader_parameter("map_origin", _map_origin)
	var radius := float(_preset_value(&"grass_radius_m", 45.0)) * FADE_END
	var cam_local := to_local(camera.global_position)
	var forward := (
		(global_transform.basis.inverse() * -camera.global_transform.basis.z).normalized()
	)
	var ground_y := _height_at(cam_local.x, cam_local.z)
	var target := CellRing.field_center(
		cam_local, forward, float(_preset_value(&"grass_near_radius_m", 15.0)), ground_y
	)
	if _has_center:
		_center = _center.lerp(target, 1.0 - exp(-delta * center_follow_rate))
	else:
		_center = target
		_has_center = true
	_material.set_shader_parameter("field_center", _center)
	_material.set_shader_parameter("camera_xz", Vector2(cam_local.x, cam_local.z))
	_material.set_shader_parameter("camera_y", cam_local.y)
	var fade_center := CellRing.fade_center(cam_local, forward, ground_y)
	_material.set_shader_parameter("fade_center", fade_center)
	_update_cells(radius, fade_center)
	_update_clears(delta)
	_update_trample(delta, radius)


## A cell exists while it is inside the radius around the fade center (the shader fades the grass by the distance to
## it); its tier (how many blades) goes by the distance to the field's center, like the density in the shader.
func _update_cells(radius: float, eye: Vector2) -> void:
	var changes := _ring.update(radius, eye, _center)
	for key: Vector2i in changes["added"]:
		_add_cell(key, _ring.tier_of(key))
	for key: Vector2i in changes["removed"]:
		var node: MultiMeshInstance3D = _cells[key]
		_cells.erase(key)
		node.queue_free()
	for key: Vector2i in changes["retiered"]:
		var node: MultiMeshInstance3D = _cells[key]
		node.set_meta(&"tier", _ring.tier_of(key))
		_assign_mesh(node)


func _add_cell(key: Vector2i, tier: int) -> void:
	var node := MultiMeshInstance3D.new()
	node.set_meta(&"tier", tier)
	node.material_override = _material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	node.position = Vector3(key.x * CELL_M, 0.0, key.y * CELL_M)
	var range_y := _height_range(key)
	var margin := 1.0
	node.custom_aabb = AABB(
		Vector3(-margin, range_y.x - 0.5, -margin),
		Vector3(
			CELL_M + margin * 2.0,
			range_y.y - range_y.x + _type.tall_height_m * 2.0 + 1.0,
			CELL_M + margin * 2.0
		)
	)
	_assign_mesh(node)
	add_child(node, false, Node.INTERNAL_MODE_BACK)
	_cells[key] = node


func _assign_mesh(node: MultiMeshInstance3D) -> void:
	node.multimesh = _tier_meshes[clampi(int(node.get_meta(&"tier")), 0, _tier_meshes.size() - 1)]


func _free_cells() -> void:
	for key in _cells:
		var node: MultiMeshInstance3D = _cells[key]
		if is_instance_valid(node):
			node.queue_free()
	_cells.clear()
	_ring.clear()


func _update_clears(delta: float) -> void:
	_clear_timer -= delta
	if _clear_timer <= 0.0:
		_clear_timer = 1.0
		_clears_dirty = true
	if not _clears_dirty:
		return
	_clears_dirty = false
	_mask.gather(get_tree(), self, _grass)
	_material.set_shader_parameter("clears", _mask.padded())
	_material.set_shader_parameter("clear_count", _mask.clears.size())


func _update_trample(delta: float, radius: float) -> void:
	if not bool(_preset_value(&"grass_trample", true)):
		if _stamps_on:
			_stamps_on = false
			_material.set_shader_parameter("stamp_count", 0)
		return
	_trample.update(delta, get_tree(), self, _center, radius, _height_at)
	var count := _trample.count
	if count > 0:
		_material.set_shader_parameter("stamps", _trample.stamps)
	_material.set_shader_parameter("stamp_count", count)
	_stamps_on = count > 0


## The node that draws the map's ground (`terrain.mesh`).
func _ground_mesh() -> MeshInstance3D:
	return _rig.terrain.mesh if _rig and _rig.terrain else null


func _camera() -> Camera3D:
	return CellRing.view_camera(self, follow_editor_camera)


## Baked land height under a map position (nearest texel; 0 off the map).
func _height_at(x: float, z: float) -> float:
	if _height_image == null:
		return 0.0
	var tx := clampi(int(x / _map_m * HEIGHT_TEXELS), 0, HEIGHT_TEXELS - 1)
	var tz := clampi(int(z / _map_m * HEIGHT_TEXELS), 0, HEIGHT_TEXELS - 1)
	return _height_image.get_pixel(tx, tz).r


## (lowest, highest) land height in a cell, from the baked map.
func _height_range(key: Vector2i) -> Vector2:
	var texels := CELL_M / (_map_m / float(HEIGHT_TEXELS))
	var x0 := maxi(int(floor(key.x * texels)) - 1, 0)
	var x1 := mini(int(ceil((key.x + 1) * texels)) + 1, HEIGHT_TEXELS - 1)
	var z0 := maxi(int(floor(key.y * texels)) - 1, 0)
	var z1 := mini(int(ceil((key.y + 1) * texels)) + 1, HEIGHT_TEXELS - 1)
	var low := INF
	var high := -INF
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var h := _height_image.get_pixel(x, z).r
			low = minf(low, h)
			high = maxf(high, h)
	return Vector2(low, high)


## The land height, derived from the terrain the first time a field loads (GrassHeight): not stored anywhere.
func _load_height(terrain: Object) -> bool:
	if _height_texture:
		return true
	var shape := Terrain.of(self)
	if shape == null:
		return false
	var image := GrassHeight.from_shape(shape)
	_map_m = shape.bounds().size.x
	_height_image = image
	var half := image.duplicate() as Image
	half.convert(Image.FORMAT_RGH)
	_height_texture = ImageTexture.create_from_image(half)
	return true


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var type := _grass.primary() if _grass else null
	if type and type.far_coverage() < GrassType.MIN_FAR_COVERAGE:
		(
			warnings
			. append(
				(
					"The far coverage (%.1f) is below %.1f: bare ground shows between blades. Raise density_far or far_width_scale."
					% [type.far_coverage(), GrassType.MIN_FAR_COVERAGE]
				)
			)
		)
	if _grass and _grass.types.size() > 1:
		warnings.append("Only the first GrassType of the GrassSet is drawn.")
	return warnings


func _exit_tree() -> void:
	_clear_paint()
	_unwatch()
