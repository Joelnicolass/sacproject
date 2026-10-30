@tool
class_name GrassField3D
extends Node3D

## Grass around the camera, drawn on the GPU. Set `ground` (where it grows and how high the ground
## is: press «Bake ground» to read it from the colliders), `look` (the blades), `quality` (how many
## and how far) and `wind` (shared with any shader that reads it). The blades stand in square cells
## around where the camera looks; a cell is one MultiMeshInstance3D per kind of blade (internal,
## never saved), each showing one of a few shared MultiMeshes. Crossing a cell only moves cells,
## nothing is rebuilt, and each cell's bounds fit its ground so the renderer culls it. A new look,
## or new values in it, are uniforms only (a biome, a god's palette); only other meshes build the
## meshes again. `enabled` off frees every cell (the wind still blows for the rest of the world;
## it moves with this node's processing, so it holds while the tree is paused, by default).
## Nothing is drawn headless or on a dedicated server. In the editor it follows the viewport's
## camera with `editor_radius` (and the brush, while one paints). The ring centres on `center` when
## set (the unit an RTS camera follows), else on where the camera looks, never farther ahead of it
## than it is high (so a camera at eye height keeps grass at its feet). Keep this node at the
## origin. Added to a scene in the editor, it sets itself up (`set_up()`): select it to paint.

## The cells are hidden headless and on dedicated servers; tests set this to draw anyway.
static var draw_anywhere := false

const SHADER := preload("grass.gdshader")
## The same with alpha scissor, for a kind with `alpha_scissor` above 0.
const CUT_SHADER := preload("grass_cut.gdshader")
## How often the clearings' nodes are read again (s).
const CLEARINGS_EVERY := 0.5
const MAX_CLEARINGS := 48
const MAX_STAMPS := 48
## The look `set_up()` gives a field without one.
const DEFAULT_LOOK := "res://addons/grass_kit/looks/meadow.tres"

## Where grass grows and how high the ground is (GrassGround).
@export var ground: GrassGround:
	set(value):
		_watch(ground, value, _on_ground_changed)
		if ground != null and ground.area_changed.is_connected(_on_area_changed):
			ground.area_changed.disconnect(_on_area_changed)
			ground.map_painted.disconnect(_on_map_painted)
		ground = value
		if ground != null:
			ground.area_changed.connect(_on_area_changed)
			ground.map_painted.connect(_on_map_painted)
		_reset()
## What the blades look like (GrassLook). Another one, or new values, take effect at once.
@export var look: GrassLook:
	set(value):
		_watch(look, value, _apply_look)
		look = value
		_apply_look()
## How many blades and how far (GrassQuality).
@export var quality: GrassQuality:
	set(value):
		_watch(quality, value, _reset)
		quality = value
		_reset()
## The world's wind (GrassWind): the field ticks it every frame, and every shader that includes
## grass_wind.gdshaderinc reads it. Null = calm.
@export var wind: GrassWind:
	set(value):
		wind = value
		_reset()
## Off frees every cell (an options menu's switch); on builds them again.
@export var enabled := true:
	set(value):
		enabled = value
		_reset()
## «Bake ground»: reads the ground's heights from the colliders under `ground.area`.
@export_tool_button("Bake ground", "Bake") var bake_button := _bake_in_editor

@export_group("Clearings")
## No grass around the nodes of these groups. GrassClear3D nodes clear too.
@export var clearings: Array[GrassClearing] = []

@export_group("Trampling")
## Nodes of this group bend the grass around them (units, the player). Empty = none.
@export var trample_group: StringName = &""
## How wide each one tramples, unless the node says otherwise with a property or meta
## `grass_trample_radius` (a dragon and a gnome in the same group).
@export_range(0.05, 10.0, 0.05, "suffix:m") var trample_radius := 0.7
## How long the grass takes to stand up again behind a body (s): it leaves a trail that fades.
## 0 = it stands up at once.
@export_range(0.0, 10.0, 0.1, "or_greater", "suffix:s") var trample_recover := 0.0

@export_group("Camera")
## The camera the grass follows. Empty = the viewport's current camera.
@export var camera: Camera3D
## The grass centres on this node (the unit the camera follows). Empty = where the camera looks.
@export var center: Node3D

