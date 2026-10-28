class_name MeleeWeapon
extends Weapon

## A blow with the body: one swing at a time, timed by the creature's attack clip. It starts when
## the target touches the melee box (scaled by `start_factor`) and the blow lands only if the target
## still touches the unscaled box on the clip's blow frame.
## Not: choosing who to hit (the chase state) nor what a blow adds afterwards (the creature's
## MeleeOnHit passives). Server (or solo) only.

## The share of the melee box a target must touch to start a swing.
@export var start_factor := 0.8
## How far ahead of the body the box sits, in reaches.
@export var forward_factor := 1.3
@export var height_factor := 1.5
## With the target inside the box the body keeps walking in until its centre is this share of the
## box's forward offset from the target's near edge.
@export var close_in_factor := 0.8
## A target whose centre is this far below ours is hit with the downward swing (attack3).
@export var downward_threshold := 0.25
## Melee damage is scaled by this times the target's melee resistance.
@export var melee_resistance_scale := 0.4

## The clip of each swing, by `MeleeRules.SWING_ROLES` index.
const CLIP_ROLES: PackedStringArray = ["attack", "attack2", "attack3"]

var type: CreatureType
## Read from the body scene (BodyFacts) every time the body changes model.
var reach := 0.35
var height := 1.8
var rng: RandomNumberGenerator
var swing := MeleeSwing.new()

var _facts := ClipFacts.of(null)
var _target: Node3D


func setup(unit: UnitBody, creature: CreatureType, stream: RandomNumberGenerator) -> void:
	super.setup(unit, creature, stream)
	type = creature
	_facts = creature.clip_facts() if creature != null else ClipFacts.of(null)
	reach = maxf(unit.mount.facts.reach_m, 0.1)
	height = maxf(unit.mount.facts.height_m, 0.6)
	# Never the global stream: a body without one gets one derived from the match seed and its name.
	rng = stream if stream else MatchSeed.rng(["melee", String(unit.name)])


## The creature's DamagePassive (the Firefist's fury reads the body's health); null = x1.
func passive() -> DamagePassive:
	return weapons.passive if weapons != null else null


## The clip of the swing in course (or the last one): 0 attack, 1 attack2, 2 attack3.
func swing_index() -> int:
	return swing.index


func cancel() -> void:
	swing.active = false
	_target = null


func can_start(target: Node3D) -> bool:
	return type != null and type.melee_strength > 0 and in_reach(target, start_factor)


func in_reach(target: Node3D, factor: float) -> bool:
	return MeleeReach.in_reach(self, target, factor)


func close_in(target: Node3D, pace: float, delta: float) -> Vector3:
	return MeleeReach.close_in(self, target, pace, delta)


func roll_damage(target: Node3D) -> Dictionary:
	return MeleeRules.roll(self, target)


func wants(target: Node3D) -> bool:
	return can_start(target)


func aim(target: Node3D) -> Step:
	start(target)
	return Step.FIRE


func announce() -> void:
	weapons.swings += 1


func busy_state() -> StringName:
	return &"Attack"


## The swing that was picked: attack, attack2 or attack3 when the model has them, else attack.
func clip_role() -> String:
	if swing.index > 0 and body.has_clip(CLIP_ROLES[swing.index]):
		return CLIP_ROLES[swing.index]
	return "attack"


## Starts the swing the target calls for.
func start(target: Node3D) -> void:
	_target = target
	swing.begin(_facts, MeleeSwing.pick(_facts, body, target, height, downward_threshold, rng))


func advance(delta: float) -> bool:
	if not swing.active:
		return false
	# Each layer of Slime makes the swing take 5x as long.
	swing.elapsed += delta / Afflictions.stat_factor_of(body, Afflictions.Stat.ATTACK_TIME)
	while swing.blow_due():
		swing.next_tick += 1
		_land()
	if swing.ended():
		swing.active = false
		return false
	return true


func _land() -> void:
	var target := _target
	if target == null or not is_instance_valid(target) or not in_reach(target, 1.0):
		return
	var health := target.get_node_or_null("Health") as Health
	if health == null or health.is_dead():
		return
	var was_frozen := Frozen.is_frozen(target)
	var result := roll_damage(target)
	# Health scales melee by Rockform and the other shields too.
	var factor := health.shield_factor() * MeleeRules.attack_factor(self)
	var amount := float(result["amount"]) * factor
	if DebugLog.on(&"melee"):
		print(
			(
				# gdlint: ignore=max-line-length
				"blow %s → %s accuracy %.1f evasion %.1f facing %.6f slope %.6f p %.6f roll %.6f strength %d scale %.4f resistance %.4f factor %.4f amount %.4f (tick %d)"
				% [
					body.name,
					target.name,
					result["accuracy"],
					result["evasion"],
					result["facing"],
					result["pending"],
					result["chance"],
					result["roll"],
					type.melee_strength,
					melee_resistance_scale,
					result["resistance"],
					factor,
					amount,
					MatchClock.now()
				]
			)
		)
	if amount > 0.0:
		LifeDrain.feed(body, target, health.damage(amount, body.owner_slot))
		struck.emit(target, amount, float(result["chance"]), float(result["roll"]))
	connected.emit(target, was_frozen)
