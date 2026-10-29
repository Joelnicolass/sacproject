extends GutTest
## DamagePassive: incoming and melee factors as linear functions of the relative health h.


func _passive(base: float, per_health: float, per_missing: float) -> DamagePassive:
	var passive: DamagePassive = autofree(DamagePassive.new())
	passive.incoming_base = base
	passive.incoming_per_health = per_health
	passive.outgoing_melee_per_missing = per_missing
	return passive


func test_defaults_change_nothing() -> void:
	var passive: DamagePassive = autofree(DamagePassive.new())
	assert_eq(passive.incoming(0.3), 1.0)
	assert_eq(passive.outgoing_melee(0.3), 1.0)


func test_taurock_hide() -> void:
	var hide := _passive(0.25, 0.75, 0.0)
	assert_almost_eq(hide.incoming(1.0), 1.0, 1e-6)
	assert_almost_eq(hide.incoming(0.5), 0.625, 1e-6)
	assert_almost_eq(hide.incoming(0.0), 0.25, 1e-6)


func test_firefist_fury() -> void:
	var fury := _passive(1.0, 0.0, 1.5)
	assert_almost_eq(fury.outgoing_melee(1.0), 1.0, 1e-6)
	assert_almost_eq(fury.outgoing_melee(0.5), 1.75, 1e-6)
	assert_almost_eq(fury.outgoing_melee(0.0), 2.5, 1e-6)


func test_health_is_clamped() -> void:
	var hide := _passive(0.25, 0.75, 1.5)
	assert_almost_eq(hide.incoming(2.0), 1.0, 1e-6)
	assert_almost_eq(hide.incoming(-1.0), 0.25, 1e-6)
	assert_almost_eq(hide.outgoing_melee(-1.0), 2.5, 1e-6)


func test_factors_never_go_below_zero() -> void:
	var passive := _passive(-1.0, 0.0, -3.0)
	assert_eq(passive.incoming(0.5), 0.0)
	assert_eq(passive.outgoing_melee(0.0), 0.0)
