class_name Frozen
extends Affliction

## F149 (RFC-030 030k-b): sacengine frozen, the Silverback's Icy Breath (rdba) and the Freeze spell (zerf).
## tryFreezeWithCooldown (state.d:10710-10725) refuses a ccProtected body (a frozen or petrified one among them,
## stats.d:89) and one whose mode cannot take crowd control (canCC, 226-234: dead…); while its own freeze cooldown runs
## it freezes only when cooldown ≤ uniform(600) (one stream per body, MatchSeed ["freeze", body name]); once
## the roll lets it try, frozen or not, it leaves the cooldown at 600, which counts down every tick (13935).
## freeze (10693-10708) refuses a frozen body and one that canBeFrozen = canBeImmobilized says no to (189-198); a
## stunned body is frozen all the same (the type's `cancels`), a thrown one is not (declared: sacengine sets the mode
## stunned over the tumble). It lasts ceil(60 · 1000 / max health · duration) ticks on a creature and
## ceil(60 · 0.25 · duration) on a wizard. While it lasts the type's flags say the rest: held, not pushed, a flier falls
## (startTumbling), no regeneration (the body does not regenerate while held), refuses crowd control.
## The end (updateFreeze, 17579-17614): its timer runs out, or a hit breaks the ice (dealRawDamage, 9034-9037,
## unfreezes on any damage that is not a fall, even 0, and on a fall that takes more than 0). Then dealSpellDamage(zerf): the SPEL amount as direct spell damage from the
## side that froze it, and 30 shards burst from its box; it goes back to idle with no knock-down.
## Deviations (declared): a hit of 0 does not break the ice (Health.hit only reports what was taken; a fall of more than
## 0 does, as in sacengine); a broken ice shatters on the next tick (sacengine: in the same frame when the Freeze effect
## updates after the hit); the ice is a tint of Afflictions.look (frozen.tres look_tint), not the `frez` cube.

const _HEALTH := preload("res://scenes/components/health.gd")
## The duration uses plain floats (RFC-036e): it may differ by one tick from sacengine (a Trogg 1251, not 1250).

## sacengine maxFreezeCooldown = 10·updateFPS (state.d:10709).
@export var max_cooldown_ticks := 600
## freeze: a creature lasts creature_k / max health · the SPEL duration (s).
@export var creature_k := 1000.0
## freeze: a wizard lasts wizard_factor · the SPEL duration (s).
@export var wizard_factor := 0.25
## Its body_height() puts the shards at the middle of the body.
@export var visual: Node3D
## FxBus type of the shards broadcast when it ends (sacengine ParticleType.shard ×30, 17596-17609).
@export var shards_fx := "freeze_shards"

var _cooldown := 0
## Simulation ticks it has lived (counted in _physics_process, so a paused tree does not count).
var _elapsed := 0
var _lifetime := 0
## The physics frame it started on: that tick is not one of its updates (sacengine updates the freezes before the
## Silverback's breath, state.d:26445 and 27399, so a Freeze added this frame first counts down on the next).
var _start_frame := -1
## Server: the freeze this node started is on.
var _running := false
## Server: it is ending by its own timer (the shards and the damage go now, not on the next tick).
var _ending := false
## Server: the tick the ice broke from outside (a hit, a death); it shatters on the next one. -1 = nothing pending.
var _thaw_at := -1
## The side that froze it and the SPEL amount it takes when it thaws.
var _from_slot := 0
var _thaw_damage := 0.0
var _rng: RandomNumberGenerator


func _ready() -> void:
	set_physics_process(false)
	var owner_node := _afflictions()
	if owner_node and owner_node.health and _simulates():
		owner_node.health.hit.connect(_on_hit)


## The Frozen state under `node` is on (a body that is not a creature or has none: false).
static func is_frozen(node: Node) -> bool:
	var frozen := node.get_node_or_null("Afflictions/Frozen") as Frozen if node else null
	return frozen != null and frozen.is_on()


## F158: the on-hit freeze (Yeti zerf). Same as try_freeze_with_cooldown, and it logs the cooldown and the one roll it drew.
func inflict(spell: SpellType, from_slot: int) -> bool:
	return _try(spell, from_slot, true)


## Server (or solo): sacengine tryFreezeWithCooldown(wizard, side, target, spell). True when it froze.
func try_freeze_with_cooldown(spell: SpellType, from_slot: int) -> bool:
	return _try(spell, from_slot, false)


func _try(spell: SpellType, from_slot: int, log_roll: bool) -> bool:
	var body := _body()
	if body == null or not _can_cc() or _afflictions().cc_protected():
		return false
	if _cooldown > 0:
		## One roll, as sacengine's `cooldown<=0||cooldown<=uniform`: with no cooldown there is none.
		var roll := _roll()
		var passes := _cooldown <= roll
		if log_roll:
			print("congelar %s enfriamiento %d tirada %d %s (tick %d)" % [str(body.name), _cooldown, roll, "congela" if passes else "rechaza", MatchClock.now()])
		elif not passes:
			print("  congelar: %s en enfriamiento %d" % [str(body.name), _cooldown])
		if not passes:
			return false
	var done := freeze(spell, from_slot)
	_cooldown = max_cooldown_ticks
	set_physics_process(true)
	return done


