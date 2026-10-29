extends "res://addons/grass_kit/tests/grass_test.gd"

## The brushes' maps: a dab moves texels towards its value with its falloff, erasing goes back to
## the map's rest, smoothing evens it, the noise rags the edge the same way every time; a ground
## makes a map on the first dab, copies a texture made elsewhere, keeps its maps when saved, puts a
## stroke back for an undo, fills, clears, imports and exports, resizes its area keeping what is
## painted, aims a ray at itself and takes heights from an image.


func _ground() -> GrassGround:
	var ground := GrassGround.new()
	ground.area = Rect2(-20, -20, 40, 40)
	ground.paint_texel_size = 0.5
	return ground


func _brush(radius := 4.0, strength := 1.0, falloff := 0.5) -> GrassBrush:
	var brush := GrassBrush.new()
	brush.radius = radius
	brush.strength = strength
	brush.falloff = falloff
	return brush


## The density at `at` (x, z) on `ground`'s density map.
func _density(ground: GrassGround, at: Vector2, map := GrassGround.DENSITY) -> float:
	var image := ground.export_map(map)
	var texel := (at - ground.area.position) / ground.area.size * Vector2(image.get_size())
	return image.get_pixelv(Vector2i(texel.floor())).r


func test_a_dab_and_its_falloff() -> void:
	var image := Image.create(80, 80, false, Image.FORMAT_R8)
	image.fill(Color(0, 0, 0))
	var brush := _brush(4.0, 0.5, 0.5)
	var area := Rect2(-20, -20, 40, 40)
	var changed := brush.dab(image, area, Vector2.ZERO, Color(0, 0, 0))
	check(changed.has_area() and changed.size.x <= 18, "it changes the texels under it (%s)" % changed)
	check(near(image.get_pixel(40, 40).r, 0.5, 0.01), "at the centre, half way to white (strength 0.5)")
	check(image.get_pixel(40 + 6, 40).r > image.get_pixel(40 + 7, 40).r, "fading towards the edge")
	check(image.get_pixel(40 + 9, 40).r == 0.0 and image.get_pixel(0, 0).r == 0.0, "nothing past the radius")
	brush.dab(image, area, Vector2.ZERO, Color(0, 0, 0))
	check(near(image.get_pixel(40, 40).r, 0.75, 0.01), "a second dab goes half the rest of the way")
	brush.mode = GrassBrush.Mode.ERASE
	brush.strength = 1.0
	brush.dab(image, area, Vector2.ZERO, Color(0, 0, 0))
	check(image.get_pixel(40, 40).r == 0.0, "erasing goes back to the map's rest")


func test_smooth_and_noise() -> void:
	var image := Image.create(80, 80, false, Image.FORMAT_R8)
	image.fill(Color(0, 0, 0))
	image.set_pixel(40, 40, Color(1, 0, 0))
	var brush := _brush(3.0, 1.0, 0.0)
	brush.mode = GrassBrush.Mode.SMOOTH
	brush.dab(image, Rect2(-20, -20, 40, 40), Vector2.ZERO, Color(0, 0, 0))
	var middle := image.get_pixel(40, 40).r
	check(middle < 0.3 and image.get_pixel(41, 40).r > 0.0, "smoothing spreads a spike (%.2f)" % middle)
	var ragged := _brush(6.0, 1.0, 0.0)
	ragged.noise = 1.0
	var a := Image.create(80, 80, false, Image.FORMAT_R8)
	var b := Image.create(80, 80, false, Image.FORMAT_R8)
	ragged.dab(a, Rect2(-20, -20, 40, 40), Vector2.ZERO, Color(0, 0, 0))
	ragged.dab(b, Rect2(-20, -20, 40, 40), Vector2.ZERO, Color(0, 0, 0))
	check(a.get_data() == b.get_data(), "the noise is the same every time")
	var round := Image.create(80, 80, false, Image.FORMAT_R8)
	_brush(6.0, 1.0, 0.0).dab(round, Rect2(-20, -20, 40, 40), Vector2.ZERO, Color(0, 0, 0))
	check(a.get_data() != round.get_data(), "and rags the edge")


