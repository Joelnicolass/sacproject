class_name Health
extends Node

## Hit points of a body. The server (or solo) changes them; clients get `current`
## and `maximum` from the owner's MultiplayerSynchronizer.

signal changed(current: float, maximum: float)
signal died(from_slot: int)
## After damage_typed(): what was really taken (0 = immune, an ally with no friendly fire, or dead).
signal hurt(amount: float, kind: StringName, from_slot: int)
## Every hit that took health, whatever called (a blow, a shot, a spell, a ritual): what was taken, who
## took it and whether the bar was full before (sacengine dealDamage notes a grudge only then, state.d:8933).
signal hit(amount: float, from_slot: int, was_full: bool)

## sacengine DamageMod (state.d:8868) as the resistance dealDamage picks (state.d:8951-8957).
const MELEE := &"melee"
const DIRECT_SPELL := &"direct_spell"
const SPLASH_SPELL := &"splash_spell"
const DIRECT_RANGED := &"direct_ranged"
const SPLASH_RANGED := &"splash_ranged"

## Only read by setup(): MatchRules.start_health, if not negative, replaces a full bar.
@export var rules: MatchRules
@export var maximum: float = 0.0:
	set(value):
		maximum = maxf(value, 0.0)
		changed.emit(current, maximum)
@export var current: float = 0.0:
	set(value):
		current = value
		changed.emit(current, maximum)

## Takes a hit before this body does (a building's guardians, RFC-021b). Optional: empty = nobody
## stands in for it.
@export var deflector: DamageDeflector
## F117: the body's passiveOnDamage (Taurock korq). Optional: empty = no passive, every hit ×1.
@export var passive: DamagePassive
## F137: the states the body is in (petrified ×0.2, state.d:8965) scale every hit, on both paths. Optional: empty = ×1.
@export var afflictions: Afflictions
## F122: the body's poison (Poisoning): its resistance bonus goes into every resistance and its factor into regenerate().
## Optional: empty = no bonus, regeneration ×1.
@export var poisoning: Poisoning

## Multiplies damage_typed on top of the resistance: the body's own effects, as dealDamage
## stacks them (state.d:8962-8969); Rockform sets 0.05.
var damage_factor := 1.0
## Per kind of damage (the constants above): multiplies damage_typed on top of the resistance. The
## body's own effects write here, Health reads (Guardian: spells ×0.5, ranged ×0.25).
var kind_factors: Dictionary = {}


func setup(full: float) -> void:
	maximum = full
	current = full
	if rules and rules.start_health >= 0.0:
		current = minf(rules.start_health, full)


func is_dead() -> bool:
	return maximum > 0.0 and current <= 0.0


func is_full() -> bool:
	return current >= maximum


## A hit whose caller already applied the body's damage_factor and resistance (melee, rituals). The states the body is
## in still scale it (_state_factor, REVIEW-F139 N5).
func damage(amount: float, from_slot: int = 0) -> void:
	if not _has_authority() or amount <= 0.0 or is_dead() or not _can_be_damaged():
		return
	## A caller that does not say the kind (melee, rituals) is asked as melee.
	if not is_nan(_deflect(amount, MELEE, from_slot)):
		return
	## Before F139 this path did not look at the side; with no MatchState it still does not.
	var side := _side_factor(from_slot, false, 1.0)
	if side <= 0.0:
		return
	_hit(amount * side * _state_factor() * _passive_factor(), from_slot)


func _hit(amount: float, from_slot: int) -> void:
	var was_full := current >= maximum
	current = maxf(current - amount, 0.0)
	hit.emit(amount, from_slot, was_full)
	if current <= 0.0:
		died.emit(from_slot)


## sacengine dealDamage (state.d:8948-8972) and dealRawDamage (state.d:9001-9050):
## amount · side factor · max(0, resistance) · damage_factor of the body's CRE8/WIZD data · its states, capped at the
## health left.
## The side factor is the match's friendly fire (_side_factor): an ally takes nothing with it off (dealDamage returns 0,
## state.d:8961) and ally_damage_factor with it on (sideDamageMultiplier, state.d:9005, 28892-28899); `ignore_friendly`
## (poison, state.d:9415-9419) takes ×1 then. A dead body takes nothing (canDamage).
## Melee callers still apply sacengine's extra 0.4 themselves (melee_attack.gd).
## Returns the damage taken.
## `pierce_shield` (sacengine DamageMod.peirceShield, state.d:8962-8969): the body's shields and states (damage_factor:
## Rockform, Life Shield; _state_factor: petrified) do not scale it. The Pyromaniac's fire (F123).
func damage_typed(amount: float, kind: StringName, from_slot: int = 0, ignore_friendly := false, pierce_shield := false) -> float:
	if not _has_authority() or amount <= 0.0 or is_dead() or not _can_be_damaged():
		return 0.0
	var passed := _deflect(amount, kind, from_slot)
	if not is_nan(passed):
		return passed
	var taken := 0.0
	var side := _side_factor(from_slot, ignore_friendly, 0.0)
	if side > 0.0:
		var factor := float(kind_factors.get(kind, 1.0))
		var shields := 1.0 if pierce_shield else maxf(0.0, damage_factor) * _state_factor()
		taken = minf(current, amount * side * resistance(kind) * maxf(0.0, factor) * shields * _passive_factor())
	if taken > 0.0:
		_hit(taken, from_slot)
	hurt.emit(taken, kind, from_slot)
	return taken


