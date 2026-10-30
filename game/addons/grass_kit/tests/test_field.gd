extends "res://addons/grass_kit/tests/grass_test.gd"

## GrassField3D: cells around the camera that move without new meshes, bounds that fit the ground,
## the counts, enabled, a new look with no rebuild, a changed part of the ground, clearings,
## trampling, and nothing drawn headless unless asked.

var camera: Camera3D


## A field over a flat 200 m ground, radius 30 m, cells of 16 m, and a camera above `at` looking
## down at it.
func _field(at := Vector3.ZERO) -> GrassField3D:
	GrassField3D.draw_anywhere = true
	var field := GrassField3D.new()
	var ground := GrassGround.new()
	ground.area = Rect2(-100, -100, 200, 200)
	ground.texel_size = 1.0
	field.ground = ground
	field.look = GrassLook.new()
	var quality := GrassQuality.new()
	quality.density = 4.0
	quality.radius = 30.0
	field.quality = quality
	root.add_child(field)
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	_aim(at)
	return field


func _aim(at: Vector3) -> void:
	camera.global_position = at + Vector3(0, 30, 0.01)
	camera.look_at(at)


func _frames(count := 3) -> void:
	for i in count:
		await tree.process_frame


## The cells in use: one Node3D each, holding a MultiMeshInstance3D per kind of blade.
func _cells(field: GrassField3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child in field.get_children(true):
		if child is Node3D and (child as Node3D).visible:
			out.append(child)
	return out


func _kind(cell: Node3D, index := 0) -> MultiMeshInstance3D:
	return cell.get_child(index) as MultiMeshInstance3D


func _blades(cell: Node3D) -> int:
	var total := 0
	for kind in cell.get_children():
		total += (kind as MultiMeshInstance3D).multimesh.instance_count
	return total


func _after() -> void:
	GrassField3D.draw_anywhere = false


func test_cells_follow_the_camera() -> void:
	var field := _field()
	await _frames()
	var cells := _cells(field)
	check(cells.size() >= 12, "a ring of cells around the camera (%d)" % cells.size())
	check(field.get_child_count() == 0, "internal: not the field's children, never saved")
	var meshes := {}
	for cell in cells:
		meshes[_kind(cell).multimesh] = true
	check(meshes.size() <= field.quality.tiers, "every cell shows one of the tier meshes (%d)" % meshes.size())
	var nearest := cells[0]
	for cell in cells:
		if Vector2(cell.position.x + 8, cell.position.z + 8).length() < Vector2(nearest.position.x + 8, nearest.position.z + 8).length():
			nearest = cell
	check(_blades(nearest) == field.quality.blades_per_cell(), "the centre's cell is full")
	_aim(Vector3(500, 0, 0))
	await _frames()
	var moved := _cells(field)
	var far := true
	for cell in moved:
		far = far and cell.position.x > 400.0
		meshes[_kind(cell).multimesh] = true
	check(far and moved.size() == cells.size(), "the ring moved with the camera (%d cells)" % moved.size())
	check(meshes.size() <= field.quality.tiers, "with the same meshes: nothing rebuilt")
	_after()


func test_bounds_fit_the_ground() -> void:
	var field := _field()
	var ramp := func(x: float, _z: float) -> float: return 5.0 + x * 0.2
	field.ground.set_heights(field.ground.area, ramp)
	await _frames()
	var fits := true
	for cell in _cells(field):
		var box := cell.global_transform * _kind(cell).custom_aabb
		var low := 5.0 + cell.position.x * 0.2
		fits = fits and box.position.y <= low - 0.05 and box.end.y >= low + 3.2 + field.look.height_range.y
	check(fits, "each cell's bounds hold its ground and the tallest blade")
	_after()


func test_stats_count_what_is_drawn() -> void:
	var field := _field()
	await _frames()
	var total := 0
	for cell in _cells(field):
		total += _blades(cell)
	check(field.stats.blades == total and field.stats.cells == _cells(field).size(), "every cell and blade counted: %s" % field.stats)
	check(field.stats.blades_in_view > 0 and field.stats.blades_in_view <= field.stats.blades, "in view, a part of them")
	camera.look_at(camera.global_position + Vector3.UP, Vector3.FORWARD)
	await _frames()
	check(field.stats.cells_in_view == 0, "looking at the sky: no cell in view (%s)" % field.stats)
	_after()


func test_enabled_off_leaves_nothing() -> void:
	var field := _field()
	await _frames()
	field.enabled = false
	await _frames()
	check(field.get_child_count(true) == 0, "off: every cell freed")
	field.enabled = true
	await _frames()
	check(_cells(field).size() >= 12, "on: back")
	_after()


func test_a_new_look_rebuilds_nothing() -> void:
	var field := _field()
	await _frames()
	var before := _cells(field)
	var autumn := GrassLook.new()
	autumn.tip_color = Color(0.8, 0.6, 0.2)
	field.look = autumn
	await _frames()
	var material := _kind(before[0]).material_override as ShaderMaterial
	check((material.get_shader_parameter(&"tip_color") as Color).is_equal_approx(Color(0.8, 0.6, 0.2)), "the shader has the new colour")
	check(_cells(field) == before, "the same cells")
	autumn.width = 0.1
	check(near(material.get_shader_parameter(&"blade_width"), 0.1), "a value changed on the look reaches it too")
	_after()


func test_a_changed_part_of_the_ground() -> void:
	var field := _field()
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 2, 200)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, -1, 0)
	root.add_child(body)
	await physics()
	check(field.bake_ground() == 200 * 200, "baked from the collider")
	await _frames()
	var cell := _cells(field)[0]
	var key := Vector2i(roundi(cell.position.x / 16.0), roundi(cell.position.z / 16.0))
	var before := _kind(cell).custom_aabb
	body.position.y = 9.0
	await physics()
	var middle := Vector3(key.x * 16 + 8, 0, key.y * 16 + 8)
	field.ground_changed(middle, 4.0)
	check(near(field.ground.height_at(Vector2(middle.x, middle.z)), 10.0, 0.01), "the ground there is higher")
	check(near(field.ground.height_at(Vector2(-90, -90)), 0.0, 0.01), "the rest is not")
	check(_kind(cell).custom_aabb.end.y > before.end.y + 9.0, "that cell's bounds rose (%s -> %s)" % [before, _kind(cell).custom_aabb])
	_after()


