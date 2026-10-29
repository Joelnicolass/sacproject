# gdlint: disable=max-public-methods
# max-public-methods: GUT runs every public test_* method; one file per component keeps the Health
# cases together.
extends GutTest
## Health: the damage a body takes on both paths (damage, damage_typed) and what it heals, with
## every piece that changes a hit (resistance, deflector, passive, wards, states, poison, oil,
## devour growth) and the side rule. The pieces are stubs that answer fixed numbers, so the test
## pins how Health puts them together. Only the _wire_* helpers know how a piece reaches Health.


## A minimal body: the two properties Health reads from its parent.
class TestBody:
	extends Node3D
	var type: CreatureType
	var owner_slot := 1


class StubPost:
	extends GuardPost
	var share := 0.25
	var asked: Array[StringName] = []

	func deflect(amount: float, kind: StringName, _from_slot: int) -> float:
		asked.append(kind)
		return NAN if share < 0.0 else amount * share


class StubWards:
	extends Wards
	var splash_factor := 1.0
	var is_immune := false

	func factor(kind: StringName) -> float:
		return splash_factor if kind == Health.SPLASH_SPELL else 1.0

	func immune() -> bool:
		return is_immune


class StubAfflictions:
	extends Afflictions
	var state := 1.0
	var bonus := 0.0
	var blocks := false

	func damage_factor() -> float:
		return state

	func resistance_bonus() -> float:
		return bonus

	func blocks_regeneration() -> bool:
		return blocks


class StubPoisoning:
	extends Poisoning
	var bonus := 0.0
	var regen := 1.0

	func resistance_bonus() -> float:
		return bonus

	func regeneration_factor() -> float:
		return regen


class StubGrowth:
	extends DevourGrowth
	var factor := 1.0

	func resistance_factor() -> float:
		return factor


class StubOil:
	extends Oiled
	var lit := false
	var asked := 0

	func ignite() -> bool:
		asked += 1
		if lit:
			return false
		lit = true
		return true


class StubMatch:
	extends MatchState

	func _ready() -> void:
		add_to_group(GROUP)


var _body: TestBody
var _health: Health


func before_each() -> void:
	_body = TestBody.new()
	var type := CreatureType.new()
	type.direct_spell_resistance = 0.5
	type.splash_spell_resistance = 1.0
	type.melee_resistance = 1.0
	_body.type = type
	_health = Health.new()
	_health.name = "Health"
	_body.add_child(_health)
	add_child_autofree(_body)
	_health.setup(100.0)


# --- Wiring: the only part that knows how a piece reaches Health. ---


func _wire_deflector(post: StubPost) -> void:
	_health.modifiers.append(post)


func _wire_passive(passive: DamagePassive) -> void:
	var hook: PassiveDamage = autofree(PassiveDamage.new())
	hook.passive = passive
	_health.modifiers.append(hook)


func _wire_wards(wards: StubWards) -> void:
	var hook: WardsDamage = autofree(WardsDamage.new())
	hook.wards = wards
	_health.modifiers.append(hook)


func _wire_afflictions(afflictions: StubAfflictions) -> void:
	var hook: AfflictionsDamage = autofree(AfflictionsDamage.new())
	hook.afflictions = afflictions
	_health.modifiers.append(hook)


func _wire_poisoning(poisoning: StubPoisoning) -> void:
	_health.modifiers.append(poisoning)


func _wire_growth(growth: StubGrowth) -> void:
	_health.modifiers.append(growth)


func _wire_oil(oil: StubOil) -> void:
	var hook: AfflictionsDamage = autofree(AfflictionsDamage.new())
	hook.oil = oil
	_health.modifiers.append(hook)


# --- Plain damage and resistance. ---


func test_typed_damage_uses_the_resistance_of_the_kind() -> void:
	assert_almost_eq(_health.damage_typed(20.0, Health.DIRECT_SPELL, 2), 10.0, 1e-5)
	assert_almost_eq(_health.current, 90.0, 1e-5)
	assert_almost_eq(_health.damage_typed(20.0, Health.MELEE, 2), 20.0, 1e-5)
	assert_almost_eq(_health.current, 70.0, 1e-5)


func test_untyped_damage_skips_the_resistance() -> void:
	assert_almost_eq(_health.damage(20.0, 2), 20.0, 1e-5)
	assert_almost_eq(_health.current, 80.0, 1e-5)


func test_zero_resistance_is_immunity() -> void:
	_body.type.direct_spell_resistance = 0.0
	assert_eq(_health.damage_typed(20.0, Health.DIRECT_SPELL, 2), 0.0)
	assert_eq(_health.current, 100.0)


