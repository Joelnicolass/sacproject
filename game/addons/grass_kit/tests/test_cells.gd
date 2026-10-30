extends "res://addons/grass_kit/tests/grass_test.gd"

## GrassCells: the cells around a centre, and GrassBlades: the shared pattern, the tier meshes as
## prefixes of it, and the blade meshes.


func test_the_ring_covers_the_circle() -> void:
	var center := Vector2(5.0, -3.0)
	var cells := GrassCells.around(center, 30.0, 16.0)
	var covered := true
	for angle in 36:
		for r: float in [0.0, 10.0, 29.9]:
			var point := center + Vector2.from_angle(angle * TAU / 36.0) * r
			covered = covered and cells.has(Vector2i(floori(point.x / 16.0), floori(point.y / 16.0)))
	check(covered, "every point within the radius is in a cell")
	var within := true
	for cell in cells:
		var rect := GrassCells.rect_of(cell, 16.0)
		within = within and near(cells[cell], center.clamp(rect.position, rect.end).distance_to(center))
		within = within and cells[cell] <= 30.0
	check(within, "each with the distance to its nearest point, none farther than the radius")
	check(cells.get(Vector2i(0, -1), -1.0) == 0.0, "the centre's own cell is at 0")


func test_the_pattern_and_its_prefixes() -> void:
	var points := GrassBlades.points(4000, 16.0)
	check(points == GrassBlades.points(4000, 16.0), "the same points every time")
	var inside := true
	for point in points:
		inside = inside and point.x >= 0.0 and point.y >= 0.0 and point.x < 16.0 and point.y < 16.0
	check(inside, "all inside the cell")
	for count in [100, 1000]:
		var quarters := [0, 0, 0, 0]
		for i in count:
			quarters[int(points[i].x >= 8.0) + 2 * int(points[i].y >= 8.0)] += 1
		var even := true
		for q in quarters:
			even = even and absi(q - count / 4) <= count / 20 + 2
		check(even, "the first %d are spread evenly (%s)" % [count, quarters])
	var quality := GrassQuality.new()
	quality.density = 10.0
	var meshes: Array[MultiMesh] = []
	meshes.assign(GrassBlades.tier_meshes(quality, [GrassMesh.new()] as Array[GrassMesh])[0])
	check(meshes.size() == quality.tiers, "one MultiMesh per tier")
	var base := GrassBlades.points(quality.blades_per_cell(), quality.cell_size)
	var full := GrassBlades.instance_buffer(base, base.size())
	check(near(Vector2(full[3], full[11]), base[0]) and near(Vector2(full[16 * 7 + 3], full[16 * 7 + 11]), base[7]), "each blade moved to its point")
	check(near(full[16 * 7 + 12], 7.5 / base.size()), "with its rank in the whole sequence")
	var prefix := true
	for tier in meshes.size():
		var count := quality.blades_in_tier(tier)
		prefix = prefix and meshes[tier].instance_count == count
		prefix = prefix and GrassBlades.instance_buffer(base, count) == full.slice(0, count * 16)
	check(prefix, "every tier is the first blades of the same pattern")
	check(meshes[0].mesh.get_faces().size() / 3 == quality.segments * 2 - 1, "near blades have %d segments" % quality.segments)
	check(meshes[-1].mesh.get_faces().size() / 3 == 1, "the farthest is one triangle")


func test_kinds_share_the_blades_by_weight() -> void:
	var quality := GrassQuality.new()
	quality.density = 20.0
	var blade := GrassMesh.new()
	blade.weight = 90.0
	var tuft := GrassMesh.new()
	tuft.mesh = BoxMesh.new()
	tuft.weight = 8.0
	var flower := GrassMesh.new()
	flower.mesh = SphereMesh.new()
	flower.weight = 2.0
	var kinds: Array[GrassMesh] = [blade, tuft, flower]
	var meshes := GrassBlades.tier_meshes(quality, kinds)
	check(meshes.size() == 3, "a set of tiers per kind")
	var total := quality.blades_per_cell()
	var shares := []
	for kind in 3:
		shares.append(float((meshes[kind][0] as MultiMesh).instance_count) / total)
	check(absf(shares[0] - 0.9) < 0.02 and absf(shares[1] - 0.08) < 0.015 and absf(shares[2] - 0.02) < 0.008, "shares by weight (%s)" % [shares])
	var sum := 0
	for kind in 3:
		sum += (meshes[kind][quality.tiers - 1] as MultiMesh).instance_count
	check(sum == quality.blades_in_tier(quality.tiers - 1), "every tier's blades split among the kinds, none lost")
	check((meshes[1][0] as MultiMesh).mesh == tuft.mesh and (meshes[1][quality.tiers - 1] as MultiMesh).mesh == tuft.mesh, "a kind's own mesh in every tier")
	var rolled := GrassBlades.kinds_of(1000, PackedFloat32Array([90.0, 8.0, 2.0]))
	check(rolled == GrassBlades.kinds_of(1000, PackedFloat32Array([90.0, 8.0, 2.0])), "the same roll every time")


func test_a_kind_that_grows_by_a_map_adds_its_blades() -> void:
	var quality := GrassQuality.new()
	quality.density = 20.0
	var blade := GrassMesh.new()
	blade.weight = 90.0
	var flower := GrassMesh.new()
	flower.mesh = SphereMesh.new()
	flower.weight = 30.0
	flower.map_name = &"flower"
	var kinds: Array[GrassMesh] = [blade, flower]
	var meshes := GrassBlades.tier_meshes(quality, kinds)
	var total := quality.blades_per_cell()
	var blades := (meshes[0][0] as MultiMesh).instance_count
	var flowers := (meshes[1][0] as MultiMesh).instance_count
	check(blades == total, "the blades keep every point: painting flowers thins nothing (%d of %d)" % [blades, total])
	check(absi(flowers - ceili(total / 3.0)) <= 1, "the flowers add their share where they grow (%d)" % flowers)
	var last := quality.tiers - 1
	var far := (meshes[1][last] as MultiMesh).instance_count
	check(far <= ceili(quality.blades_in_tier(last) / 3.0) + 1 and far > 0, "a prefix of their own in every tier")
	var buffer := (meshes[1][0] as MultiMesh).buffer
	var first := Vector2(buffer[3], buffer[11])
	var base := (meshes[0][0] as MultiMesh).buffer
	check(not first.is_equal_approx(Vector2(base[3], base[11])), "on points of their own")
	flower.map_name = &""
	check(blade.build_key() != "" and flower.build_key() != GrassMesh.new().build_key(), "growing by a map or not changes what is built")


func test_segments_halve_and_blend() -> void:
	var quality := GrassQuality.new()
	quality.segments = 3
	check(quality.segments == 2, "segments are a power of two")
	quality.segments = 8
	var per_tier := []
	for tier in quality.tiers:
		per_tier.append(quality.segments_in_tier(tier))
	var halving := true
	for k in range(1, per_tier.size()):
		halving = halving and (per_tier[k] == per_tier[k - 1] or per_tier[k] * 2 == per_tier[k - 1])
	check(halving and per_tier[0] == 8 and per_tier[-1] == 1, "8 near, halving step by step to 1 (%s)" % [per_tier])
	var ends := quality.morph_ends()
	var starts := quality.tier_starts()
	var right := true
	for tier in range(1, quality.tiers):
		if per_tier[tier] < per_tier[tier - 1]:
			var k := int(log(float(per_tier[tier - 1])) / log(2.0) + 0.001)
			right = right and near(ends[k], starts[tier] + quality.ring_margin())
	check(right, "a blade has its coarser shape where a cell can switch to it (%s)" % ends)
