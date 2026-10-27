class_name Frozen
extends Affliction

## A creature turned into ice: the Silverback's Icy Breath and the Freeze spell.
## A try refuses a ccProtected body (a frozen or petrified one among them)
## and one whose mode cannot take crowd control (dead…); while its own freeze cooldown runs
## it freezes only when cooldown ≤ uniform(600) (one stream per body, MatchSeed ["freeze", body name]); once
## the roll lets it try, frozen or not, it leaves the cooldown at 600, which counts down every tick.
## The freeze itself refuses a frozen body and one that cannot be immobilized; a
## stunned body is frozen all the same (the type's `cancels`), a thrown one is not (declared: the original sets the mode
## stunned over the tumble). It lasts ceil(60 · 1000 / max health · duration) ticks on a creature and
## ceil(60 · 0.25 · duration) on a wizard. While it lasts the type's flags say the rest: held, not pushed, a flier falls,
## no regeneration (the body does not regenerate while held), refuses crowd control.
## The end: its timer runs out, or a hit breaks the ice (any damage that is not a fall, even 0, and a fall that takes
## more than 0). Then the spell's amount lands as direct spell damage from the
## side that froze it, and 30 shards burst from its box; it goes back to idle with no knock-down.
## Deviations (declared): a hit of 0 does not break the ice (Health.hit only reports what was taken; a fall of more than
## 0 does, as in the original); a broken ice shatters on the next tick (the original: in the same frame when the Freeze effect
## updates after the hit). The ice is the translucent block of its child IceBlock (`icec`; the exe loads it for the spell), the
## same for the spell and for the Yeti's and the Silverback's breath.
## Ref: F149 (RFC-030 030k-b); sacengine frozen (rdba, zerf), tryFreezeWithCooldown state.d:10710-10725, stats.d:89, canCC 226-234, 13935, freeze 10693-10708, canBeFrozen 189-198, startTumbling, updateFreeze 17579-17614, dealRawDamage 9034-9037, dealSpellDamage(zerf).

const _HEALTH := preload("res://scenes/components/health.gd")
## The duration uses plain floats: it may differ by one tick from the original (a Trogg 1251, not 1250).
## Ref: RFC-036e.

## The longest time a frozen body cannot be frozen again.
## Ref: sacengine maxFreezeCooldown = 10·updateFPS (state.d:10709).
@export_range(0.0166, 60.0, 0.0001, "suffix:s") var max_cooldown_s := 10.0
## freeze: a creature lasts creature_k / max health · the SPEL duration (s).
@export var creature_k := 1000.0
## freeze: a wizard lasts wizard_factor · the SPEL duration (s).
@export var wizard_factor := 0.25
## The shards broadcast when it ends (×30), and the socket of the body they leave from.
## Ref: sacengine ParticleType.shard, 17596-17609.
@export var shards_fx: ParticleType = preload("res://data/fx/freeze_shards.tres")
@export var shards_socket: BodyFacts.Socket = BodyFacts.Socket.CENTER

var _cooldown := 0
## Simulation ticks it has lived (counted in _physics_process, so a paused tree does not count).
var _elapsed := 0
var _lifetime := 0
## The physics frame it started on: that tick is not one of its updates (the original updates the freezes before the
## Silverback's breath, so a Freeze added this frame first counts down on the next).
## Ref: sacengine state.d:26445 and 27399.
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
	if owner_node and owner_node.health and is_multiplayer_authority():
		owner_node.health.hit.connect(_on_hit)


## The Frozen state of `node`, or null (a body that is not a creature has none).
static func of(node: Node) -> Frozen:
	return node.get_node_or_null("Afflictions/Frozen") as Frozen if node else null


## The Frozen state under `node` is on (a body that is not a creature or has none: false).
static func is_frozen(node: Node) -> bool:
	var frozen := of(node)
	return frozen != null and frozen.is_on()


## The on-hit freeze (Yeti). Same as try_freeze_with_cooldown, and it logs the cooldown and the one roll it drew.
## Ref: F158; zerf.
func inflict(spell: SpellType, from_slot: int) -> bool:
	return _try(spell, from_slot, true)