@export_group("Editor")
## Draw the grass in the editor, around the 3D view's camera.
@export var editor_preview := true:
	set(value):
		editor_preview = value
		_reset()
## How far it reaches in the editor (m): less than in play, so the editor stays quick.
@export_range(4.0, 500.0, 1.0, "suffix:m") var editor_radius := 25.0:
	set(value):
		editor_radius = value
		_reset()

## What the field draws now (cells and blades, all and in view).
var stats := GrassStats.new()
## While true, GrassKit's shader globals show the game's ground as it is under the drawn grass
## everywhere, with no wind: what a render of the ground from above for `ground.color_texture`
## must see (`bake_ground_color()` sets it itself; a game that renders its own view sets it around
## that render). The field writes them every frame, active or not.
var ground_bake_view := false:
	set(value):
		ground_bake_view = value
		if value and is_inside_tree():
			_write_bake_globals()
		set_process(value or _active() or wind != null)

## One material per kind of blade, and per kind one MultiMesh per tier.
var _materials: Array[ShaderMaterial] = []
var _tier_meshes: Array[Array] = []
var _kinds: Array[GrassMesh] = []
var _build_key := ""
var _quality: GrassQuality
## A cell: a Node3D with one MultiMeshInstance3D per kind.
var _cells: Dictionary[Vector2i, Node3D] = {}
var _tiers: Dictionary[Vector2i, int] = {}
var _bounds: Dictionary[Vector2i, AABB] = {}
var _pool: Array[Node3D] = []
var _center := Vector2.INF
var _ring_center := Vector2.INF
var _clearings_timer := 0.0
var _textures_dirty := true
## Per trampling body: where it passed (x, z, radius, when).
var _trails: Dictionary[int, PackedVector4Array] = {}
var _trample_time := 0.0
## Editor only: where the brush is, so the grass shows around what is painted.
var _editor_focus := Vector2.INF


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if ground == null:
		out.append("Set ground (a GrassGround): where grass grows.")
	elif ground.data == null:
		out.append("The ground is flat at flat_height: press «Bake ground» to read its heights.")
	if ground != null and ground.bake_cost().y > 64.0:
		var cost := ground.bake_cost()
		out.append(
			(
				"Baking this ground casts %d million rays and keeps %d MB: raise texel_size, or "
				+ "write the heights with set_heights()."
			)
			% [roundi(cost.x / 1000000.0), roundi(cost.y)]
		)
	if look == null:
		out.append("Set look (a GrassLook).")
	if quality == null:
		out.append("Set quality (a GrassQuality, or GrassQuality.preset()).")
	if is_inside_tree() and not global_transform.is_equal_approx(Transform3D.IDENTITY):
		out.append("Keep this node at the origin with no rotation or scale.")
	return out


func _ready() -> void:
	set_notify_transform(true)
	_reset()


func _exit_tree() -> void:
	_free_cells()


## True when this process can draw grass: not headless, not a dedicated server.
func can_draw() -> bool:
	if draw_anywhere:
		return true
	return DisplayServer.get_name() != "headless" and not OS.has_feature("dedicated_server")


## Reads the ground's heights again from the colliders within `radius` of `at`: a crater, a mound.
## Only the cells there change.
func ground_changed(at: Vector3, radius: float) -> void:
	if ground == null or not is_inside_tree():
		return
	var rect := Rect2(at.x - radius, at.z - radius, radius * 2.0, radius * 2.0)
	ground.bake(get_world_3d().direct_space_state, rect)


## Reads every ground height again from the colliders (`ground.area`).
func bake_ground() -> int:
	if ground == null or not is_inside_tree():
		return 0
	return ground.bake(get_world_3d().direct_space_state)


## Gives the field what it lacks to draw, and nothing else: a ground fitted to the scene's colliders
## (`colliders_area()`), the meadow look, medium quality and a wind. The editor does it when the
## field is added to a scene. Returns the names of what it set.
func set_up() -> PackedStringArray:
	var made := PackedStringArray()
	if ground == null:
		var fresh := GrassGround.new()
		ground = fresh
		var fitted := colliders_area()
		if fitted.has_area():
			fresh.area = fitted
		made.append("ground")
	if look == null:
		look = load(DEFAULT_LOOK) as GrassLook
		made.append("look")
	if quality == null:
		quality = GrassQuality.preset(GrassQuality.Level.MEDIUM)
		made.append("quality")
	if wind == null:
		wind = GrassWind.new()
		made.append("wind")
	return made


