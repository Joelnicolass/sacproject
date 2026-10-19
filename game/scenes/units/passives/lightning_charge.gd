class_name LightningCharge
extends Node

## F130 (RFC-030 030s-a): the Storm Giant's Lightning Charge (gcil, its passiveOnDamage). The one owner of how charged a body
## is: the frames it still holds, the ramp of its discharges, what it multiplies (pace, blow, accuracy) and the bolts it throws.
## A child of unit.tscn; take it out and no body is charged. Not a DamagePassiveType: the passive has side effects (gcil is not of
## the shape of korq / ahtf, damage_passive_type.gd), so DamagePassive only asks it.
##
## Charging (dealRawDamage, state.d:9017-9022): a hit with DamageMod.lightning charges `int(f · damage)` frames (f = 4 when the
## attacker is an ally, 2 otherwise; the damage is the one already scaled by side, resistance and shields) and the body takes a
## quarter of it. absorb() does both; add() is the bare `lightningCharge` (13131-13136): a new charge (it was off) starts its
## ramp at 0.
## updateLightningCharge (25342-25386), once per tick of a charged body, in this order:
##   frames −= 1; at 0 the charge is over. ramp += 1/60 (cap 1).
##   frames ≥ the SPEL's amount (250) and uniform < ramp / 60: a discharge. It picks with uniform(n + 4) among the n bodies whose
##   center is within the SPEL's range (30 m; creatures and wizards, not dead; the body itself among them) and the land (a random
##   2D direction, 5 m to the range, at the land's height). A pick over n, or a body that is no longer valid, is the land; the body
##   itself is nothing (no discharge, no cost). Otherwise frames −= amount >> 1 (125), ramp = 0 and a LightningStrike `gcil`
##   (the SPEL's 250) flies from its center to the pick, without bouncing.
##   Sparks over the body: probability 1 − e^(−2/60) per tick (presentation only).
## While charged: pace ×1.5 (movementSpeed, stats.d:122), blow ×1.5 (attackDamageFactor, state.d:8885) and accuracy ×1.5
## (dealMeleeDamage, 9237). The pace goes to PaceFactors under its own source; the other two are asked of melee_factor().
## The simulation is MatchSeed's stream ["charge", body, tick] (drawn only on a tick that can discharge); the sparks have a stream
## of their own, so they never move it. `shown` is replicated (the unit's MultiplayerSynchronizer, "LightningCharge:shown").
## Divergences (declared): the candidates go in the order of the groups (wizards, then units), not sacengine's proximity order; a
## body that dies loses its charge at once; the sparks are a reserve look.


## The PaceFactors source of the charge.
const PACE_SOURCE := &"lightning_charge"

## The body that is charged (its center, its name, its slot). Empty = the parent.
@export var body: Node3D
## Who writes speed_factor. Empty = the charge does not change the pace.
@export var pace: PaceFactors
## The discharge's bolt (lightning_strike.tscn).
@export var bolt_scene: PackedScene
## SpellTag of the passive (the SPEL gives the amount 250, the range 30 and the bolt's damage 250).
@export var tag := "gcil"
## Frames charged per point of damage taken from an ally / from anyone else.
@export var ally_factor := 4.0
@export var foe_factor := 2.0
## What is left of the hit that charges (the body takes this much of it).
@export var absorbed_factor := 0.25
## Multiplies the body's pace while charged.
@export var pace_boost := 1.5
## Multiplies the body's blows and its melee accuracy while charged.
@export var melee_boost := 1.5
## uniform(n + extra_picks): the picks past the bodies are the land.
@export var extra_picks := 4
## The nearest the land strike falls from the body.
@export var ground_min_m := 5.0
@export_group("Look")
## FxBus burst over the body while charged (reserve look).
@export var spark_fx := "styx_spark"
## sacengine LightningCharge.sparkRate (per second).
@export var spark_rate := 2.0

## Replicated. Charged. The setter is the one place that turns the node's tick on and off.
@export var shown := false:
	set(value):
		shown = value
		if is_node_ready():
			_wake()

## Server: the frames the body still holds. Charged = more than 0.
var frames := 0
var ramp := 0.0

var _look_rng := RandomNumberGenerator.new()
var _last_walk := Vector3.INF


## The LightningCharge of `node`, or null.
static func of(node: Node) -> LightningCharge:
	return (node.get_node_or_null("LightningCharge") as LightningCharge) if node else null


func _ready() -> void:
	if body == null:
		body = get_parent() as Node3D
	MatchSeed.seed_rng(_look_rng, ["charge_look", _who()])
	_wake()


## Server (or solo). `amount` frames more; a body that was not charged starts a new charge (ramp 0).
func add(amount: int) -> void:
	if not _has_authority() or amount <= 0:
		return
	if frames <= 0:
		ramp = 0.0
	frames += amount
	_say("carga %s +%d cuadros total %d (tick %d)" % [_who(), amount, frames, MatchClock.now()])
	_refresh()


## A hit with DamageMod.lightning that reached the body: `damage` is what is left after side, resistance and shields, `ally` that
## the attacker is of the body's side. Charges f · damage frames and returns what the body takes of the hit.
func absorb(damage: float, ally: bool) -> float:
	add(int((ally_factor if ally else foe_factor) * damage))
	return absorbed_factor


func is_on() -> bool:
	return frames > 0 if _has_authority() else shown


## ×melee_boost while charged: the blow (attackDamageFactor) and the accuracy (dealMeleeDamage). 1 otherwise.
func melee_factor() -> float:
	return melee_boost if is_on() else 1.0