func test_damage_factor_and_kind_factors_scale_typed_hits() -> void:
	_health.damage_factor = 0.5
	_health.kind_factors[Health.DIRECT_SPELL] = 0.5
	# 20 · resistance 0.5 · kind 0.5 · shield 0.5
	assert_almost_eq(_health.damage_typed(20.0, Health.DIRECT_SPELL, 2), 2.5, 1e-5)
	assert_almost_eq(_health.shield_factor(), 0.5, 1e-5)
	# The shield does not touch a pierce_shield hit; the kind factor does.
	assert_almost_eq(_health.damage_typed(20.0, Health.DIRECT_SPELL, 2, false, true), 5.0, 1e-5)


func test_hurt_tells_what_was_taken() -> void:
	watch_signals(_health)
	_health.damage_typed(20.0, Health.DIRECT_SPELL, 2)
	assert_signal_emitted_with_parameters(_health, "hurt", [10.0, Health.DIRECT_SPELL, 2])


# --- Deflector (a building's guardians). ---


func test_deflector_takes_the_whole_hit() -> void:
	var post: StubPost = autofree(StubPost.new())
	_wire_deflector(post)
	assert_almost_eq(_health.damage_typed(40.0, Health.SPLASH_SPELL, 2), 10.0, 1e-5)
	assert_eq(_health.current, 100.0)
	assert_true(_health.deflected_last)
	assert_almost_eq(_health.damage(40.0, 2), 10.0, 1e-5)
	assert_eq(_health.current, 100.0)
	assert_eq(post.asked, [Health.SPLASH_SPELL, Health.MELEE] as Array[StringName])


func test_deflector_that_does_not_deflect_lets_the_body_take_it() -> void:
	var post: StubPost = autofree(StubPost.new())
	post.share = -1.0
	_wire_deflector(post)
	assert_almost_eq(_health.damage_typed(40.0, Health.SPLASH_SPELL, 2), 40.0, 1e-5)
	assert_false(_health.deflected_last)
	assert_almost_eq(_health.current, 60.0, 1e-5)


# --- Passive (Taurock's hide: 0.25 + 0.75 · health before the hit). ---


func test_taurock_hide_scales_by_the_health_before_the_hit() -> void:
	var passive: DamagePassive = autofree(DamagePassive.new())
	passive.incoming_base = 0.25
	passive.incoming_per_health = 0.75
	_wire_passive(passive)
	assert_almost_eq(_health.damage_typed(40.0, Health.MELEE, 2), 40.0, 1e-5)
	# h = 0.6: ×0.7
	assert_almost_eq(_health.damage_typed(40.0, Health.MELEE, 2), 28.0, 1e-5)
	assert_almost_eq(_health.current, 32.0, 1e-5)
	# The untyped path too: h = 0.32, ×0.49
	assert_almost_eq(_health.damage(10.0, 2), 4.9, 1e-5)


# --- Wards (shields and forms). ---


func test_wards_scale_typed_hits_of_their_kind() -> void:
	var wards: StubWards = autofree(StubWards.new())
	wards.splash_factor = 0.5
	_wire_wards(wards)
	assert_almost_eq(_health.damage_typed(20.0, Health.SPLASH_SPELL, 2), 10.0, 1e-5)
	assert_almost_eq(_health.damage_typed(20.0, Health.MELEE, 2), 20.0, 1e-5)
	assert_almost_eq(_health.shield_factor(Health.SPLASH_SPELL), 0.5, 1e-5)
	# A pierce_shield hit ignores them; the untyped path never asks them.
	assert_almost_eq(_health.damage_typed(20.0, Health.SPLASH_SPELL, 2, false, true), 20.0, 1e-5)
	assert_almost_eq(_health.damage(10.0, 2), 10.0, 1e-5)


func test_an_immune_ward_blocks_every_hit() -> void:
	var wards: StubWards = autofree(StubWards.new())
	wards.is_immune = true
	_wire_wards(wards)
	assert_eq(_health.damage_typed(20.0, Health.MELEE, 2, false, true), 0.0)
	assert_eq(_health.damage(20.0, 2), 0.0)
	assert_eq(_health.current, 100.0)


# --- States the body is in (petrified ×0.2). ---


func test_states_scale_both_paths_unless_pierced() -> void:
	var afflictions: StubAfflictions = autofree(StubAfflictions.new())
	afflictions.state = 0.2
	_wire_afflictions(afflictions)
	assert_almost_eq(_health.damage(50.0, 2), 10.0, 1e-5)
	assert_almost_eq(_health.damage_typed(50.0, Health.MELEE, 2), 10.0, 1e-5)
	assert_almost_eq(_health.damage_typed(50.0, Health.MELEE, 2, false, true), 50.0, 1e-5)


# --- Oil (an IGNITE hit on an oiled body ×2, the first time). ---


func test_oil_doubles_the_first_ignite_hit() -> void:
	var oil: StubOil = autofree(StubOil.new())
	_wire_oil(oil)
	assert_almost_eq(_health.damage_typed(10.0, Health.DIRECT_SPELL, 2), 5.0, 1e-5)
	assert_eq(oil.asked, 0)
	assert_almost_eq(
		_health.damage_typed(10.0, Health.DIRECT_SPELL, 2, false, false, Health.IGNITE), 10.0, 1e-5
	)
	assert_almost_eq(
		_health.damage_typed(10.0, Health.DIRECT_SPELL, 2, false, false, Health.IGNITE), 5.0, 1e-5
	)
	assert_eq(oil.asked, 2)