## The rect on the ground plane (x, z) that the scene's colliders on `ground.collision_mask` cover
## (with `meshes_too`, the scene's meshes when it has none), out to whole metres: what «Fit area»
## sets. Empty when the scene has none.
func colliders_area(meshes_too := true) -> Rect2:
	if not is_inside_tree():
		return Rect2()
	var mask := ground.collision_mask if ground != null else 1
	var colliders: Array[AABB] = []
	var meshes: Array[AABB] = []
	_boxes_under(_scene_root(), mask, colliders, meshes)
	var boxes := colliders if not colliders.is_empty() or not meshes_too else meshes
	if boxes.is_empty():
		return Rect2()
	var box := boxes[0]
	for other in boxes:
		box = box.merge(other)
	var low := Vector2(floorf(box.position.x), floorf(box.position.z))
	var high := Vector2(ceilf(box.end.x), ceilf(box.end.z))
	return Rect2(low, high - low)


## The world boxes of the colliders on `mask` and of the visible meshes under `node`, its internal
## children too (a terrain node's own collider).
func _boxes_under(node: Node, mask: int, colliders: Array[AABB], meshes: Array[AABB]) -> void:
	if node == self:
		return
	var shape := node as CollisionShape3D
	if shape != null and shape.shape != null and not shape.disabled:
		var body := shape.get_parent() as CollisionObject3D
		if body != null and body.collision_layer & mask:
			colliders.append(shape.global_transform * shape.shape.get_debug_mesh().get_aabb())
	var csg := node as CSGShape3D
	if csg != null and csg.use_collision and csg.is_root_shape() and csg.collision_layer & mask:
		colliders.append(csg.global_transform * csg.get_aabb())
	var mesh := node as MeshInstance3D
	if mesh != null and mesh.mesh != null and mesh.is_visible_in_tree():
		meshes.append(mesh.global_transform * mesh.get_aabb())
	for child in node.get_children(true):
		_boxes_under(child, mask, colliders, meshes)


## Renders the game's ground from straight above over `ground.area` and keeps it as
## `ground.color_texture`, the colour the blades' roots take. It sees the render layers in
## `ground.color_layers`, without light or fog (its colours only), as the ground shows under the
## drawn grass (`ground_bake_view`), and the field's own blades are hidden meanwhile. One texel
## per `ground.paint_texel_size`, at most GrassGround.MAX_MAP_SIZE a side. Takes two frames:
## `await field.bake_ground_color()`. Returns the image, or null where nothing renders (headless,
## a dedicated server). GrassKit ▸ Bake ground colour does it in the editor.
func bake_ground_color() -> Image:
	if ground == null or not is_inside_tree():
		return null
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		push_warning("%s: baking the ground's colour needs a window (it renders it)" % name)
		return null
	var area := ground.area
	var size := ground.new_map_size()
	var heights := ground.height_range_in(area)
	var view := SubViewport.new()
	view.size = size
	view.transparent_bg = true
	view.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var eye := Camera3D.new()
	eye.projection = Camera3D.PROJECTION_ORTHOGONAL
	eye.keep_aspect = Camera3D.KEEP_HEIGHT
	eye.size = area.size.y
	eye.near = 0.05
	eye.far = heights.y - heights.x + 200.0
	eye.cull_mask = ground.color_layers
	var plain := Environment.new()
	plain.background_mode = Environment.BG_CLEAR_COLOR
	plain.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	eye.environment = plain
	view.add_child(eye)
	add_child(view, false, Node.INTERNAL_MODE_BACK)
	# Looking down, x to the right and z down the image, as the ground's maps lie.
	var centre := area.get_center()
	eye.global_transform = Transform3D(
		Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(centre.x, heights.y + 100.0, centre.y)
	)
	eye.current = true
	var shown := visible
	visible = false
	ground_bake_view = true
	for i in 3:
		await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	ground_bake_view = false
	visible = shown
	view.queue_free()
	if image == null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	ground.set_map_texture(GrassGround.COLOR, GrassMap.from(image))
	return image


func _write_bake_globals() -> void:
	GrassGlobals.write_bake_view(look, ground)


