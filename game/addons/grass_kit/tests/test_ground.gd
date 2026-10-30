extends "res://addons/grass_kit/tests/grass_test.gd"

## GrassGround: flat, written from the game's data, baked from colliders, and a part of it changed.


func _ground(area := Rect2(0, 0, 20, 20)) -> GrassGround:
	var ground := GrassGround.new()
	ground.area = area
	ground.texel_size = 0.5
	return ground


func test_flat_until_baked() -> void:
	var ground := _ground()
	ground.flat_height = 2.0
	check(near(ground.height_at(Vector2(5, 5)), 2.0), "flat at flat_height")
	check(near(ground.height_range_in(Rect2(0, 0, 10, 10)), Vector2(2, 2)), "its range is that height")
	check(ground.texture_size() == Vector2i(40, 40), "40 x 40 texels for 20 m at 0.5 m")
	check(ground.ground_texture() != null, "a texture for the shader all the same")


func test_heights_from_the_game() -> void:
	var ground := _ground()
	var changed: Array[Rect2] = []
	ground.area_changed.connect(func(rect: Rect2) -> void: changed.append(rect))
	var ramp := func(x: float, z: float) -> float: return x * 0.1 + z * 0.05
	ground.set_heights(ground.area, ramp)
	check(near(ground.height_at(Vector2(7.3, 4.1)), 0.73 + 0.205, 0.02), "between the texels, the ramp's height")
	check(near(ground.height_range_in(Rect2(0, 0, 4, 4)).y, 0.6, 0.06), "the range of a part")
	check(changed.size() == 1 and changed[0].encloses(Rect2(0.5, 0.5, 19, 19)), "area_changed with the rect")
	var steep := func(x: float, _z: float) -> float: return x * 2.0 if x > 10.0 else 0.0
	ground.set_heights(ground.area, steep)
	check(near(ground.slope_at(Vector2(15, 10)), 63.43, 0.5), "its slope from the heights (%.1f°)" % ground.slope_at(Vector2(15, 10)))
	check(ground.slope_keep(Vector2(15, 10)) == 0.0, "too steep: no grass")
	check(ground.slope_keep(Vector2(5, 10)) == 1.0 and ground.normal_at(Vector2(5, 10)).y > 0.999, "flat: all of it, the normal up")
	var hole := func(x: float, _z: float) -> float: return NAN if x < 2.0 else 0.0
	ground.set_heights(Rect2(0, 0, 4, 20), hole)
	check(not ground.has_ground(Vector2(0.75, 5.25)) and ground.has_ground(Vector2(3.25, 5.25)), "NAN: no ground, no grass")
	check(changed[-1].position.x <= 0.0 and changed[-1].end.x >= 4.0, "only that part announced (%s)" % changed[-1])


func test_baked_from_colliders() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 1, 20)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(5, 1.5, 10)
	root.add_child(body)
	await physics()
	var ground := _ground()
	var space := body.get_world_3d().direct_space_state
	var hit := ground.bake(space)
	check(hit == 20 * 40, "half the texels found the box (%d)" % hit)
	check(near(ground.height_at(Vector2(4, 10)), 2.0, 0.01), "on the box: its top")
	check(ground.normal_at(Vector2(4, 10)).y > 0.999, "the box's normal")
	check(not ground.has_ground(Vector2(15.25, 5.25)), "off it: no ground, no grass")
	body.position.y = 3.5
	await physics()
	var changed: Array[Rect2] = []
	ground.area_changed.connect(func(rect: Rect2) -> void: changed.append(rect))
	ground.bake(space, Rect2(2, 2, 2, 2))
	check(near(ground.height_at(Vector2(3, 3)), 4.0, 0.01), "baked again there: the new height")
	check(near(ground.height_at(Vector2(8, 15)), 2.0, 0.01), "the rest as it was")
	check(changed.size() == 1 and changed[0].encloses(Rect2(2.25, 2.25, 1.5, 1.5)), "area_changed with that part")