func _physics_process(_delta: float) -> void:
	if _has_authority():
		_simulate()
		_trace_walk()
	if shown:
		_spark()


## updateLightningCharge.
func _simulate() -> void:
	if frames <= 0:
		return
	var health: Health = body.get_node_or_null("Health") as Health if body != null else null
	if health != null and health.is_dead():
		frames = 0
		_say("carga %s fin por muerte (tick %d)" % [_who(), MatchClock.now()])
		_refresh()
		return
	frames -= 1
	if frames <= 0:
		frames = 0
		_say("carga %s fin (tick %d)" % [_who(), MatchClock.now()])
		_refresh()
		return
	ramp = minf(ramp + 1.0 / MatchClock.TICKS_PER_SECOND_F, 1.0)
	var spell := GameData.ability(tag)
	if spell == null or frames < spell.damage:
		return
	var rng := MatchSeed.rng(["charge", _who(), MatchClock.now()])
	if rng.randf() < ramp / MatchClock.TICKS_PER_SECOND_F:
		_discharge(rng, spell)


## The pick and the bolt.
func _discharge(rng: RandomNumberGenerator, spell: AbilityType) -> void:
	var center := BodyNudge.center(body)
	var candidates := _candidates(center, spell.cast_range)
	var pick := rng.randi_range(0, candidates.size() + extra_picks - 1)
	var target: Node3D = null
	if pick < candidates.size() and LightningStrike.is_valid_target(candidates[pick]):
		target = candidates[pick]
	if target == body:
		_say("carga %s elige su propio cuerpo: nada (candidatos %d, tirada %d, tick %d)" % [_who(), candidates.size(), pick, MatchClock.now()])
		return
	var ground := Vector3.ZERO
	if target == null:
		var flat := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		var distance := rng.randf_range(ground_min_m, spell.cast_range)
		ground = center + Vector3(flat.x * distance, 0.0, flat.y * distance)
		ground.y = BodyNudge.ground_y(body, ground)
	var before := frames
	frames -= int(spell.damage) >> 1
	ramp = 0.0
	LightningStrike.launch(bolt_scene, self, body, center, target, ground, float(spell.damage), tag, false)
	var where := "suelo %s" % _v(ground) if target == null else "%s a %.4f m" % [target.name, center.distance_to(BodyNudge.center(target))]
	_say("carga %s descarga a %s (candidatos %d, tirada %d) cuadros %d->%d (tick %d)" % [
		_who(), where, candidates.size(), pick, before, frames, MatchClock.now()])


## The bodies within `radius` of `center` (center to center) that a discharge can pick: creatures and wizards that are not
## dead, the charged body itself among them (collect, 25353-25357). Group order.
func _candidates(center: Vector3, radius: float) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var seen := {}
	for group in [&"wizard", &"unit"]:
		for node in get_tree().get_nodes_in_group(group):
			var other := node as Node3D
			if other == null or seen.has(other) or not Attackable.is_body(other):
				continue
			seen[other] = true
			var health := other.get_node_or_null("Health") as Health
			if health == null or health.is_dead():
				continue
			if center.distance_to(BodyNudge.center(other)) <= radius:
				found.append(other)
	return found


## Derives the pace, `shown` and the node's tick from the frames. Idempotent. Server (or solo).
func _refresh() -> void:
	var on := frames > 0
	if pace != null:
		if on:
			pace.set_factor(PACE_SOURCE, pace_boost)
		else:
			pace.clear(PACE_SOURCE)
	shown = on
	if is_node_ready():
		_wake()


## The tick runs while charged, and with the bench log on (a carrier of the passive traces its walk: its type is set after
## _ready, so the check is per tick).
func _wake() -> void:
	set_physics_process(shown or frames > 0 or DebugLog.on(&"charge"))


func _carries() -> bool:
	var type: Variant = body.get("type") if body != null and "type" in body else null
	return type is CreatureType and (type as CreatureType).passive_on_damage == tag


## Bench only: `marcha body ×pace (x, y, z)` on every tick the carrier moved, for the replica to measure the step.
func _trace_walk() -> void:
	if not DebugLog.on(&"charge") or body == null or not _carries():
		return
	var at := body.global_position
	if at == _last_walk:
		return
	_last_walk = at
	var factor := float(body.get("speed_factor")) if "speed_factor" in body else 1.0
	print("marcha %s ×%.4f (%.4f, %.4f, %.4f) (tick %d)" % [_who(), factor, at.x, at.y, at.z, MatchClock.now()])


## sparkAnimation!48 over the body's box at sparkProb per tick; the stream is the look's, not the simulation's.
func _spark() -> void:
	if body == null or spark_fx.is_empty():
		return
	var chance := 1.0 - exp(-spark_rate / MatchClock.TICKS_PER_SECOND_F)
	if _look_rng.randf() > chance:
		return
	var box := BodyNudge.box(body)
	var at := box.position + Vector3(_look_rng.randf(), _look_rng.randf(), _look_rng.randf()) * box.size
	FxBus.play(spark_fx, at)


func _who() -> String:
	return str(body.name) if body != null else "?"


func _say(text: String) -> void:
	if DebugLog.on(&"charge"):
		print(text)


static func _v(v: Vector3) -> String:
	return "(%.4f, %.4f, %.4f)" % [v.x, v.y, v.z]


func _has_authority() -> bool:
	return not MpKit.is_networked() or MpKit.is_server()
