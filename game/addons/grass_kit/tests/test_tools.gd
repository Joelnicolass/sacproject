extends "res://addons/grass_kit/tests/grass_test.gd"

## What a person gets without code: a field that sets itself up and fits its area to the
## colliders, a kind's painted map reaching its blades, the ground under the grass taking its
## colour, trampled grass standing up again over `trample_recover`, a clearing that says when it
## changed, quality presets with their cost in sight, and the ready-made looks.

var camera: Camera3D


func _field() -> GrassField3D:
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
	camera.global_position = Vector3(0, 30, 0.01)
	camera.look_at(Vector3.ZERO)
	return field


func _frames(count := 3) -> void:
	for i in count:
		await tree.process_frame


func _materials(field: GrassField3D) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for cell in field.get_children(true):
		if cell is Node3D and (cell as Node3D).visible and cell.get_child_count() > 0:
			for kind in cell.get_children():
				out.append((kind as MultiMeshInstance3D).material_override as ShaderMaterial)
			return out
	return out


func _after() -> void:
	GrassField3D.draw_anywhere = false


func test_a_field_sets_itself_up() -> void:
	var hill := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 2, 20)
	shape.shape = box
	hill.add_child(shape)
	root.add_child(hill)
	hill.global_position = Vector3(10.4, -1, -5)
	var field := GrassField3D.new()
	root.add_child(field)
	var made := field.set_up()
	check(made == PackedStringArray(["ground", "look", "quality", "wind"]), "it set what it lacked (%s)" % made)
	check(field.ground.area == Rect2(-5, -15, 31, 20), "a ground fitted to the colliders, out to whole metres (%s)" % field.ground.area)
	check(field.look.resource_path == GrassField3D.DEFAULT_LOOK and field.quality.density == GrassQuality.preset(GrassQuality.Level.MEDIUM).density and field.wind != null, "the meadow look, medium quality, a wind")
	var look := field.look
	check(field.set_up().is_empty() and field.look == look, "set up again: nothing to set")
	hill.collision_layer = 2
	check(field.colliders_area(false) == Rect2(), "colliders on another layer do not count")
	_after()


func test_a_kind_grows_where_its_map_is_painted() -> void:
	var field := _field()
	var flower := GrassMesh.new()
	flower.mesh = SphereMesh.new()
	flower.map_name = &"flower"
	var blade := GrassMesh.new()
	blade.weight = 9.0
	field.look.meshes = [blade, flower]
	await _frames()
	var materials := _materials(field)
	check(materials.size() == 2 and materials[1].get_shader_parameter(&"mask_map") == null, "no map by that name yet: everywhere")
	var brush := GrassBrush.new()
	field.ground.paint(&"flower", Vector2(3, 3), brush)
	await _frames()
	check(materials[1].get_shader_parameter(&"mask_map") == field.ground.kind_maps[&"flower"], "the ground's map by the kind's name reaches its blades")
	check(materials[0].get_shader_parameter(&"mask_map") == null, "and only that kind's")
	_after()


func test_painted_out_cells_cost_nothing() -> void:
	var field := _field()
	var flower := GrassMesh.new()
	flower.mesh = SphereMesh.new()
	flower.map_name = &"flower"
	var blade := GrassMesh.new()
	field.look.meshes = [blade, flower]
	field.ground.paint_texel_size = 1.0
	var brush := GrassBrush.new()
	brush.radius = 3.0
	brush.strength = 1.0
	field.ground.paint(&"flower", Vector2(4, 4), brush)
	await _frames()
	var shown := 0
	var hidden := 0
	for cell in field.get_children(true):
		if (cell as Node3D).visible and cell.get_child_count() == 2:
			if (cell.get_child(1) as Node3D).visible:
				shown += 1
			else:
				hidden += 1
	check(shown >= 1 and shown <= 4 and hidden > 4, "flowers drawn only in the cells where they are painted (%d drawn, %d not)" % [shown, hidden])
	check(field.stats.blades_by_kind[1] < field.stats.blades_by_kind[0], "and counted only there (%s)" % [field.stats.blades_by_kind])
	var before := field.stats.draws
	field.ground.fill_map(GrassGround.DENSITY, Color(0, 0, 0))
	await _frames()
	check(field.stats.draws == 0 and field.stats.blades_in_view == 0, "no grass painted anywhere: no draws at all (%d before)" % before)
	brush.radius = 2.0
	field.ground.paint(GrassGround.DENSITY, Vector2(1, 1), brush)
	await _frames()
	check(field.stats.draws > 0 and field.stats.draws < before, "painted back in one place: only the cells there (%d)" % field.stats.draws)
	_after()