func test_clearings_and_trampling() -> void:
	var field := _field()
	var clearing := GrassClearing.new()
	clearing.group = &"test_camps"
	field.clearings = [clearing]
	field.trample_group = &"test_units"
	for at in [Vector3(3, 0, 3), Vector3(-5, 0, 2)]:
		var camp := Node3D.new()
		camp.add_to_group(&"test_camps")
		root.add_child(camp)
		camp.global_position = at
	var clear := GrassClear3D.new()
	root.add_child(clear)
	var unit := Node3D.new()
	unit.add_to_group(&"test_units")
	root.add_child(unit)
	unit.global_position = Vector3(1, 0, 1)
	var away := Node3D.new()
	away.add_to_group(&"test_units")
	root.add_child(away)
	away.global_position = Vector3(300, 0, 0)
	field.refresh_clearings()
	await _frames()
	var material := _kind(_cells(field)[0]).material_override as ShaderMaterial
	check(material.get_shader_parameter(&"clearing_count") == 3, "two camps by group and a GrassClear3D")
	check(material.get_shader_parameter(&"stamp_count") == 1, "the unit near the field tramples, the far one does not")
	var stamps: PackedVector4Array = material.get_shader_parameter(&"stamps")
	check(near(Vector2(stamps[0].x, stamps[0].y), Vector2(1, 1)) and near(stamps[0].z, field.trample_radius), "where and how wide")
	_after()


func test_nothing_headless_unless_asked() -> void:
	var field := _field()
	GrassField3D.draw_anywhere = false
	field.enabled = false
	field.enabled = true
	await _frames()
	check(not field.can_draw(), "headless: it cannot draw")
	check(field.get_child_count(true) == 0, "so it makes no cell")


func test_where_the_ring_centres() -> void:
	var field := _field()
	camera.look_at_from_position(Vector3(0, 1.7, 0), Vector3(0, 1.4, -30))
	await _frames()
	var mean := Vector2.ZERO
	for cell in _cells(field):
		mean += Vector2(cell.position.x + 8, cell.position.z + 8)
	mean /= _cells(field).size()
	check(mean.length() < 8.0, "at eye height: around the camera's feet (%s)" % mean)
	camera.look_at_from_position(Vector3(0, 40, 0), Vector3(0, 0, -34))
	await _frames()
	var hit := Vector2.ZERO
	for cell in _cells(field):
		hit += Vector2(cell.position.x + 8, cell.position.z + 8)
	hit /= _cells(field).size()
	check(hit.distance_to(Vector2(0, -34)) < 8.0, "high up: around where it looks (%s)" % hit)
	var unit := Node3D.new()
	root.add_child(unit)
	unit.global_position = Vector3(300, 0, 300)
	field.center = unit
	await _frames()
	var far := true
	for cell in _cells(field):
		far = far and Vector2(cell.position.x + 8, cell.position.z + 8).distance_to(Vector2(300, 300)) < 46.0
	check(far, "with a centre node: around it")
	_after()


func test_each_body_tramples_its_own_width() -> void:
	var field := _field()
	field.trample_group = &"test_walkers"
	var gnome := Node3D.new()
	gnome.add_to_group(&"test_walkers")
	root.add_child(gnome)
	var dragon := Node3D.new()
	dragon.add_to_group(&"test_walkers")
	dragon.set_meta(&"grass_trample_radius", 4.0)
	root.add_child(dragon)
	dragon.global_position = Vector3(5, 0, 0)
	await _frames()
	var stamps: PackedVector4Array = (_kind(_cells(field)[0]).material_override as ShaderMaterial).get_shader_parameter(&"stamps")
	var widths := [stamps[0].z, stamps[1].z]
	widths.sort()
	check(near(widths[0], field.trample_radius) and near(widths[1], 4.0), "the field's width, and the dragon's own (%s)" % [widths])
	_after()