## The Freeze spell: the cast already refused a ccProtected body, and freeze() takes no Yeti cooldown.
## Ref: sacengine castFreeze (state.d:10687-10708).
func lay(spell: SpellType, from_slot: int) -> bool:
	return freeze(spell, from_slot)


func lay_ticks(spell: SpellType) -> int:
	return lifetime_ticks(_body(), spell) if _body() != null else 0


## Server (or solo): tries to freeze with the Yeti cooldown rule. True when it froze.
## Ref: sacengine tryFreezeWithCooldown(wizard, side, target, spell).
func try_freeze_with_cooldown(spell: SpellType, from_slot: int) -> bool:
	return _try(spell, from_slot, false)


func _try(spell: SpellType, from_slot: int, log_roll: bool) -> bool:
	var body := _body()
	if body == null or not _can_cc() or _afflictions().cc_protected():
		return false
	if _cooldown > 0:
		## One roll, as the original's `cooldown<=0||cooldown<=uniform`: with no cooldown there is none.
		var roll := _roll()
		var passes := _cooldown <= roll
		if log_roll:
			print("congelar %s enfriamiento %d tirada %d %s (tick %d)" % [str(body.name), _cooldown, roll, "congela" if passes else "rechaza", MatchClock.now()])
		elif not passes:
			print("  congelar: %s en enfriamiento %d" % [str(body.name), _cooldown])
		if not passes:
			return false
	var done := freeze(spell, from_slot)
	_cooldown = MatchClock.ticks_for(max_cooldown_s)
	set_physics_process(true)
	return done


## Server (or solo): freezes the body. True when it froze.
## Ref: sacengine freeze(wizard, side, target, spell).
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


## The lifetime in physics ticks: ceil(ticks per second · duration), duration = (wizard ? 0.25 : 1000 / max health)
## · the spell's duration.
## Ref: state.d:10701-10702.
func lifetime_ticks(body: Node3D, spell: SpellType) -> int:
	var health := _afflictions().health
	return cc_ticks(body.is_in_group(&"wizard"), health.maximum if health else 0.0, spell.duration_s, creature_k, wizard_factor)


## Can it be frozen? The same answer as Petrified's can-be-immobilized.
## Ref: canBeFrozen = canBeImmobilized (state.d:189-198, 204).
static func can_be_frozen(body: Node3D) -> bool:
	return Petrified.can_be_immobilized(body)


## Can it take crowd control: every mode but dead (and the ones the port has no body for).
## Ref: canCC (state.d:226-234).
func _can_cc() -> bool:
	var health := _afflictions().health
	return health == null or not health.is_dead()


## The cooldown roll: one stream per body, made on the first roll (the body's name is set by then).
## Ref: state.uniform(maxFreezeCooldown).
func _roll() -> int:
	if _rng == null:
		_rng = MatchSeed.rng(["freeze", String(_body().name)])
	return int(_rng.randi() % maxi(1, MatchClock.ticks_for(max_cooldown_s)))


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


## A hit that took health breaks the ice.
## Ref: dealRawDamage; sacengine unfreeze, state.d:9013.
func _on_hit(amount: float, _from: int, _was_full: bool) -> void:
	if not _running or not is_on() or amount <= 0.0:
		return
	print("%s rompe el hielo con %.2f de daño (cuadro %d)" % [str(_body().name), amount, MatchClock.now()])
	_afflictions().mark(self, false)


## The thaw: the spell's amount as direct spell damage from the side that froze it, and
## the shards. A dead body takes nothing; the shards fly all the same.
## Ref: dealSpellDamage, DamageMod.none.
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
	if shards_fx != null:
		FxBus.broadcast(shards_fx, BodyFacts.point(body, shards_socket))


func _shown(on: bool) -> void:
	if on or not is_multiplayer_authority() or not _running or _ending:
		return
	## Ended from outside while the server still ran it (a hit broke the ice, or the body died): it shatters next tick.
	_running = false
	_thaw_at = MatchClock.now()
	set_physics_process(true)