func test_the_ground_under_the_grass() -> void:
	var field := _field()
	field.look.under_grass = 0.8
	field.look.under_relief = 0.2
	await _frames()
	var under := field.look.ground_under()
	var plain := field.look.ground_color.srgb_to_linear()
	var light := plain.r * 0.2126 + plain.g * 0.7152 + plain.b * 0.0722
	check(near(under.x, 0.8) and near(under.y, 0.2) and near(under.z, light, 0.001), "the look's amounts reach grass_ground.gdshaderinc (%s)" % under)
	check(GrassGlobals.ALL.has(&"grasskit_under"), "a global the plugin adds to the project")
	var text := FileAccess.get_file_as_string("res://addons/grass_kit/field/grass_ground.gdshaderinc")
	check(text.contains("vec3 grasskit_ground_color(vec3 ground_rgb, vec2 xz, float grass_here)"), "the game's shader calls the same function as before")
	_after()


func test_trampled_grass_stands_up_again() -> void:
	var field := _field()
	field.trample_group = &"test_walkers"
	field.trample_recover = 1.0
	await _frames()
	var walker := Node3D.new()
	walker.add_to_group(&"test_walkers")
	root.add_child(walker)
	for step in 6:
		walker.global_position = Vector3(step * 1.0, 0, 0)
		field._apply_stamps(0.1)
	var stamps := _stamps(field)
	check(stamps.size() > 1 and near(Vector2(stamps[0].x, stamps[0].y), Vector2(5, 0)) and stamps[0].w == 1.0, "the body, then its trail (%d stamps)" % stamps.size())
	var trail := stamps.slice(1)
	var oldest: Vector4 = trail[trail.size() - 1]
	check(oldest.w < trail[0].w and oldest.w > 0.0 and near(oldest.x, 0.0), "fading the farther back (%s)" % [trail])
	walker.remove_from_group(&"test_walkers")
	field._apply_stamps(0.5)
	var left := _stamps(field)
	check(not left.is_empty() and left[0].w < 1.0, "it left: its trail goes on fading")
	field._apply_stamps(1.0)
	check(_stamps(field).is_empty() and field._trails.is_empty(), "and is gone after trample_recover")
	field.trample_recover = 0.0
	walker.add_to_group(&"test_walkers")
	field._apply_stamps(0.1)
	walker.global_position = Vector3(20, 0, 0)
	field._apply_stamps(0.1)
	check(_stamps(field).size() == 1, "trample_recover 0: only where it is")
	_after()


func _stamps(field: GrassField3D) -> Array[Vector4]:
	var material := _materials(field)[0] if not _materials(field).is_empty() else null
	var out: Array[Vector4] = []
	if material == null:
		return out
	var all: PackedVector4Array = material.get_shader_parameter(&"stamps")
	for k in int(material.get_shader_parameter(&"stamp_count")):
		out.append(all[k])
	return out


func test_a_clearing_says_when_it_changed() -> void:
	var clear := GrassClear3D.new()
	root.add_child(clear)
	var heard := [0]
	clear.changed.connect(func() -> void: heard[0] += 1)
	clear.radius = 6.0
	clear.soft = 0.5
	check(heard[0] == 2, "radius and soft each emit changed")


func test_quality_presets_and_their_cost() -> void:
	var quality := GrassQuality.new()
	quality.density = 99.0
	quality.apply_preset(GrassQuality.Level.LOW)
	var low := GrassQuality.preset(GrassQuality.Level.LOW)
	check(quality.density == low.density and quality.radius == low.radius and quality.segments == low.segments, "a preset's values, in place")
	check(quality.cost == quality.describe() and quality.cost.contains("blades a ring"), "its cost, read in the inspector (%s)" % quality.cost)
	var listed := false
	for info in quality.get_property_list():
		if info["name"] == "cost":
			listed = info["usage"] & PROPERTY_USAGE_EDITOR and not info["usage"] & PROPERTY_USAGE_STORAGE
	check(listed, "shown, never saved")


func test_ready_made_looks() -> void:
	var names := []
	for file in DirAccess.get_files_at("res://addons/grass_kit/looks"):
		if file.ends_with(".tres"):
			var look := load("res://addons/grass_kit/looks/" + file) as GrassLook
			check(look != null, "%s is a GrassLook" % file)
			names.append(file.get_basename())
	names.sort()
	check(names == ["autumn", "lush", "meadow", "steppe"], "meadow, autumn, lush, steppe (%s)" % [names])