## Reads the clearings' nodes now instead of within half a second.
func refresh_clearings() -> void:
	_clearings_timer = CLEARINGS_EVERY


func _process(delta: float) -> void:
	if ground_bake_view:
		_write_bake_globals()
	elif wind != null:
		wind.tick(delta)
	if not _active():
		return
	var view := _camera()
	if view == null:
		return
	if _textures_dirty:
		_apply_ground()
	var painting := Engine.is_editor_hint() and _editor_focus != Vector2.INF
	_center = _editor_focus if painting else _focus(view)
	_set_all(&"field_center", _center)
	if not ground_bake_view:
		_write_meeting()
	if _ring_center == Vector2.INF or _ring_center.distance_to(_center) > _quality.ring_margin():
		_update_ring(_center)
	_clearings_timer += delta
	if _clearings_timer >= CLEARINGS_EVERY:
		_clearings_timer = 0.0
		_apply_clearings()
	_apply_stamps(delta)
	_count(view)


func _active() -> bool:
	if not enabled or ground == null or look == null or quality == null or not is_inside_tree():
		return false
	if Engine.is_editor_hint():
		return editor_preview
	return can_draw()


## Builds the meshes and the materials for the settings in force, and drops every cell.
func _reset() -> void:
	_free_cells()
	if not is_inside_tree():
		return
	GrassGlobals.declare()
	if wind == null:
		GrassWind.write_calm()
	else:
		wind.write()
	set_process(_active() or wind != null)
	_materials.clear()
	if not _active():
		stats = GrassStats.new()
		return
	_quality = quality
	if Engine.is_editor_hint() and editor_radius < quality.radius:
		_quality = quality.duplicate() as GrassQuality
		_quality.radius = editor_radius
		_quality.near_radius = minf(quality.near_radius, editor_radius)
	_kinds = look.kinds()
	_build_key = look.build_key()
	_tier_meshes = GrassBlades.tier_meshes(_quality, _kinds)
	for kind in _kinds:
		var material := ShaderMaterial.new()
		material.shader = CUT_SHADER if kind.alpha_scissor > 0.0 else SHADER
		_materials.append(material)
	_apply_quality()
	_apply_look()
	_apply_ground()
	_apply_clearings()


## Sets a uniform on every kind's material.
func _set_all(uniform: StringName, value: Variant) -> void:
	for material in _materials:
		material.set_shader_parameter(uniform, value)


## Where the drawn grass ends and the colour it fades to, for the game's ground
## (grass_ground.gdshaderinc).
func _write_meeting() -> void:
	var fade := look.fade_to_ground * _quality.radius
	var field := Vector4(_center.x, _center.y, _quality.radius, fade)
	RenderingServer.global_shader_parameter_set(&"grasskit_field", field)
	var grass := look.average_color()
	var colour := Vector4(grass.r, grass.g, grass.b, look.far_grass)
	RenderingServer.global_shader_parameter_set(&"grasskit_grass", colour)
	RenderingServer.global_shader_parameter_set(&"grasskit_under", look.ground_under())


func _free_cells() -> void:
	for cell in _cells.values():
		cell.queue_free()
	for cell in _pool:
		cell.queue_free()
	_cells.clear()
	_tiers.clear()
	_bounds.clear()
	_pool.clear()
	_ring_center = Vector2.INF


func _apply_quality() -> void:
	_set_all(&"radius", _quality.radius)
	_set_all(&"near_radius", _quality.near_radius)
	_set_all(&"far_density", _quality.far_density)
	_set_all(&"min_blade_pixels", _quality.min_blade_pixels)
	_set_all(&"near_fade", _quality.near_fade)
	_set_all(&"jitter", 1.0 / sqrt(_quality.density))
	_set_all(&"morph_ends", _quality.morph_ends())
	_set_all(&"morph_band", _quality.cell_size * 0.4)