func test_colour_lays_over_and_uncovers() -> void:
	var image := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var brush := _brush(4.0, 0.5, 0.0)
	brush.value = Color(0.8, 0.2, 0.1, 1.0)
	brush.dab(image, Rect2(-20, -20, 40, 40), Vector2.ZERO, Color(0, 0, 0, 0))
	var texel := image.get_pixel(20, 20)
	check(near(texel.a, 0.5, 0.01) and near(texel.r, 0.8, 0.01), "half covering, in its own colour (%s)" % texel)
	brush.mode = GrassBrush.Mode.ERASE
	brush.dab(image, Rect2(-20, -20, 40, 40), Vector2.ZERO, Color(0, 0, 0, 0))
	texel = image.get_pixel(20, 20)
	check(near(texel.a, 0.25, 0.01) and near(texel.r, 0.8, 0.01), "erasing uncovers it, keeping its colour")


func test_a_ground_makes_its_map_on_the_first_dab() -> void:
	var ground := _ground()
	check(ground.map_texture(GrassGround.DENSITY) == null, "no map before painting")
	var emitted := [0]
	ground.changed.connect(func() -> void: emitted[0] += 1)
	var brush := _brush()
	brush.mode = GrassBrush.Mode.ERASE
	var changed := ground.paint(GrassGround.DENSITY, Vector2(5, 5), brush)
	check(ground.density_texture is GrassMap and ground.map_size(GrassGround.DENSITY) == Vector2i(80, 80), "the first dab makes it at paint_texel_size (%s)" % ground.map_size(GrassGround.DENSITY))
	check(emitted[0] == 1, "the field hears of the new texture once")
	check(changed.has_area() and near(_density(ground, Vector2(5, 5)), 0.0, 0.01), "no grass where it erased")
	check(near(_density(ground, Vector2(-15, -15)), 1.0, 0.01), "grass everywhere else: the map starts at its rest")
	ground.paint(GrassGround.DENSITY, Vector2(-5, 5), brush)
	check(emitted[0] == 1, "later dabs only change texels")
	check(GrassGround.map_rest(GrassGround.SIZE).r == 0.5 and GrassGround.map_rest(GrassGround.COLOR).a == 0.0 and GrassGround.map_rest(&"flower").r == 0.0, "rests: as tall as the look, the look's colour, no kind")
	check(GrassGround.map_erased(GrassGround.DENSITY).r == 0.0 and GrassGround.map_erased(GrassGround.SIZE).r == 0.5, "erasing: no grass, or back to the rest")
	var big := GrassGround.new()
	big.area = Rect2(0, 0, 4000, 1000)
	big.paint_texel_size = 0.25
	check(big.new_map_size() == Vector2i(2048, 2048), "never more than MAX_MAP_SIZE a side (%s)" % big.new_map_size())
	check(not ground._maps_queued.is_empty(), "the texture is to show it")
	await tree.process_frame
	check(ground._maps_queued.is_empty() and (ground.density_texture as GrassMap).source == ground.editable_map(GrassGround.DENSITY), "shown by the end of the frame, from the image painted")


func test_a_texture_made_elsewhere_is_copied() -> void:
	var path := "res://scratch/test_paint/painted.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var source := Image.create(16, 16, false, Image.FORMAT_RGB8)
	source.fill(Color(1, 1, 1))
	source.save_png(path)
	var outside := ImageTexture.create_from_image(source)
	outside.take_over_path(path)
	var ground := _ground()
	ground.density_texture = outside
	check(ground.export_map(GrassGround.DENSITY) != null and ground.density_texture == outside, "exporting reads it without copying")
	ground.set_map_region(GrassGround.DENSITY, Image.create(2, 2, false, Image.FORMAT_R8), Vector2i.ZERO)
	check(ground.density_texture == outside, "an undo's region does not touch it")
	var brush := _brush()
	brush.mode = GrassBrush.Mode.ERASE
	ground.paint(GrassGround.DENSITY, Vector2.ZERO, brush)
	check(ground.density_texture is GrassMap and ground.density_texture != outside, "the first dab paints a copy kept in the ground")
	check(ground.map_size(GrassGround.DENSITY) == Vector2i(16, 16), "at the texture's own size")
	check(Image.load_from_file(path).get_pixel(8, 8).r == 1.0, "the file stays as it was")


