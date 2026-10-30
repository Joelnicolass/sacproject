extends GutTest
## AbilityType.needs_target: any target kind asks the player to pick one.


func test_no_target_kind_needs_no_target() -> void:
	assert_false(AbilityType.new().needs_target())


func test_each_target_kind_needs_a_target() -> void:
	var wizards := AbilityType.new()
	wizards.targets_wizards = true
	var souls := AbilityType.new()
	souls.targets_souls = true
	var creatures := AbilityType.new()
	creatures.targets_creatures = true
	var corpses := AbilityType.new()
	corpses.targets_corpses = true
	var structures := AbilityType.new()
	structures.targets_structures = true
	var ground := AbilityType.new()
	ground.targets_ground = true
	assert_true(wizards.needs_target(), "wizards")
	assert_true(souls.needs_target(), "souls")
	assert_true(creatures.needs_target(), "creatures")
	assert_true(corpses.needs_target(), "corpses")
	assert_true(structures.needs_target(), "structures")
	assert_true(ground.needs_target(), "ground")
