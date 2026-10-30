extends "res://addons/grass_kit/tests/grass_test.gd"

## GrassQuality: the density curve, the tiers (each a prefix of the one before), and the counts.


func test_density_by_distance() -> void:
	var quality := GrassQuality.new()
	check(near(quality.density_at(0.0), 1.0) and near(quality.density_at(quality.near_radius), 1.0), "full up to near_radius")
	check(near(quality.density_at(quality.radius), quality.far_density), "far_density at the radius")
	check(quality.density_at(quality.radius + 0.1) == 0.0, "none past it")
	var last := 2.0
	var falling := true
	for step in 50:
		var value := quality.density_at(step * quality.radius / 50.0)
		falling = falling and value <= last
		last = value
	check(falling, "it never goes up with distance")


func test_tiers_are_prefixes() -> void:
	var quality := GrassQuality.new()
	check(quality.blades_in_tier(0) == quality.blades_per_cell(), "tier 0 holds a full cell")
	check(quality.blades_per_cell() == ceili(quality.density * quality.cell_size * quality.cell_size), "density times the cell's area")
	var counts := []
	for tier in quality.tiers:
		counts.append(quality.blades_in_tier(tier))
	var falling := true
	for k in range(1, counts.size()):
		falling = falling and counts[k] <= counts[k - 1]
	check(falling and counts[-1] > 0, "each tier holds no more than the one before (%s)" % [counts])
	check(quality.tier_at(0.0) == 0 and quality.tier_at(quality.radius) == quality.tiers - 1, "near is tier 0, the edge the last")


func test_presets_and_the_ring() -> void:
	var low := GrassQuality.preset(GrassQuality.Level.LOW)
	var medium := GrassQuality.preset(GrassQuality.Level.MEDIUM)
	var high := GrassQuality.preset(GrassQuality.Level.HIGH)
	check(low.blades_in_ring() < medium.blades_in_ring() and medium.blades_in_ring() < high.blades_in_ring(), "low < medium < high (%d, %d, %d)" % [low.blades_in_ring(), medium.blades_in_ring(), high.blades_in_ring()])
	check(medium.describe().contains("%d blades a ring" % medium.blades_in_ring()), "describe() says what a ring instances: %s" % medium.describe())
	var changed := [0]
	medium.changed.connect(func() -> void: changed[0] += 1)
	medium.radius = 50.0
	check(changed[0] == 1, "a change is announced")