## The look's uniforms on every material; other meshes in it build the field again.
func _apply_look() -> void:
	if _materials.is_empty() or look == null:
		return
	if look.build_key() != _build_key:
		_reset()
		return
	for index in _kinds.size():
		var material := _materials[index]
		var kind := _kinds[index]
		look.apply_to(material)
		material.set_shader_parameter(&"kind_size", kind.size)
		var height := kind.mesh.get_aabb().end.y if kind.mesh != null else 1.0
		material.set_shader_parameter(&"mesh_height", maxf(height, 0.001))
		material.set_shader_parameter(&"bend_from_color", kind.bend_from_color)
		material.set_shader_parameter(&"palette", kind.palette)
		material.set_shader_parameter(&"tint", kind.tint)
		material.set_shader_parameter(&"mask_map", _mask_of(kind))
		material.set_shader_parameter(&"albedo_map", kind.albedo_texture)
		material.set_shader_parameter(&"has_albedo", kind.albedo_texture != null)
		material.set_shader_parameter(&"normal_map", kind.normal_texture)
		material.set_shader_parameter(&"has_normal_map", kind.normal_texture != null)
		material.set_shader_parameter(&"orm_map", kind.orm_texture)
		material.set_shader_parameter(&"has_orm", kind.orm_texture != null)
		material.set_shader_parameter(&"alpha_scissor", kind.alpha_scissor)


func _apply_ground() -> void:
	_textures_dirty = false
	if _materials.is_empty() or ground == null:
		return
	_set_all(&"ground_data", ground.ground_texture())
	var fade := Vector2(cos(deg_to_rad(ground.slope_fade.x)), cos(deg_to_rad(ground.slope_fade.y)))
	_set_all(&"slope_fade_cos", fade)
	_set_all(&"density_map", ground.density_texture)
	_set_all(&"size_map", ground.size_texture)
	_set_all(&"has_size_map", ground.size_texture != null)
	_set_all(&"ground_colors", ground.color_texture)
	_set_all(&"has_ground_colors", ground.color_texture != null)
	var area := ground.area
	_set_all(&"ground_area", Vector4(area.position.x, area.position.y, area.size.x, area.size.y))
	for index in mini(_kinds.size(), _materials.size()):
		_materials[index].set_shader_parameter(&"mask_map", _mask_of(_kinds[index]))
	_show_all_kinds()
	# Where grass grows, for the game's ground (grass_ground.gdshaderinc).
	var density: Texture2D = ground.density_texture
	if density == null:
		density = load(GrassGlobals.FULL_PATH)
	RenderingServer.global_shader_parameter_set(&"grasskit_density", density)
	RenderingServer.global_shader_parameter_set(
		&"grasskit_area", Vector4(area.position.x, area.position.y, area.size.x, area.size.y)
	)


## Each kind of a cell drawn only where it can grow: none where the density map is empty, a kind
## that grows by a map only where it is painted. A painted-out area costs no draws.
func _show_kinds(key: Vector2i, cell: Node3D) -> void:
	# A blade's root may stray a little past its cell.
	var rect := GrassCells.rect_of(key, _quality.cell_size).grow(1.0)
	var none := ground.map_empty_in(GrassGround.DENSITY, rect)
	for index in mini(cell.get_child_count(), _kinds.size()):
		var kind := _kinds[index]
		var shown := not none
		if shown and kind.map_name != &"" and ground.kind_maps.has(kind.map_name):
			shown = not ground.map_empty_in(kind.map_name, rect)
		(cell.get_child(index) as Node3D).visible = shown


func _show_all_kinds() -> void:
	if ground == null or _quality == null:
		return
	for key in _cells:
		_show_kinds(key, _cells[key])


func _on_map_painted(_map: StringName) -> void:
	_show_all_kinds()


## Where a kind grows: the ground's map by its name, else its own mask (null = everywhere).
func _mask_of(kind: GrassMesh) -> Texture2D:
	if ground != null and kind.map_name != &"" and ground.kind_maps.has(kind.map_name):
		return ground.kind_maps[kind.map_name]
	return kind.mask_texture


## Where the ring goes: `center` if set, else where the camera looks on the ground, but never
## farther ahead of the camera than 1.5 times its height above the ground. A high RTS camera centres
## on the middle of the screen; one at eye height keeps the grass around its feet.
func _focus(view: Camera3D) -> Vector2:
	if center != null and center.is_inside_tree():
		return Vector2(center.global_position.x, center.global_position.z)
	var eye := view.global_position
	var flat := Vector2(eye.x, eye.z)
	var forward := -view.global_basis.z
	var above := maxf(eye.y - ground.height_at(flat), 0.0)
	var reach := above * 1.5
	if forward.y < -0.01:
		var hit := eye + forward * (above / -forward.y)
		return flat + (Vector2(hit.x, hit.z) - flat).limit_length(reach)
	var ahead := Vector2(forward.x, forward.z)
	if ahead.length() < 0.001:
		return flat
	return flat + ahead.normalized() * minf(reach, _quality.radius * 0.25)