## A terrain the way games have them: a height map collider, a slope with rough bumps (±15 cm at
## every vertex: creases where the triangles meet), at 30° and 60°. A blade's root height (the
## baked heights, read the way the shader reads them) against the collider's exact height under
## thousands of random points. The default texel (0.5 m) on triangles of 4 m, and 0.25 m on
## triangles of 1 m: a texel at most a quarter of the triangles keeps every root within 5 cm.
func test_roots_sit_on_the_ground() -> void:
	for setup: Vector2 in [Vector2(4.0, 0.5), Vector2(1.0, 0.25), Vector2(1.0, 0.5)]:
		var spacing := setup.x
		for degrees: float in [30.0, 60.0]:
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var side := 33
			var data := PackedFloat32Array()
			var noise := RandomNumberGenerator.new()
			noise.seed = 7
			for z in side:
				for x in side:
					data.append(x * spacing * tan(deg_to_rad(degrees)) + noise.randf_range(-0.15, 0.15))
			var map := HeightMapShape3D.new()
			map.map_width = side
			map.map_depth = side
			map.map_data = data
			shape.shape = map
			shape.scale = Vector3(spacing, 1.0, spacing)
			body.add_child(shape)
			root.add_child(body)
			await physics()
			var half := (side - 1) * spacing * 0.5
			var ground := GrassGround.new()
			ground.area = Rect2(-half, -half, half * 2.0, half * 2.0)
			ground.texel_size = setup.y
			var space := body.get_world_3d().direct_space_state
			ground.bake(space)
			var query := PhysicsRayQueryParameters3D.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = 11
			var total := 0.0
			var worst_below := 0.0
			var buried := 0
			var count := 3000
			for i in count:
				var at := Vector2(rng.randf_range(-half + 1.0, half - 1.0), rng.randf_range(-half + 1.0, half - 1.0))
				query.from = Vector3(at.x, 1000.0, at.y)
				query.to = Vector3(at.x, -1000.0, at.y)
				var exact: float = (space.intersect_ray(query)["position"] as Vector3).y
				var error := ground.height_at(at) - exact
				total += absf(error)
				worst_below = minf(worst_below, error)
				if error < -0.05:
					buried += 1
			var mean := total / count
			var label := "%d° on %d m triangles, %.2f m texels" % [degrees, spacing, setup.y]
			print("    %s: mean %.4f m, worst below %.4f m, %d of %d over 5 cm below" % [label, mean, worst_below, buried, count])
			if setup.y <= spacing * 0.25:
				check(mean < 0.01 and worst_below > -0.05, "%s: every root within 5 cm (mean %.4f, worst %.4f)" % [label, mean, worst_below])
			body.free()


func test_changes_in_one_frame_upload_once() -> void:
	var ground := _ground()
	ground.ground_texture()
	var changed: Array[Rect2] = []
	ground.area_changed.connect(func(rect: Rect2) -> void: changed.append(rect))
	var flat := func(_x: float, _z: float) -> float: return 1.0
	for i in 5:
		ground.set_heights(Rect2(i * 3, 0, 2, 2), flat)
	check(changed.size() == 5, "each change is heard at once (%d)" % changed.size())
	check(ground._upload_queued, "the textures wait for the end of the frame")
	await tree.process_frame
	check(not ground._upload_queued, "and go up once")


func test_a_big_ground_says_what_a_bake_costs() -> void:
	var ground := _ground(Rect2(0, 0, 2560, 2560))
	var cost := ground.bake_cost()
	check(near(cost.x, 5120.0 * 5120.0) and near(cost.y, 400.0, 1.0), "26 million rays, 400 MB at 0.5 m (%s)" % cost)
	var field := GrassField3D.new()
	field.ground = ground
	var warnings := "\n".join(field._get_configuration_warnings())
	check(warnings.contains("million rays"), "the inspector warns (%s)" % warnings)
	field.free()
	ground.texel_size = 2.5
	check(near(ground.bake_cost().y, 16.0, 0.1), "at 2.5 m: 16 MB")