func test_maps_are_saved_in_the_ground() -> void:
	var ground := _ground()
	var brush := _brush()
	brush.mode = GrassBrush.Mode.ERASE
	ground.paint(GrassGround.DENSITY, Vector2(2, 2), brush)
	brush.mode = GrassBrush.Mode.PAINT
	brush.value = Color(1, 0, 0)
	ground.paint(&"flower", Vector2(-8, 4), brush)
	brush.value = Color(0.9, 0.3, 0.2)
	ground.paint(GrassGround.COLOR, Vector2(0, 0), brush)
	var path := "res://scratch/test_paint/ground.res"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	ground.flush_maps()
	check(ResourceSaver.save(ground, path) == OK, "saved")
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GrassGround
	check(near(_density(loaded, Vector2(2, 2)), 0.0, 0.01) and near(_density(loaded, Vector2(15, 15)), 1.0, 0.01), "the density map, as painted")
	check(loaded.kind_maps.has(&"flower") and near(_density(loaded, Vector2(-8, 4), &"flower"), 1.0, 0.01), "a kind's map, by its name")
	check(loaded.color_texture != null and loaded.export_map(GrassGround.COLOR).get_pixel(40, 40).a > 0.9, "the colour map")
	brush.mode = GrassBrush.Mode.ERASE
	loaded.paint(GrassGround.DENSITY, Vector2(10, 10), brush)
	check(loaded.density_texture == loaded.map_texture(GrassGround.DENSITY) and loaded._owns(loaded.density_texture), "a map saved inside the ground is painted in place, not copied")


func test_a_stroke_goes_back() -> void:
	var ground := _ground()
	var image := ground.editable_map(GrassGround.DENSITY)
	var texture := ground.density_texture
	var before := image.duplicate() as Image
	var brush := _brush()
	brush.mode = GrassBrush.Mode.ERASE
	var dirty := ground.paint(GrassGround.DENSITY, Vector2(0, 0), brush)
	dirty = dirty.merge(ground.paint(GrassGround.DENSITY, Vector2(3, 0), brush))
	var after := ground.map_region(GrassGround.DENSITY, dirty)
	ground.put_map(GrassGround.DENSITY, null)
	check(ground.density_texture == null, "undo of a first stroke: no map again")
	ground.put_map(GrassGround.DENSITY, texture, after, dirty.position)
	check(near(_density(ground, Vector2(1, 0)), 0.0, 0.01), "redo: the stroke is back")
	ground.put_map(GrassGround.DENSITY, texture, before.get_region(dirty), dirty.position)
	check(near(_density(ground, Vector2(1, 0)), 1.0, 0.01), "undo of a later stroke: its texels as they were")


func test_fill_clear_import_export() -> void:
	var ground := _ground()
	ground.fill_map(GrassGround.DENSITY, Color(0, 0, 0))
	check(near(_density(ground, Vector2(7, -3)), 0.0, 0.01), "filled: no grass anywhere")
	ground.clear_map(GrassGround.DENSITY)
	check(ground.density_texture == null, "cleared: back to grass everywhere")
	var image := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.5, 0.9, 0.1, 1))
	ground.import_map(GrassGround.SIZE, image)
	check(ground.map_size(GrassGround.SIZE) == Vector2i(8, 4) and near(ground.export_map(GrassGround.SIZE).get_pixel(1, 1).r, 0.5, 0.01), "imported at its own size, its red as the map")
	check(ground.export_map(GrassGround.SIZE).get_format() == Image.FORMAT_R8, "exported as one channel")


func test_resizing_the_area_keeps_what_is_painted() -> void:
	var ground := _ground()
	ground.texel_size = 1.0
	ground.set_heights(ground.area, func(x: float, z: float) -> float: return x * 0.1)
	var brush := _brush(2.0, 1.0, 0.0)
	brush.mode = GrassBrush.Mode.ERASE
	ground.paint(GrassGround.DENSITY, Vector2(10, 10), brush)
	var saved := ground.layout()
	ground.resize_area(Rect2(0, -20, 60, 40))
	check(ground.area == Rect2(0, -20, 60, 40), "the new area")
	check(near(_density(ground, Vector2(10, 10)), 0.0, 0.05), "the painted patch is where it was")
	check(near(_density(ground, Vector2(15, 0)), 1.0, 0.05) and near(_density(ground, Vector2(50, 0)), 1.0, 0.05), "grass elsewhere, and in the new part")
	check(near(ground.height_at(Vector2(15, 0)), 1.5, 0.1), "the heights are where they were")
	check(not ground.has_ground(Vector2(40, 0)), "the new part has no ground until baked")
	ground.set_layout(saved)
	check(ground.area == Rect2(-20, -20, 40, 40) and near(_density(ground, Vector2(10, 10)), 0.0, 0.05) and ground.has_ground(Vector2(-15, 0)), "the layout puts it all back")