## Cells for a ring around `center`: new ones from the pool, the ones left behind back to it.
## A cell's tier is taken a little nearer than its nearest point, so the centre can move a quarter
## of a cell before the ring follows and every cell still holds the blades it must show.
func _update_ring(center: Vector2) -> void:
	_ring_center = center
	var size := _quality.cell_size
	var margin := _quality.ring_margin()
	var wanted := GrassCells.around(center, _quality.radius + margin, size)
	for key in _cells.keys():
		if not wanted.has(key):
			var gone := _cells[key]
			gone.visible = false
			_pool.append(gone)
			_cells.erase(key)
			_tiers.erase(key)
	for key in wanted:
		var tier := _quality.tier_at(maxf(wanted[key] - margin, 0.0))
		var cell: Node3D = _cells.get(key)
		if cell == null:
			cell = _pool.pop_back() if not _pool.is_empty() else _new_cell()
			_cells[key] = cell
			cell.position = Vector3(key.x * size, 0.0, key.y * size)
			var box := _bounds_of(key)
			for kind in cell.get_children():
				(kind as MultiMeshInstance3D).custom_aabb = box
			cell.visible = true
			_show_kinds(key, cell)
		if _tiers.get(key, -1) != tier:
			for index in _kinds.size():
				(cell.get_child(index) as MultiMeshInstance3D).multimesh = _tier_meshes[index][tier]
			_tiers[key] = tier


func _new_cell() -> Node3D:
	var cell := Node3D.new()
	for material in _materials:
		var kind := MultiMeshInstance3D.new()
		kind.material_override = material
		kind.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _quality.cast_shadows
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		cell.add_child(kind)
	add_child(cell, false, Node.INTERNAL_MODE_BACK)
	return cell


## The cell's bounds in its own space: its ground's lowest to highest point plus the tallest blade
## standing, and room for a blade bent past the cell's edge.
func _bounds_of(key: Vector2i) -> AABB:
	if _bounds.has(key):
		return _bounds[key]
	var size := _quality.cell_size
	var biggest := 1.0
	for kind in _kinds:
		biggest = maxf(biggest, kind.size)
	var tallest := look.height_range.y * biggest * 2.4
	var span := ground.height_range_in(GrassCells.rect_of(key, size))
	var box := AABB(
		Vector3(-tallest, span.x - 0.1, -tallest),
		Vector3(size + tallest * 2.0, span.y - span.x + tallest + 0.2, size + tallest * 2.0)
	)
	_bounds[key] = box
	return box


func _apply_clearings() -> void:
	if _materials.is_empty() or not is_inside_tree():
		return
	var found := PackedVector4Array()
	for clearing in clearings:
		if clearing == null or clearing.group == &"":
			continue
		for node in get_tree().get_nodes_in_group(clearing.group):
			if node is Node3D and found.size() < MAX_CLEARINGS:
				var at := (node as Node3D).global_position
				found.append(Vector4(at.x, at.z, clearing.radius, clearing.soft))
	for node in get_tree().get_nodes_in_group(GrassClear3D.GROUP):
		var clear := node as GrassClear3D
		if clear != null and clear.is_visible_in_tree() and found.size() < MAX_CLEARINGS:
			var at := clear.global_position
			found.append(Vector4(at.x, at.z, clear.radius, clear.soft))
	_set_all(&"clearing_count", found.size())
	found.resize(MAX_CLEARINGS)
	_set_all(&"clearings", found)


