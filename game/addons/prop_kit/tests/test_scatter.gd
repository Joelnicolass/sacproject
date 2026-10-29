extends "res://addons/prop_kit/tests/prop_test.gd"

## PropScatter3D and PropScatter2D plant saved children; PropRayGround stands them on colliders.


func _scene_3d() -> PackedScene:
	var prop := StaticBody3D.new()
	prop.name = "Tree"
	var shape := CollisionShape3D.new()
	shape.name = "Trunk"
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.5
	shape.shape = cylinder
	prop.add_child(shape)
	shape.owner = prop
	var packed := PackedScene.new()
	packed.pack(prop)
	prop.free()
	return packed


func _scene_2d() -> PackedScene:
	var prop := Node2D.new()
	prop.name = "Bush"
	var packed := PackedScene.new()
	packed.pack(prop)
	prop.free()
	return packed


func _variant(scene: PackedScene) -> PropVariant:
	var variant := PropVariant.new()
	variant.scene = scene
	return variant


func _rules() -> PropScatterRules:
	var rules := PropScatterRules.new()
	rules.cover = 1.0
	rules.spacing = 5.0
	rules.max_count = 200
	return rules


func _scatter_3d(ground: PropGround) -> PropScatter3D:
	var scatter := PropScatter3D.new()
	scatter.name = "Forest"
	scatter.rules = _rules()
	scatter.ground = ground
	scatter.variants = [_variant(_scene_3d())]
	root.add_child(scatter)
	return scatter


func _flat(height := 0.0, size := 60.0) -> PropFlatGround:
	var ground := PropFlatGround.new()
	ground.area = Rect2(0.0, 0.0, size, size)
	ground.height = height
	return ground


func test_scatter_3d_plants_saved_children() -> void:
	var scatter := _scatter_3d(_flat(3.0))
	scatter.rules.sink = 0.5
	var planted := scatter.scatter(root)
	check(planted > 20 and planted == scatter.get_child_count(), "it plants children (%d)" % planted)
	var prop := scatter.get_child(0) as Node3D
	check(prop.name == &"Prop0000", "stable names")
	check(prop.owner == root, "owned by the scene, so they are saved")
	var scale := prop.global_transform.basis.get_scale().x
	check(near(prop.global_position.y, 3.0 - 0.5 * scale, 0.001), "on the ground, sunk by sink * scale")
	var first := prop.global_position
	check(scatter.scatter(root) == planted, "scatter again: the same count")
	check((scatter.get_child(0) as Node3D).global_position == first, "and the same props")
	scatter.clear()
	check(scatter.get_child_count() == 0, "clear removes them")


func test_scatter_3d_keeps_out_of_a_group() -> void:
	var start := Node3D.new()
	start.position = Vector3(30.0, 0.0, 30.0)
	root.add_child(start)
	start.add_to_group(&"test_start")
	var scatter := _scatter_3d(_flat())
	var keep := PropKeepOut.new()
	keep.group = &"test_start"
	keep.radius = 12.0
	scatter.keep_out = [keep]
	scatter.scatter(root)
	var closest := INF
	for prop: Node3D in scatter.get_children():
		closest = minf(closest, Vector2(prop.position.x, prop.position.z).distance_to(Vector2(30, 30)))
	check(closest > 12.0, "nothing within the keep-out (closest %.1f)" % closest)


func test_scatter_reports_a_broken_setup() -> void:
	var scatter := PropScatter3D.new()
	root.add_child(scatter)
	check(scatter._get_configuration_warnings().size() == 3, "no rules, ground or variants: three warnings")
	scatter.rules = _rules()
	scatter.ground = _flat()
	scatter.variants = [PropVariant.new()]
	check(scatter._get_configuration_warnings().size() == 1, "a variant without a scene")