func test_painted_size() -> void:
	var field := _field()
	await _frames()
	var material := _kind(_cells(field)[0]).material_override as ShaderMaterial
	check(material.get_shader_parameter(&"has_size_map") == false, "no size map: the look's heights")
	var paint := Image.create(4, 4, false, Image.FORMAT_R8)
	paint.fill(Color(0.25, 0, 0))
	field.ground.size_texture = ImageTexture.create_from_image(paint)
	await _frames()
	check(material.get_shader_parameter(&"has_size_map") == true and material.get_shader_parameter(&"size_map") == field.ground.size_texture, "a size map reaches the shader")
	_after()


func test_kinds_of_blade_in_a_look() -> void:
	var field := _field()
	await _frames()
	var before := _cells(field)
	check(before[0].get_child_count() == 1, "the kit's blade alone: one kind a cell")
	var look := field.look
	var flower := GrassMesh.new()
	flower.mesh = SphereMesh.new()
	flower.weight = 1.0
	flower.alpha_scissor = 0.4
	flower.palette = 0.0
	var blade := GrassMesh.new()
	blade.weight = 9.0
	look.meshes = [blade, flower]
	await _frames()
	var cells := _cells(field)
	check(cells.size() > 0 and cells[0].get_child_count() == 2, "another mesh in the look: two kinds a cell")
	var blade_material := _kind(cells[0], 0).material_override as ShaderMaterial
	var flower_material := _kind(cells[0], 1).material_override as ShaderMaterial
	check(blade_material.shader == GrassField3D.SHADER and flower_material.shader == GrassField3D.CUT_SHADER, "the flower with alpha scissor takes the cut shader, the blade the opaque one")
	check(near(flower_material.get_shader_parameter(&"mesh_height"), (flower.mesh as SphereMesh).get_aabb().end.y) and flower_material.get_shader_parameter(&"palette") == 0.0, "the flower's own height and palette")
	var kept := _cells(field)
	look.base_color = Color(0.5, 0.2, 0.1)
	await _frames()
	check(_cells(field) == kept, "a colour change rebuilds nothing")
	check((blade_material.get_shader_parameter(&"base_color") as Color).is_equal_approx(Color(0.5, 0.2, 0.1)), "and reaches every kind")
	_after()


func test_the_wind_is_shared_and_smooth() -> void:
	var wind := GrassWind.new()
	wind.direction = Vector2(1, 0)
	wind.speed = 2.0
	wind.blend_time = 2.0
	var first := _field()
	first.wind = wind
	var second := GrassField3D.new()
	second.ground = first.ground
	second.look = first.look
	second.quality = first.quality
	second.wind = wind
	root.add_child(second)
	await _frames(2)
	var at := wind.offset
	var time := wind.time
	await tree.process_frame
	var delta := wind.time - time
	check(delta > 0.0 and delta < 0.1, "two fields share it: it moves once a frame (%.3f s)" % delta)
	check(near(wind.offset.x - at.x, 2.0 * delta, 0.001), "its pattern travels at its speed")
	wind.direction = Vector2(0, 1)
	await tree.process_frame
	check(wind.current_direction.x > 0.5, "a new direction is not there at once (%s)" % wind.current_direction)
	var since := wind.time
	while wind.time - since < wind.blend_time * 2.0:
		await tree.process_frame
	check(wind.current_direction.distance_to(Vector2(0, 1)) < 0.05, "it gets there in about blend_time (%s)" % wind.current_direction)
	wind.time_override = 3.0
	await tree.process_frame
	var frozen := wind.offset
	await tree.process_frame
	check(wind.time == 3.0 and wind.offset == frozen, "time_override stops it")
	first.enabled = false
	wind.time_override = -1.0
	var running := wind.time
	await tree.process_frame
	second.free()
	await tree.process_frame
	check(wind.time > running, "with the grass off it still blows")
	_after()


func test_the_wind_stops_with_the_pause() -> void:
	var field := _field()
	field.wind = GrassWind.new()
	await _frames(2)
	tree.paused = true
	var held := field.wind.time
	await _frames(3)
	check(field.wind.time == held, "paused tree, inherited processing: the wind holds")
	field.process_mode = Node.PROCESS_MODE_ALWAYS
	await _frames(3)
	check(field.wind.time > held, "processing always: it blows on")
	tree.paused = false
	_after()


func test_draws_by_kind() -> void:
	var field := _field()
	var blade := GrassMesh.new()
	blade.weight = 9.0
	var tuft := GrassMesh.new()
	tuft.mesh = BoxMesh.new()
	tuft.weight = 1.0
	field.look.meshes = [blade, tuft]
	await _frames()
	var stats := field.stats
	check(stats.draws == stats.cells_in_view * 2, "a draw per kind per cell in view (%s)" % stats)
	check(stats.blades_by_kind.size() == 2 and stats.blades_by_kind[0] + stats.blades_by_kind[1] == stats.blades_in_view, "blades in view by kind (%s)" % stats.blades_by_kind)
	check(stats.blades_by_kind[0] > stats.blades_by_kind[1] * 5, "by their weights")
	_after()