## The trampling nodes nearest the field's centre, within its radius, and with `trample_recover`
## the trails behind them, fading (the bodies first, then the freshest of their trails).
func _apply_stamps(delta: float) -> void:
	if trample_group == &"":
		_trails.clear()
		_set_all(&"stamp_count", 0)
		return
	_trample_time += delta
	var bodies := PackedVector4Array()
	var seen: Dictionary[int, bool] = {}
	for node in get_tree().get_nodes_in_group(trample_group):
		if not node is Node3D:
			continue
		var at := (node as Node3D).global_position
		var radius := _trample_radius_of(node)
		if Vector2(at.x, at.z).distance_to(_center) <= _quality.radius:
			bodies.append(Vector4(at.x, at.z, radius, 1.0))
		if trample_recover > 0.0:
			var id := node.get_instance_id()
			seen[id] = true
			var trail: PackedVector4Array = _trails.get(id, PackedVector4Array())
			var last := trail[trail.size() - 1] if not trail.is_empty() else Vector4.INF
			if Vector2(at.x, at.z).distance_to(Vector2(last.x, last.y)) > radius * 0.75:
				trail.append(Vector4(at.x, at.z, radius, _trample_time))
			else:
				# Standing still: the grass under it starts recovering only once it leaves.
				trail[trail.size() - 1] = Vector4(last.x, last.y, radius, _trample_time)
			_trails[id] = trail
	var stamps := _nearest(bodies, MAX_STAMPS)
	var faded := PackedVector4Array()
	for id in _trails.keys():
		var trail := _trails[id]
		var kept := PackedVector4Array()
		for point in trail:
			var age := _trample_time - point.w
			if age < trample_recover:
				kept.append(point)
				if Vector2(point.x, point.y).distance_to(_center) <= _quality.radius:
					faded.append(Vector4(point.x, point.y, point.z, 1.0 - age / trample_recover))
		if kept.is_empty() and not seen.has(id):
			_trails.erase(id)
		else:
			_trails[id] = kept
	if not faded.is_empty() and stamps.size() < MAX_STAMPS:
		var freshest := Array(faded)
		freshest.sort_custom(func(a: Vector4, b: Vector4) -> bool: return a.w > b.w)
		stamps.append_array(PackedVector4Array(freshest.slice(0, MAX_STAMPS - stamps.size())))
	_set_all(&"stamp_count", stamps.size())
	stamps.resize(MAX_STAMPS)
	_set_all(&"stamps", stamps)


## The `count` stamps nearest the field's centre.
func _nearest(stamps: PackedVector4Array, count: int) -> PackedVector4Array:
	if stamps.size() <= count:
		return stamps
	var by_distance := Array(stamps)
	by_distance.sort_custom(
		func(a: Vector4, b: Vector4) -> bool:
			var near_a := _center.distance_squared_to(Vector2(a.x, a.y))
			return near_a < _center.distance_squared_to(Vector2(b.x, b.y))
	)
	return PackedVector4Array(by_distance.slice(0, count))


## The node's own `grass_trample_radius` (property, then meta), else `trample_radius`.
func _trample_radius_of(node: Node) -> float:
	var own: Variant = node.get(&"grass_trample_radius")
	if own == null:
		own = node.get_meta(&"grass_trample_radius", trample_radius)
	return float(own)


## Counts the cells and blades, all of them and those whose bounds the camera sees.
func _count(view: Camera3D) -> void:
	var planes := view.get_frustum()
	var counted := GrassStats.new()
	counted.blades_by_kind.resize(_kinds.size())
	for key in _cells:
		var cell := _cells[key]
		var seen := _in_view(cell.global_transform * _bounds_of(key), planes)
		counted.cells += 1
		if seen:
			counted.cells_in_view += 1
		for index in cell.get_child_count():
			var kind := cell.get_child(index) as MultiMeshInstance3D
			if not kind.visible:
				continue
			var blades := kind.multimesh.instance_count
			counted.blades += blades
			if seen:
				counted.blades_in_view += blades
				counted.blades_by_kind[index] += blades
				counted.draws += 1
	stats = counted


static func _in_view(box: AABB, planes: Array[Plane]) -> bool:
	for plane in planes:
		# The box corner farthest along the plane's normal: outside if even it is in front.
		var corner := box.position + Vector3(
			box.size.x if plane.normal.x < 0.0 else 0.0,
			box.size.y if plane.normal.y < 0.0 else 0.0,
			box.size.z if plane.normal.z < 0.0 else 0.0
		)
		if plane.is_point_over(corner):
			return false
	return true