# --- Resistance: devour growth, poison and spell states. ---


func test_devour_growth_scales_the_base_resistance() -> void:
	var growth: StubGrowth = autofree(StubGrowth.new())
	growth.factor = 0.81
	_wire_growth(growth)
	assert_almost_eq(_health.resistance(Health.DIRECT_SPELL), 0.405, 1e-6)
	assert_almost_eq(_health.damage_typed(40.0, Health.DIRECT_SPELL, 2), 16.2, 1e-5)


func test_poison_and_states_add_to_the_grown_resistance() -> void:
	var growth: StubGrowth = autofree(StubGrowth.new())
	growth.factor = 0.81
	var poisoning: StubPoisoning = autofree(StubPoisoning.new())
	poisoning.bonus = 0.1
	var afflictions: StubAfflictions = autofree(StubAfflictions.new())
	afflictions.bonus = 0.2
	_wire_growth(growth)
	_wire_poisoning(poisoning)
	_wire_afflictions(afflictions)
	assert_almost_eq(_health.resistance(Health.DIRECT_SPELL), 0.705, 1e-6)
	assert_almost_eq(_health.damage_typed(20.0, Health.DIRECT_SPELL, 2), 14.1, 1e-5)


func test_resistance_never_goes_below_zero() -> void:
	var poisoning: StubPoisoning = autofree(StubPoisoning.new())
	poisoning.bonus = -1.0
	_wire_poisoning(poisoning)
	assert_eq(_health.resistance(Health.DIRECT_SPELL), 0.0)
	assert_eq(_health.damage_typed(20.0, Health.DIRECT_SPELL, 2), 0.0)


# --- Regeneration. ---


func test_regeneration_takes_the_poison_factor_and_the_block() -> void:
	_health.current = 50.0
	var poisoning: StubPoisoning = autofree(StubPoisoning.new())
	poisoning.regen = 0.5
	var afflictions: StubAfflictions = autofree(StubAfflictions.new())
	_wire_poisoning(poisoning)
	_wire_afflictions(afflictions)
	_health.regenerate(10.0)
	assert_almost_eq(_health.current, 55.0, 1e-5)
	poisoning.regen = -2.0
	_health.regenerate(10.0)
	assert_almost_eq(_health.current, 55.0, 1e-5)
	poisoning.regen = 1.0
	afflictions.blocks = true
	_health.regenerate(10.0)
	assert_almost_eq(_health.current, 55.0, 1e-5)


# --- A lethal hit. ---


func test_a_lethal_hit_takes_what_is_left_and_kills() -> void:
	_health.current = 30.0
	watch_signals(_health)
	assert_almost_eq(_health.damage_typed(100.0, Health.MELEE, 3), 30.0, 1e-5)
	assert_true(_health.is_dead())
	assert_signal_emitted_with_parameters(_health, "died", [3])
	assert_eq(_health.damage_typed(100.0, Health.MELEE, 3), 0.0)
	assert_eq(_health.damage(100.0, 3), 0.0)


func test_kill_ignores_every_modifier() -> void:
	var wards: StubWards = autofree(StubWards.new())
	wards.splash_factor = 0.0
	_wire_wards(wards)
	_health.kill(2)
	assert_true(_health.is_dead())


# --- Friendly fire (match rule, not a modifier). ---


func test_friendly_fire_off_spares_allies() -> void:
	var state: StubMatch = StubMatch.new()
	state.friendly_fire = false
	add_child_autofree(state)
	assert_eq(_health.damage_typed(20.0, Health.MELEE, 1), 0.0)
	assert_eq(_health.damage(20.0, 1), 0.0)
	assert_eq(_health.current, 100.0)
	# Another side and no side are not allies.
	assert_almost_eq(_health.damage_typed(20.0, Health.MELEE, 2), 20.0, 1e-5)
	assert_almost_eq(_health.damage(20.0, 0), 20.0, 1e-5)


func test_friendly_fire_on_scales_ally_hits() -> void:
	var state: StubMatch = StubMatch.new()
	state.friendly_fire = true
	state.ally_damage_factor = 0.5
	add_child_autofree(state)
	assert_almost_eq(_health.damage_typed(20.0, Health.MELEE, 1), 10.0, 1e-5)
	assert_almost_eq(_health.damage_typed(20.0, Health.MELEE, 1, true), 20.0, 1e-5)
	assert_almost_eq(_health.damage(20.0, 1), 10.0, 1e-5)


func test_with_no_match_state_ally_typed_hits_do_nothing() -> void:
	assert_eq(_health.damage_typed(20.0, Health.MELEE, 1), 0.0)
	assert_almost_eq(_health.damage(20.0, 1), 20.0, 1e-5)
