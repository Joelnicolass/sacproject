class_name Frozen
extends Affliction

## A creature turned into ice: the Silverback's Icy Breath and the Freeze spell. A try refuses a
## body protected from crowd control (a frozen or petrified one among them) and one whose mode
## cannot take crowd control (dead…); while its own freeze cooldown runs it freezes only when
## cooldown ≤ uniform(600) (one stream per body, MatchSeed ["freeze", body name]); once the roll
## lets it try, frozen or not, it leaves the cooldown at 600, which counts down every tick. The
## freeze itself refuses a frozen body and one that cannot be immobilized; a stunned body is frozen
## all the same (the type's `cancels`), a thrown one is not. It lasts ceil(60 · 1000 / max health ·
## duration) ticks on a creature and ceil(60 · 0.25 · duration) on a wizard. While it lasts the
## type's flags say the rest: held, not pushed, a flier falls, no regeneration (the body does not
## regenerate while held), refuses crowd control.
## The end: its timer runs out, or a hit breaks the ice (any damage that is not a fall, even 0, and
## a fall that takes more than 0). Then the spell's amount lands as direct spell damage from the
## side that froze it, and 30 shards burst from its box; it goes back to idle with no knock-down.
## Limits: a hit of 0 does not break the ice (Health.hit only reports what was taken; a fall of more
## than 0 does); a broken ice shatters on the next tick. The ice is the translucent block of its
## child IceBlock (`icec`), the same for the spell and for the Yeti's and the Silverback's breath.
## The duration uses plain floats: it may differ by one tick from float32 (a Trogg 1251, not 1250).

const _HEALTH := preload("res://scenes/components/health.gd")

## The longest time a frozen body cannot be frozen again.
@export_range(0.0166, 60.0, 0.0001, "suffix:s") var max_cooldown_s := 10.0
## freeze: a creature lasts creature_k / max health · the SPEL duration (s).
@export var creature_k := 1000.0
## freeze: a wizard lasts wizard_factor · the SPEL duration (s).
@export var wizard_factor := 0.25
## The shards broadcast when it ends (×30), and the socket of the body they leave from.
@export var shards_fx: ParticleType = preload("res://scenes/fx/effects/freeze_shards.tres")
@export var shards_socket: BodyFacts.Socket = BodyFacts.Socket.CENTER

var _cooldown := 0
## Simulation ticks it has lived (counted in _physics_process, so a paused tree does not count).
var _elapsed := 0
var _lifetime := 0
## The physics frame it started on: that tick is not one of its updates (freezes update before the
## Silverback's breath, so a Freeze added this frame first counts down on the next).
var _start_frame := -1
## Server: the freeze this node started is on.
var _running := false
## Server: it is ending by its own timer (the shards and the damage go now, not on the next tick).
var _ending := false
## Server: the tick the ice broke from outside (a hit, a death); it shatters on the next one. -1 =
## nothing pending.
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


## The on-hit freeze (Yeti). Same as try_freeze_with_cooldown, and it logs the cooldown and the one
## roll it drew.
func inflict(spell: SpellType, from_slot: int) -> bool:
	return _try(spell, from_slot, true)


## The Freeze spell: the cast already refused a cc-protected body, and freeze() takes no Yeti
## cooldown.
func lay(spell: SpellType, from_slot: int) -> bool:
	return freeze(spell, from_slot)


func lay_ticks(spell: SpellType) -> int:
	return lifetime_ticks(_body(), spell) if _body() != null else 0


## Server (or solo): tries to freeze with the Yeti cooldown rule. True when it froze.
func try_freeze_with_cooldown(spell: SpellType, from_slot: int) -> bool:
	return _try(spell, from_slot, false)


func _try(spell: SpellType, from_slot: int, log_roll: bool) -> bool:
	var body := _body()
	if body == null or not _can_cc() or _afflictions().cc_protected():
		return false
	if _cooldown > 0:
		# One roll (`cooldown <= 0 or cooldown <= uniform`): with no cooldown there is none.
		var roll := _roll()
		var passes := _cooldown <= roll
		if log_roll:
			print(
				(
					"freeze %s cooldown %d roll %d %s (tick %d)"
					% [
						str(body.name),
						_cooldown,
						roll,
						"congela" if passes else "rechaza",
						MatchClock.now()
					]
				)
			)
		elif not passes:
			print("  freeze: %s on cooldown %d" % [str(body.name), _cooldown])
		if not passes:
			return false
	var done := freeze(spell, from_slot)
	_cooldown = MatchClock.ticks_for(max_cooldown_s)
	set_physics_process(true)
	return done


## Server (or solo): freezes the body. True when it froze.
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
	print(
		(
			"frozen %s for %d (max health %d%s) (frame %d)"
			% [
				str(body.name),
				_lifetime,
				roundi(health.maximum) if health else 0,
				", wizard" if body.is_in_group(WizardBody.GROUP) else "",
				_start_frame
			]
		)
	)
	return true


## The lifetime in physics ticks: ceil(ticks per second · duration), duration = (wizard ? 0.25 :
## 1000 / max health) · the spell's duration.
func lifetime_ticks(body: Node3D, spell: SpellType) -> int:
	var health := _afflictions().health
	return cc_ticks(
		body.is_in_group(WizardBody.GROUP),
		health.maximum if health else 0.0,
		spell.duration_s,
		creature_k,
		wizard_factor
	)


## Can it be frozen? The same answer as Petrified's can-be-immobilized.
static func can_be_frozen(body: Node3D) -> bool:
	return Petrified.can_be_immobilized(body)


## Can it take crowd control: every mode but dead (and the ones this game has no body for).
func _can_cc() -> bool:
	var health := _afflictions().health
	return health == null or not health.is_dead()


## The cooldown roll: one stream per body, made on the first roll (the body's name is set by then).
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


## `if(--timer<=0) unfreeze`, then the shatter in the same update.
func _end_by_time() -> void:
	_running = false
	_ending = true
	_afflictions().mark(self, false)
	_ending = false
	print("%s thaws (frame %d)" % [str(_body().name), MatchClock.now()])
	_shatter()


## A hit that took health breaks the ice.
func _on_hit(amount: float, _from: int, _was_full: bool) -> void:
	if not _running or not is_on() or amount <= 0.0:
		return
	print(
		(
			"%s breaks the ice with %.2f damage (frame %d)"
			% [str(_body().name), amount, MatchClock.now()]
		)
	)
	_afflictions().mark(self, false)


## The thaw: the spell's amount as direct spell damage from the side that froze it, and
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
	print(
		(
			"thaw %s %d spell damage health %d%s (frame %d)"
			% [
				str(body.name),
				roundi(taken),
				roundi(health.current) if health else 0,
				" (inmune)" if immune else "",
				MatchClock.now()
			]
		)
	)
	if shards_fx != null:
		FxBus.broadcast(shards_fx, BodyFacts.point(body, shards_socket))


func _shown(on: bool) -> void:
	if on or not is_multiplayer_authority() or not _running or _ending:
		return
	# Ended from outside while the server still ran it (a hit broke the ice, or the body died): it
	# shatters next tick.
	_running = false
	_thaw_at = MatchClock.now()
	set_physics_process(true)