func _camera() -> Camera3D:
	if Engine.is_editor_hint():
		# Looked up by name: EditorInterface is not in an exported game.
		var editor := Engine.get_singleton(&"EditorInterface") if Engine.is_editor_hint() else null
		if editor == null:
			return null
		var viewport: SubViewport = editor.call(&"get_editor_viewport_3d", 0)
		return viewport.get_camera_3d() if viewport != null else null
	if camera != null:
		return camera
	return get_viewport().get_camera_3d()


func _on_ground_changed() -> void:
	_textures_dirty = true


## Part of the ground changed: the cells there take new bounds.
func _on_area_changed(rect: Rect2) -> void:
	_textures_dirty = true
	if _quality == null:
		return
	for key in _bounds.keys():
		if GrassCells.rect_of(key, _quality.cell_size).intersects(rect, true):
			_bounds.erase(key)
			if _cells.has(key):
				var box := _bounds_of(key)
				for kind in _cells[key].get_children():
					(kind as MultiMeshInstance3D).custom_aabb = box


## «Bake ground» in the editor: one step of its history (Ctrl+Z puts the old ground back), with the
## ground saved next to the scene.
func _bake_in_editor() -> void:
	if ground == null:
		push_error("%s: set ground first" % name)
		return
	var path := _keep_ground_in_file()
	if path.is_empty():
		return
	var before := ground.data.duplicate() as Image if ground.data != null else null
	var found := bake_ground()
	var after := ground.data.duplicate() as Image if ground.data != null else null
	# Looked up by name: EditorInterface is not in an exported game.
	var editor := Engine.get_singleton(&"EditorInterface") if Engine.is_editor_hint() else null
	if editor != null:
		var history: Object = editor.call(&"get_editor_undo_redo")
		history.call(&"create_action", "Bake ground of %s" % name, UndoRedo.MERGE_DISABLE, self)
		history.call(&"add_do_method", ground, &"restore_data", after)
		history.call(&"add_undo_method", ground, &"restore_data", before)
		history.call(&"add_do_method", self, &"update_configuration_warnings")
		history.call(&"add_undo_method", self, &"update_configuration_warnings")
		history.call(&"commit_action", false)
	ground.flush_maps()
	ResourceSaver.save(ground, path, ResourceSaver.FLAG_COMPRESS)
	ground._maps_edited = false
	GrassGround._edited.erase(ground)
	update_configuration_warnings()
	print("%s: ground baked, %d of %d texels hit (%s)" % [
		name, found, ground.texture_size().x * ground.texture_size().y, path
	])


## Editor only: the ground's own file, saving it next to the scene first when it lives inside the
## scene (`<scene>_grass_ground.res`): baked heights and painted maps are kept there, not in the
## scene's text. Empty (and an error) when the scene has never been saved.
func _keep_ground_in_file() -> String:
	var path := ground.resource_path
	if not path.is_empty() and not path.contains("::"):
		return path
	var scene := get_tree().edited_scene_root if Engine.is_editor_hint() else null
	if scene == null or scene.scene_file_path.is_empty():
		push_error("%s: save the scene first; the ground goes next to it" % name)
		return ""
	# Another field's ground may be there already: then this one goes by the field's name.
	var base := scene.scene_file_path.get_basename()
	path = base + "_grass_ground.res"
	var n := 1
	while FileAccess.file_exists(path):
		path = "%s_%s%s_grass_ground.res" % [base, name.to_snake_case(), "" if n == 1 else str(n)]
		n += 1
	ground.flush_maps()
	var err := ResourceSaver.save(ground, path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("%s: could not save %s (%s)" % [name, path, error_string(err)])
		return ""
	ground.take_over_path(path)
	var editor := Engine.get_singleton(&"EditorInterface") if Engine.is_editor_hint() else null
	if editor != null:
		editor.call(&"mark_scene_as_unsaved")
	return path


## The scene the field is in: the one being edited, else the running one.
func _scene_root() -> Node:
	if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
		return get_tree().edited_scene_root
	if get_tree().current_scene != null:
		return get_tree().current_scene
	return get_tree().root


## Keeps `callback` connected to the `changed` of the resource in force only.
func _watch(old: Resource, new: Resource, callback: Callable) -> void:
	if old != null and old.changed.is_connected(callback):
		old.changed.disconnect(callback)
	if new != null and not new.changed.is_connected(callback):
		new.changed.connect(callback)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		update_configuration_warnings()