func test_a_ray_meets_the_ground() -> void:
	var ground := _ground()
	ground.flat_height = 2.0
	var hit: Variant = ground.ray_hit(Vector3(3, 10, 4), Vector3.DOWN)
	check(hit != null and near(hit, Vector3(3, 2, 4)), "flat: at flat_height (%s)" % [hit])
	check(ground.ray_hit(Vector3(300, 10, 4), Vector3.DOWN) == null, "outside the area: none")
	ground.texel_size = 0.5
	ground.set_heights(ground.area, func(x: float, z: float) -> float: return 1.0 + x * 0.5)
	var from := Vector3(-10, 30, 0)
	var dir := Vector3(1, -1, 0).normalized()
	hit = ground.ray_hit(from, dir)
	# The ray y = 30 - (x + 10) meets y = 1 + x / 2 at x = 12.67.
	check(hit != null and near((hit as Vector3).x, 12.667, 0.05) and near((hit as Vector3).y, ground.height_at(Vector2(hit.x, hit.z)), 0.02), "on a slope (%s)" % [hit])
	check(ground.ray_hit(Vector3(0, 30, 0), Vector3.UP) == null, "a ray away from it: none")


func test_heights_from_an_image() -> void:
	var ground := _ground()
	ground.texel_size = 0.5
	var size := ground.texture_size()
	var floats := PackedFloat32Array()
	for y in size.y:
		for x in size.x:
			floats.append(float(x) * 0.25)
	floats[5] = NAN
	var image := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RF, floats.to_byte_array())
	ground.set_heights_image(image)
	check(near(ground.height_at(Vector2(-20 + 0.25 + 0.5 * 10, 0.25)), 2.5, 0.001), "the image's heights, texel for texel")
	check(near(ground.normal_at(Vector2(0, 0)), Vector3(-0.5, 1, 0).normalized(), 0.01), "and the normals from them")
	check(not ground.has_ground(Vector2(-20 + 0.5 * 5 + 0.25, -19.75)), "NAN: no ground there")
	var by_call := _ground()
	by_call.texel_size = 0.5
	by_call.set_heights(by_call.area, func(x: float, z: float) -> float: return (x + 20.0 - 0.25) * 0.5)
	check(near(by_call.height_at(Vector2(3.3, -7.1)), ground.height_at(Vector2(3.3, -7.1)), 0.01), "the same ground set_heights() writes")
	var coarse := Image.create_from_data(2, 2, false, Image.FORMAT_RF, PackedFloat32Array([0.0, 4.0, 0.0, 4.0]).to_byte_array())
	ground.set_heights_image(coarse, Rect2(-10, -10, 20, 20))
	check(near(ground.height_at(Vector2(0, 0)), 2.0, 0.05) and near(ground.height_at(Vector2(-15, 0)), 2.375, 0.01), "a smaller image over part of it, resampled; the rest kept")
	var timing := GrassGround.new()
	timing.area = Rect2(0, 0, 1000, 1000)
	timing.texel_size = 1.0
	var many := PackedFloat32Array()
	many.resize(1000 * 1000)
	var start := Time.get_ticks_msec()
	timing.set_heights_image(Image.create_from_data(1000, 1000, false, Image.FORMAT_RF, many.to_byte_array()))
	var image_ms := Time.get_ticks_msec() - start
	start = Time.get_ticks_msec()
	timing.set_heights(timing.area, func(x: float, z: float) -> float: return 0.0)
	var call_ms := Time.get_ticks_msec() - start
	print("    1M texels: set_heights_image %d ms, set_heights %d ms" % [image_ms, call_ms])
	check(image_ms < call_ms, "quicker than a call a texel")
