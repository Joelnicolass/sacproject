class_name Oiled
extends Affliction

## F155 (RFC-030 030r-b): a body smeared with the Pyrodactyl's Viscous oil (kcfa), sacengine Oil (state.d:25653-25676) and
## `creatureStats.effects.oiled / oilStatus`. A child of Afflictions with its own bit (bit 7) that COEXISTS with the other
## states (AfflictionType.coexists: it neither refuses nor is refused by them), so a stunned, frozen or burning body can be
## oiled and the oil never cancels the others.
##
## Life (updateOil): `start()` is the explosion of the oil shot (OilImpact). One update per tick from the next one (frame 1, 2…,
## before the bodies move: process priority −1, like the other effects):
##   - while frame <= `ticks` (900 = the SPEL's duration · 60) the oil holds: a creature that is not a wizard has its order queue
##     cleared every tick (`orders` socket; a wizard has none) and, as the type `holds`, the AI does not run (13647-13649);
##   - frame `ticks` + 1 the oil is gone («limpio»): the body can be oiled again (+901 ticks after the shot);
##   - a body that can no longer be oiled (dying, dead, dissolving: sacengine canBeOiled = canBePoisoned) loses it with no blast.
## Ignite (dealRawDamage, 9028-9031): Health calls `ignite()` when a hit carries IGNITE and the body is oiled; that hit takes ×2
## (Health) and the oil blasts on the NEXT update (igniteOil, 25639-25651): dealSplashRangedDamageAt of the SPEL's amount
## (500) within its damage_range (5 m) of the body's center, with IGNITE, in the name of whoever threw the oil; each body in the
## radius also gets a 60-tick fire of no damage (setAblaze(target, 60, false, 0), only the look), and the oil is removed.
## The oil of the body that blasts is already «ignited», so its own blast is not doubled; a neighbour that is oiled is (and so it
## blasts one update later: the chain). An ally of whoever threw it takes 0 with no friendly fire and does not ignite (dealDamage
## returns before dealRawDamage, 8961): Health decides, `ignite()` is never called for it.
##
## The shown bit is the oil for every peer; the splash look is the shot's (ShotLook.impact_fx). Server (or solo) only decides.
## Divergence (declared): in sacengine two oiled bodies blast in the order of their Oil effects (creation order); here, in the order of
## the scene tree. A neighbour lit by a blast may blast on the same tick or on the next one.


## unit_orders.gd has no class_name (other scripts preload it).
const _ORDERS := preload("res://scenes/units/unit_orders.gd")

## The creature's order queue (UnitOrders), cleared every tick the oil holds. Empty on a wizard (sacengine `!isWizard`).
@export var orders: Node
## FxBus type puffed on each body the blast lights, and how long that fire of no damage lasts (setAblaze(…, updateFPS)).
@export var fire_fx := "fire"
@export_range(0.0, 10.0, 0.0001, "suffix:s") var fire_s := 1.0
## FxBus type of the fireball that blasts at the body's center (sacengine animateFireballExplosion, 25650; the explosion's
## particles of the original are the `fire` atlas here, in MIX like the Bombard's).
@export var blast_fx := "oil_blast"

var _frame := 0
var _ticks := 0
var _slot := 0
var _damage := 0.0
var _radius := 0.0
var _ignited := false
var _running := false


static func of(body: Node) -> Oiled:
	return (body.get_node_or_null("Afflictions/Oiled") as Oiled) if body else null


func _ready() -> void:
	set_physics_process(false)
	## sacengine updates its effects before its creatures: the oil clears the orders before the body acts.
	process_physics_priority = -1


## Server (or solo): sacengine oilExplosion's callback + Oil. `ticks`: how long it lasts (ability.duration_s · 60); `slot`: the
## side of whoever threw it (the blast's attacker); `ability`: the SPEL (amount and damage_range of the blast). True when the body
## got smeared; false if it already is, cannot be, or this is a client.
func start(ticks: int, slot: int, ability: AbilityType) -> bool:
	var body := _body()
	if not _simulates() or body == null or ticks <= 0 or is_on() or not can_be_oiled():
		return false
	if not _afflictions().admit(self):
		return false
	_ticks = ticks
	_slot = slot
	_damage = float(ability.damage) if ability != null else 0.0
	_radius = ability.damage_range_m if ability != null else 0.0
	_frame = 0
	_ignited = false
	_running = true
	_afflictions().mark(self, true)
	set_physics_process(true)
	_say("untado hasta %d" % (MatchClock.now() + ticks + 1))
	return true


## sacengine canBeOiled = canBePoisoned(mode): a live body that is not dying, being summoned or taken.
func can_be_oiled() -> bool:
	var poisoning := Poisoning.of(_body())
	return poisoning != null and poisoning.can_be_poisoned()


## Server (or solo): a hit that carries IGNITE reached an oiled body (Health, sacengine igniteOil 25632-25634). True the first
## time only: the oil is lit, the hit counts ×2 and the blast comes on the next update.
func ignite() -> bool:
	if not _running or not is_on() or _ignited:
		return false
	_ignited = true
	_say("arde")
	return true


func _physics_process(_delta: float) -> void:
	if not _running or not _simulates():
		return
	var body := _body()
	if body == null or not is_on():
		_finish("cortado")
		return
	_frame += 1
	if _frame > _ticks:
		_finish("vencido")
		return
	if orders != null and is_instance_valid(orders):
		(orders as _ORDERS).clear()
	if DebugLog.on(&"oil"):
		_say("paso (%.3f, %.3f, %.3f)" % [body.global_position.x, body.global_position.y, body.global_position.z])
	if not can_be_oiled():
		_finish("no se puede untar")
		return
	if _ignited:
		_blast(body)


func _shown(on: bool) -> void:
	if not on and _running and _simulates():
		_finish("cortado")


## igniteOil: 500 of ranged splash with IGNITE from the body's center, a short fire of no damage on each body in the radius
## (the callback runs before the damage, 9086), then the oil is gone.
func _blast(body: Node3D) -> void:
	var center := BodyNudge.center(body)
	_say("explota en (%.3f, %.3f, %.3f) radio %.1f" % [center.x, center.y, center.z, _radius])
	FxBus.broadcast(blast_fx, center)
	var tree := get_tree()
	for target in SplashDamage.bodies_within(tree, center, _radius):
		Burning.ignite(target, 0.0, MatchClock.ticks_for(fire_s), Health.SPLASH_RANGED, _slot, 0.0, false, fire_fx)
	SplashDamage.deal(tree, center, _damage, _radius, null, _slot, Health.SPLASH_RANGED, Health.IGNITE)
	_say("explosión fin")
	_finish("explotó")


## The one way out. Idempotent: the bit off, one line in the log.
func _finish(reason: String) -> void:
	if not _running:
		return
	_running = false
	set_physics_process(false)
	if is_on():
		_afflictions().mark(self, false)
	_say("limpio (%s)" % reason)


func _say(text: String) -> void:
	if DebugLog.on(&"oil"):
		var body := _body()
		print("aceite %s %s (tick %d)" % [AbilityEffect.who(body), text, MatchClock.now()])
