extends GutTest
## DeathRules: souls left by a death and what happens to a creature whose doctor dies.


func test_leaves_soul() -> void:
	assert_true(DeathRules.leaves_soul(1, false))
	assert_false(DeathRules.leaves_soul(1, true), "a burst body leaves none")
	assert_false(DeathRules.leaves_soul(0, false), "a creature with no souls leaves none")


func test_held_creature_lands_alive_by_default() -> void:
	var outcome := DeathRules.on_carrier_lost(DeathRules.Carried.HELD, true, false)
	assert_eq(outcome, DeathRules.Outcome.LAND_ALIVE)


func test_held_creature_dies_when_the_match_says_so() -> void:
	var outcome := DeathRules.on_carrier_lost(DeathRules.Carried.HELD, true, true)
	assert_eq(outcome, DeathRules.Outcome.DROP_DEAD)


func test_reviving_body_always_dies() -> void:
	var outcome := DeathRules.on_carrier_lost(DeathRules.Carried.REVIVING, true, false)
	assert_eq(outcome, DeathRules.Outcome.DROP_DEAD)


func test_dead_body_stays_dead() -> void:
	var outcome := DeathRules.on_carrier_lost(DeathRules.Carried.HELD, false, false)
	assert_eq(outcome, DeathRules.Outcome.DROP_DEAD)
