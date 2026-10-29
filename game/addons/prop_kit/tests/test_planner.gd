extends "res://addons/prop_kit/tests/prop_test.gd"

## PropPlanner: deterministic, spacing, keep-outs, masks, outlines, variants and the cap.


func _rules() -> PropScatterRules:
	var rules := PropScatterRules.new()
	rules.random_seed = 3
	rules.cluster_size = 60.0
	rules.cover = 0.5
	rules.spacing = 4.0
	rules.max_count = 5000
	return rules


func _ground(size := 100.0) -> PropFlatGround:
	var ground := PropFlatGround.new()
	ground.area = Rect2(0.0, 0.0, size, size)
	return ground


func _plan(
	rules: PropScatterRules,
	ground: PropGround,
	mask: PropMask = null,
	discs := PackedVector4Array(),
	weights := PackedFloat32Array()
) -> Array[PropSpot]:
	ground.begin(null)
	if mask != null:
		mask.begin(ground.bounds())
	return PropPlanner.plan(rules, ground, mask, discs, weights)


func test_the_same_inputs_give_the_same_spots() -> void:
	var a := _plan(_rules(), _ground())
	var b := _plan(_rules(), _ground())
	check(a.size() > 20, "a plan has spots (%d)" % a.size())
	check(a.size() == b.size(), "same count")
	var same := true
	for i in mini(a.size(), b.size()):
		same = same and a[i].at == b[i].at and a[i].scale == b[i].scale and a[i].angle == b[i].angle
	check(same, "same spots, scale and angle")
	var other := _rules()
	other.random_seed = 4
	var c := _plan(other, _ground())
	check(c.size() != a.size() or c[0].at != a[0].at, "another seed, another plan")


func test_spots_keep_their_room() -> void:
	var rules := _rules()
	var spots := _plan(rules, _ground(60.0))
	var crowded := 0
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			var room := rules.spacing * (spots[i].scale + spots[j].scale) * 0.5
			if spots[i].at.distance_to(spots[j].at) < room - 0.0001:
				crowded += 1
	check(crowded == 0, "no two spots closer than their room (%d crowded)" % crowded)


func test_spots_stay_inside_the_area() -> void:
	var outside := 0
	for spot in _plan(_rules(), _ground()):
		if not Rect2(0.0, 0.0, 100.0, 100.0).has_point(spot.at):
			outside += 1
	check(outside == 0, "every spot inside the ground's bounds")


func test_keep_outs_are_empty() -> void:
	var discs := PackedVector4Array([Vector4(50.0, 50.0, 20.0, 0.5)])
	var rules := _rules()
	rules.cover = 1.0
	var spots := _plan(rules, _ground(), null, discs)
	var inside := 0
	var soft := 0
	for spot in spots:
		var distance := spot.at.distance_to(Vector2(50.0, 50.0))
		if distance <= 20.0:
			inside += 1
		elif distance < 30.0:
			soft += 1
	check(spots.size() > 50, "a full cover around the keep-out (%d)" % spots.size())
	check(inside == 0, "nothing inside the keep-out's radius")
	check(soft > 0, "some in its soft edge")


func test_an_even_cover_reaches_every_quarter() -> void:
	var rules := _rules()
	rules.cover = 1.0
	var quarters := [0, 0, 0, 0]
	for spot in _plan(rules, _ground()):
		quarters[int(spot.at.x >= 50.0) + 2 * int(spot.at.y >= 50.0)] += 1
	check(quarters.min() > 20, "cover 1 fills every quarter (%s)" % [quarters])


func test_an_outline_bounds_the_scatter() -> void:
	var ground := PropFlatGround.new()
	ground.area = Rect2()
	ground.outline = PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(0, 100)])
	check(ground.bounds() == Rect2(0, 0, 100, 100), "the outline's bounds when area is empty")
	var rules := _rules()
	rules.cover = 1.0
	var outside := 0
	var spots := _plan(rules, ground)
	for spot in spots:
		if spot.at.x + spot.at.y > 100.0:
			outside += 1
	check(spots.size() > 20 and outside == 0, "every spot inside the triangle (%d)" % spots.size())