func test_ray_ground_stands_props_on_colliders() -> void:
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 1.0, 60.0)
	shape.shape = box
	floor.add_child(shape)
	floor.position = Vector3(15.0, 1.5, 30.0)
	root.add_child(floor)
	await physics()
	var ground := PropRayGround.new()
	ground.area = Rect2(0.0, 0.0, 60.0, 60.0)
	var scatter := _scatter_3d(ground)
	var planted := scatter.scatter(root)
	var on_top := 0
	var off := 0
	for prop: Node3D in scatter.get_children():
		if prop.position.x <= 30.0 and near(prop.position.y, 2.0, 0.01):
			on_top += 1
		elif prop.position.x > 30.0:
			off += 1
	check(planted > 5 and on_top == planted, "every prop on the box's top (%d of %d)" % [on_top, planted])
	check(off == 0, "none where the rays hit nothing")


func test_ray_ground_skips_steep_slopes() -> void:
	var ramp := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Long enough that its ends (faces less steep than the top) fall outside the area.
	box.size = Vector3(240.0, 1.0, 240.0)
	shape.shape = box
	ramp.add_child(shape)
	ramp.position = Vector3(30.0, 0.0, 30.0)
	ramp.rotation_degrees.z = 60.0
	root.add_child(ramp)
	await physics()
	var ground := PropRayGround.new()
	ground.area = Rect2(0.0, 0.0, 60.0, 60.0)
	ground.max_slope_deg = 40.0
	check(_scatter_3d(ground).scatter(root) == 0, "a 60° slope takes no props")


func test_align_to_normal_leans_the_props() -> void:
	var ramp := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	shape.shape = box
	ramp.add_child(shape)
	ramp.position = Vector3(30.0, 0.0, 30.0)
	ramp.rotation_degrees.z = 20.0
	root.add_child(ramp)
	await physics()
	var ground := PropRayGround.new()
	ground.area = Rect2(10.0, 10.0, 40.0, 40.0)
	var scatter := _scatter_3d(ground)
	scatter.rules.align_to_normal = 1.0
	scatter.scatter(root)
	var prop := scatter.get_child(0) as Node3D
	var up := prop.global_transform.basis.y.normalized()
	check(near(rad_to_deg(up.angle_to(Vector3.UP)), 20.0, 0.5), "square to a 20° slope")


func test_scatter_2d_places_rotates_and_scales() -> void:
	var scatter := PropScatter2D.new()
	scatter.rules = _rules()
	scatter.rules.spacing = 40.0
	var ground := PropFlatGround.new()
	ground.area = Rect2(0.0, 0.0, 600.0, 400.0)
	scatter.ground = ground
	scatter.variants = [_variant(_scene_2d())]
	root.add_child(scatter)
	var planted := scatter.scatter(root)
	check(planted > 20 and scatter.get_child_count() == planted, "2D props planted (%d)" % planted)
	var turned := 0
	var outside := 0
	for prop: Node2D in scatter.get_children():
		if not is_zero_approx(prop.rotation):
			turned += 1
		if not ground.area.has_point(prop.global_position):
			outside += 1
		check(prop.scale.x > 0.0 and is_equal_approx(prop.scale.x, prop.scale.y), "a uniform scale")
	check(turned > 0 and outside == 0, "turned, and inside the area")


func test_run_all_scatters_a_saved_scene() -> void:
	var scene := Node3D.new()
	scene.name = "Map"
	var scatter := PropScatter3D.new()
	scatter.name = "Forest"
	scatter.rules = _rules()
	scatter.ground = _flat()
	scatter.variants = [_variant(_scene_3d())]
	scene.add_child(scatter)
	scatter.owner = scene
	root.add_child(scene)
	var planted := PropScatterRun.run_all(scene)
	var packed := PackedScene.new()
	check(packed.pack(scene) == OK, "the scattered scene packs")
	var path := "user://prop_kit_test_scene.tscn"
	check(ResourceSaver.save(packed, path) == OK, "and saves")
	var again := (load(path) as PackedScene).instantiate()
	check(again.get_node("Forest").get_child_count() == planted, "the props are in the saved scene (%d)" % planted)
	again.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
