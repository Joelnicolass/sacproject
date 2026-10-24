class_name DragonArrive
extends CarrierArrive

## The work of Dragonfire's dragon: it burns whatever its box passes through (a share of the spell's amount per second, ignoring shields),
## and when it reaches a body it hurts everything around with the spell's splash, sets it ablaze for a second and flies on to a point
## before it looks for another target. Its ChainHop says who was hit and whom to fly to next (a fixed radius, up to `hits`); after
## `misses_allowed` failed searches, or with the chain full, the dragon shrinks away. It does not fly (SpellCarrier).
## Ref: sacengine updateDragonfirePosition, updateDragonfireTarget (state.d:18801-18856).

## Who was hit and who is next.
@export var chain: ChainHop
## Per second the dragon's box burns, as a share of the spell's amount (SPEL 700 × 0.25 = 175/s).
@export_range(0.0, 1.0, 0.05) var burn_share := 0.25
## What a body hit by the splash burns for afterwards, with no damage of its own.
@export_range(0.0, 5.0, 0.1, "suffix:s") var ablaze_s := 1.0
## Searches that may find nobody before the dragon gives up.
@export_range(0, 5) var misses_allowed := 1
## How far it flies on to look for the next target, as a share of the spell's range.
@export_range(0.0, 1.0, 0.05) var wander_share := 0.5
## The sound of the dragon at a new target and at each hit (a ParticleType with no sprites under data/fx/).
@export var roar: ParticleType

var _spell: SpellType
var _misses := 0
var _rng: RandomNumberGenerator


func begin(carrier: SpellCarrier, wizard: Node3D, spell: SpellType, target: Node3D) -> void:
	_spell = spell
	_misses = 0
	_rng = MatchSeed.rng(["dragonfire", spell.tag, carrier.slot, MatchClock.now()])
	chain.begin_cast(wizard, spell, target, carrier.global_position, 0)


func released(carrier: SpellCarrier, target: Node3D) -> void:
	chain.add_hit(target)
	_roar(carrier)


func along(carrier: SpellCarrier) -> void:
	var half := carrier.damage_range * 0.5
	var area := AABB(carrier.global_position - Vector3(half, half, half), Vector3(carrier.damage_range, carrier.damage_range, carrier.damage_range))
	var per_tick := burn_share * carrier.damage / MatchClock.TICKS_PER_SECOND_F
	for body in BodyNudge.bodies_in(carrier.get_tree(), area):
		if body != carrier.caster():
			Health.of(body).damage_typed(per_tick, Health.DIRECT_SPELL, carrier.slot, false, true)


func arrive(carrier: SpellCarrier) -> void:
	_roar(carrier)
	if carrier.target_body() != null:
		_burst(carrier)
		_wander(carrier)
		return
	var next := chain.pick_next(carrier.global_position, 0)
	if next != null:
		if chain.add_hit(next):
			carrier.retarget(next, BodyNudge.center(next))
		else:
			carrier.finish_flight()
		return
	_misses += 1
	if _misses > misses_allowed:
		carrier.finish_flight()
	else:
		_wander(carrier)


## The splash at the dragon, each body in it set ablaze: dealSplashSpellDamageAt with DamageMod.ignite and setAblaze.
func _burst(carrier: SpellCarrier) -> void:
	var center := carrier.global_position
	var tree := carrier.get_tree()
	SplashDamage.deal(tree, center, carrier.damage, carrier.damage_range, null, carrier.slot, Health.SPLASH_SPELL, Health.IGNITE)
	for body in SplashDamage.bodies_within(tree, center, carrier.damage_range):
		Burning.ignite(body, 0.0, MatchClock.ticks_for(ablaze_s), Health.SPLASH_SPELL, carrier.slot)


## No body to follow: fly on to a point `wander_share` of the range away, over the land.
func _wander(carrier: SpellCarrier) -> void:
	var around := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized()
	var at := carrier.global_position + around * wander_share * _spell.effect_range
	var ground := GroundRay.surface_y(carrier, at, 1, GroundRay.wizard_rids(carrier.get_tree()), INF)
	at.y = (ground if is_finite(ground) else carrier.global_position.y) + wander_share * _spell.effect_range
	carrier.retarget(null, at)


func _roar(carrier: SpellCarrier) -> void:
	if roar != null:
		FxBus.broadcast(roar.fx_name(), carrier.global_position)