func test_a_mask_forbids_and_thins() -> void:
	var image := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(1.0, 0.0, 0.0, 1.0))
	image.set_pixel(1, 0, Color(1.0, 1.0, 0.0, 1.0))
	var mask := PropMask.new()
	mask.texture = ImageTexture.create_from_image(image)
	mask.density_channel = PropMask.Channel.RED
	mask.forbid_channel = PropMask.Channel.GREEN
	var rules := _rules()
	rules.cover = 1.0
	var right := 0
	var spots := _plan(rules, _ground(), mask)
	for spot in spots:
		if spot.at.x >= 50.0:
			right += 1
	check(spots.size() > 20 and right == 0, "the green half is forbidden (%d left)" % spots.size())
	image.set_pixel(1, 0, Color(0.0, 0.0, 0.0, 1.0))
	mask.texture = ImageTexture.create_from_image(image)
	mask.forbid_channel = PropMask.Channel.NONE
	right = 0
	for spot in _plan(rules, _ground(), mask):
		if spot.at.x >= 50.0:
			right += 1
	check(right == 0, "a density of 0 thins to nothing")


func test_a_mask_thins_part_way_and_inverted() -> void:
	var image := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(0.0, 0.0, 0.0, 1.0))
	image.set_pixel(1, 0, Color(0.0, 0.0, 1.0, 1.0))
	var mask := PropMask.new()
	mask.texture = ImageTexture.create_from_image(image)
	mask.area = Rect2(0.0, 0.0, 100.0, 100.0)
	mask.density_channel = PropMask.Channel.BLUE
	mask.density_strength = 0.6
	mask.density_invert = true
	check(mask.begin(Rect2(0.0, 0.0, 100.0, 100.0)), "the mask reads")
	check(near(mask.weight_at(Vector2(25.0, 50.0)), 1.0), "black, inverted: no thinning")
	check(near(mask.weight_at(Vector2(75.0, 50.0)), 0.4, 0.01), "white rock, inverted, 60 %%: 0.4")
	mask.density_invert = false
	check(near(mask.weight_at(Vector2(25.0, 50.0)), 0.4, 0.01), "black, not inverted: 0.4")
	mask.density_strength = 1.0
	check(near(mask.weight_at(Vector2(25.0, 50.0)), 0.0), "strength 1: all the way (as before)")
	var rules := _rules()
	rules.cover = 1.0
	mask.density_strength = 0.6
	mask.density_invert = true
	var left := 0
	var right := 0
	for spot in _plan(rules, _ground(), mask):
		if spot.at.x < 50.0:
			left += 1
		else:
			right += 1
	check(right > 0 and right < left, "fewer props on the rock, but some (%d vs %d)" % [right, left])


func test_weights_pick_the_variants() -> void:
	var rules := _rules()
	rules.cover = 1.0
	var only_first := true
	for spot in _plan(rules, _ground(), null, PackedVector4Array(), PackedFloat32Array([1.0, 0.0])):
		only_first = only_first and spot.variant == 0
	check(only_first, "a variant of weight 0 never comes up")
	var counts := [0, 0]
	var spots := _plan(rules, _ground(), null, PackedVector4Array(), PackedFloat32Array([1.0, 3.0]))
	for spot in spots:
		counts[spot.variant] += 1
	var share := float(counts[1]) / spots.size()
	check(share > 0.65 and share < 0.85, "weights 1:3 give about 75 %% (%.2f)" % share)


func test_the_cap_cuts_at_the_edges() -> void:
	var rules := _rules()
	var full := _plan(rules, _ground())
	rules.max_count = 30
	var cut := _plan(rules, _ground())
	check(cut.size() == 30, "max_count caps the plan")
	var prefix := full.size() >= 30
	for i in mini(cut.size(), full.size()):
		prefix = prefix and cut[i].at == full[i].at
	check(prefix, "the capped plan is the start of the full one (hearts first)")
	var deepest := true
	for i in range(1, cut.size()):
		deepest = deepest and cut[i - 1].depth >= cut[i].depth
	check(deepest, "planted from the deepest outwards")


func test_hearts_grow_bigger_props() -> void:
	var rules := _rules()
	rules.scale_jitter = 0.0
	rules.keep_out_shrink = 0.0
	var spots := _plan(rules, _ground(200.0))
	var first := spots[0]
	var last := spots[spots.size() - 1]
	check(first.scale > last.scale, "the heart's prop is bigger than the edge's")
	check(first.scale <= rules.scale_range.y + 0.0001, "within scale_range")


func test_no_rotation_when_asked() -> void:
	var rules := _rules()
	rules.random_rotation = false
	var turned := 0
	for spot in _plan(rules, _ground()):
		if spot.angle != 0.0:
			turned += 1
	check(turned == 0, "random_rotation off gives angle 0")


func test_nothing_without_an_area() -> void:
	var ground := PropFlatGround.new()
	ground.area = Rect2()
	check(_plan(_rules(), ground).is_empty(), "an empty ground plans nothing")
	var problems := PropPlanner.problems(null, null, [] as Array[PropVariant])
	check(problems.size() == 3, "missing rules, ground and variants are reported (%s)" % problems)