## The body's resistance for `kind`: CreatureType for a UnitBody, WizardType for a wizard.
## sacengine stores them ×1e-3 (sacobject.d:156-160); a 0 is immunity (Trogg vs spells).
## F122: dealDamage adds the poison's resistanceBonus inside the max (state.d:8950-8957): max(0, resistance + bonus).
func resistance(kind: StringName) -> float:
	return maxf(0.0, _base_resistance(kind) + (poisoning.resistance_bonus() if poisoning else 0.0))


func _base_resistance(kind: StringName) -> float:
	var body := get_parent()
	var data: Resource = null
	var type: Variant = body.get("type") if body and "type" in body else null
	if type is CreatureType:
		data = type
	elif body and "wizard_tag" in body:
		data = GameData.wizard(str(body.get("wizard_tag")))
	if data == null:
		return 1.0
	var value: Variant = data.get("%s_resistance" % kind)
	return float(value) if value != null else 1.0


var _deflecting := false
## F139: the match's MatchState, found on the first hit between allies (group `match_state`).
var _match: MatchState


## F139 (RFC-031 §3.2): the one place that decides how much of a hit from `from_slot` this body takes for its side.
## Another side, or no side (0): ×1. The same side: 0 with friendly fire off (state.d:8961); with it on, ×1 if the hit
## ignores it (poison, state.d:9415-9419) and the match's ally_damage_factor otherwise (state.d:9005, 28892-28899).
## The rule is the one MatchState took from the world's rules. With no MatchState (a harness) it is `unruled`: the
## behaviour each caller had before F139 (damage_typed 0, damage ×1).
func _side_factor(from_slot: int, ignore_friendly: bool, unruled: float) -> float:
	if from_slot <= 0 or from_slot != _owner_slot():
		return 1.0
	var state := _match_state()
	if state == null:
		return unruled
	if not state.friendly_fire:
		return 0.0
	return 1.0 if ignore_friendly else maxf(0.0, state.ally_damage_factor)


func _match_state() -> MatchState:
	if _match == null or not is_instance_valid(_match):
		_match = null
		if is_inside_tree():
			_match = get_tree().get_first_node_in_group(&"match_state") as MatchState
	return _match


## F137: the one place both damage paths ask for the factor of the states the body is in (dealDamage, state.d:8965).
func _state_factor() -> float:
	return maxf(0.0, afflictions.damage_factor()) if afflictions else 1.0


## sacengine dealRawDamage (state.d:9010-9028): the passive scales every kind of hit by the health before it.
func _passive_factor() -> float:
	if passive == null or maximum <= 0.0:
		return 1.0
	return passive.incoming_factor(current / maximum)


## One query per hit: the damage the deflector's stand-ins took, or NAN if it did not deflect.
func _deflect(amount: float, kind: StringName, from_slot: int) -> float:
	if deflector == null or not is_instance_valid(deflector) or _deflecting:
		return NAN
	_deflecting = true
	var taken: float = deflector.deflect(amount, kind, from_slot)
	_deflecting = false
	return taken


## sacengine updateCreatureStats (state.d:14403): heal(max(0, regeneration · poisonRegeneration) · …). The body's
## regeneration (amount already scaled by mana and delta) times the poison's factor (freg 0: none while it lasts).
func regenerate(amount: float) -> void:
	heal(amount * (maxf(0.0, poisoning.regeneration_factor()) if poisoning else 1.0))


func heal(amount: float) -> void:
	if not _has_authority() or amount <= 0.0:
		return
	current = minf(current + amount, maximum)


## sacengine canDamage (state.d:8916-8923): a wizard's ghost takes no damage while it heals.
func _can_be_damaged() -> bool:
	var body := get_parent()
	return body == null or not body.has_method("is_targetable") or bool(body.call("is_targetable"))


func _owner_slot() -> int:
	var body := get_parent()
	return int(body.get("owner_slot")) if body and "owner_slot" in body else 0


func _has_authority() -> bool:
	return not MpKit.is_networked() or MpKit.is_server()
