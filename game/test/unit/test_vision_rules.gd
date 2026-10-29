extends GutTest
## VisionRules: sight shapes, cones and memory.

const CENTER := Vector3.ZERO
const AHEAD := Vector3(0, 0, 1)


func test_cylinder_ignores_height() -> void:
	assert_true(VisionRules.covers(false, CENTER, Vector3(0, 50, 9), 10.0, AHEAD, 360.0))
	assert_false(VisionRules.covers(false, CENTER, Vector3(0, 0, 11), 10.0, AHEAD, 360.0))


func test_sphere_uses_full_distance() -> void:
	assert_true(VisionRules.covers(true, CENTER, Vector3(0, 5, 5), 10.0, AHEAD, 360.0))
	assert_false(VisionRules.covers(true, CENTER, Vector3(0, 50, 9), 10.0, AHEAD, 360.0))


func test_covers_applies_the_cone() -> void:
	assert_true(VisionRules.covers(false, CENTER, Vector3(0, 0, 5), 10.0, AHEAD, 90.0))
	assert_false(VisionRules.covers(false, CENTER, Vector3(0, 0, -5), 10.0, AHEAD, 90.0))


func test_in_cone() -> void:
	assert_true(VisionRules.in_cone(AHEAD, Vector3(1, 0, 2), 90.0), "27 degrees off, inside 45")
	assert_false(VisionRules.in_cone(AHEAD, Vector3(2, 0, 1), 90.0), "63 degrees off, outside 45")
	assert_true(VisionRules.in_cone(AHEAD, Vector3(0, 0, -1), 360.0), "360 is no cone")


func test_target_on_top_is_inside_the_cone() -> void:
	assert_true(VisionRules.in_cone(AHEAD, Vector3(0, 3, 0), 10.0))


func test_lapsed() -> void:
	assert_false(VisionRules.lapsed(100, 159, 60))
	assert_true(VisionRules.lapsed(100, 160, 60))
	assert_false(
		VisionRules.lapsed(Vision.FOREVER, Vision.FOREVER + 1000, 60), "FOREVER never lapses"
	)