## Server (or solo): sacengine freeze(wizard, side, target, spell). True when it froze.
func freeze(spell: SpellType, from_slot: int) -> bool:
	var body := _body()
	if body == null or spell == null or is_on() or not can_be_frozen(body):
		return false
	var lifetime := lifetime_ticks(body, spell)
	if lifetime <= 0 or not _afflictions().admit(self):
		return false
	if _thaw_at >= 0:
		_shatter()
	_elapsed = 0
	_lifetime = lifetime
	_start_frame = MatchClock.now()
	_from_slot = from_slot
	_thaw_damage = float(spell.damage)
	_running = true
	_afflictions().mark(self, true)
	set_physics_process(true)
	var health := _afflictions().health
	print("congelado %s durante %d (vida máx %d%s) (cuadro %d)" % [str(body.name), _lifetime,
		roundi(health.maximum) if health else 0, ", mago" if body.is_in_group(&"wizard") else "", _start_frame])
	return true


## The lifetime in physics ticks: cast(int)ceil(updateFPS · duration), duration = (wizard ? 0.25 : 1000 / max health)
## · SPEL duration (state.d:10701-10702).
func lifetime_ticks(body: Node3D, spell: SpellType) -> int:
	var health := _afflictions().health
	return cc_ticks(body.is_in_group(&"wizard"), health.maximum if health else 0.0, spell.duration, creature_k, wizard_factor)


## canBeFrozen = canBeImmobilized (state.d:189-198, 204): Petrified's.
static func can_be_frozen(body: Node3D) -> bool:
	return Petrified.can_be_immobilized(body)


## canCC (state.d:226-234): every mode but dead (and the ones the port has no body for).
func _can_cc() -> bool:
	var health := _afflictions().health
	return health == null or not health.is_dead()


## state.uniform(maxFreezeCooldown): one stream per body, made on the first roll (the body's name is set by then).
func _roll() -> int:
	if _rng == null:
		_rng = MatchSeed.rng(["freeze", String(_body().name)])
	return int(_rng.randi() % maxi(1, max_cooldown_ticks))


## Server only: on from the first try until the cooldown ran out, the ice ended and the shards flew.
func _physics_process(_delta: float) -> void:
	if _cooldown > 0:
		_cooldown -= 1
	if _thaw_at >= 0 and MatchClock.now() > _thaw_at:
		_shatter()
	if _running and is_on() and MatchClock.now() != _start_frame:
		_elapsed += 1
		if _elapsed >= _lifetime:
			_end_by_time()
	if _cooldown <= 0 and not _running and _thaw_at < 0:
		set_physics_process(false)


## updateFreeze: `if(--timer<=0) unfreeze`, then the shatter in the same update.
func _end_by_time() -> void:
	_running = false
	_ending = true
	_afflictions().mark(self, false)
	_ending = false
	print("%s se descongela (cuadro %d)" % [str(_body().name), MatchClock.now()])
	_shatter()


## dealRawDamage: a hit that took health breaks the ice (sacengine unfreeze, state.d:9013).
func _on_hit(amount: float, _from: int, _was_full: bool) -> void:
	if not _running or not is_on() or amount <= 0.0:
		return
	print("%s rompe el hielo con %.2f de daño (cuadro %d)" % [str(_body().name), amount, MatchClock.now()])
	_afflictions().mark(self, false)


## The thaw: the SPEL amount as direct spell damage from the side that froze it (dealSpellDamage, DamageMod.none), and
## the shards. A dead body takes nothing; the shards fly all the same.
func _shatter() -> void:
	_thaw_at = -1
	var body := _body()
	if body == null:
		return
	var health := _afflictions().health
	var taken := 0.0
	if health and _thaw_damage > 0.0:
		taken = health.damage_typed(_thaw_damage, _HEALTH.DIRECT_SPELL, _from_slot)
	var immune := health != null and taken <= 0.0 and health.resistance(_HEALTH.DIRECT_SPELL) <= 0.0
	print("deshielo %s %d de hechizo vida %d%s (cuadro %d)" % [str(body.name), roundi(taken),
		roundi(health.current) if health else 0, " (inmune)" if immune else "", MatchClock.now()])
	var height := (visual as BodyVisual).body_height() if visual is BodyVisual else 1.0
	FxBus.broadcast(shards_fx, body.global_position + Vector3.UP * height * 0.5)


func _shown(on: bool) -> void:
	if on or not _simulates() or not _running or _ending:
		return
	## Ended from outside while the server still ran it (a hit broke the ice, or the body died): it shatters next tick.
	_running = false
	_thaw_at = MatchClock.now()
	set_physics_process(true)
