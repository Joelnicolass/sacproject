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

## sacengine DamageMod bits that are not the kind (state.d:8868-8880), for damage_typed(..., mods). F130 (lightning charges the
## Storm Giant) and F155 (ignite lights the oil) read them; the kinds above stay the resistance's.
const LIGHTNING := 1 << 5
const IGNITE := 1 << 6

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
## F126: the body's life shield (Life Shield, Protector). Optional: empty = no shield, ×1.
@export var life_shield: LifeShield
## F155: the body's oil (Oiled). A hit with IGNITE that reaches it while the body is oiled takes ×2 and lights it (sacengine
## dealRawDamage, state.d:9028-9031). Optional: empty = never doubled.
@export var oil: Oiled
## F131: what the body has devoured (Devour): its five resistances ×0.9 each soul (sacengine devourSoul, state.d:13154-13158).
## Optional: empty = ×1.
@export var growth: DevourGrowth

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


## Server or solo. The maximum goes up by `amount` and so does the health (devourSoul: health += 500, maxHealth += 500).
func raise_maximum(amount: float) -> void:
	if not _has_authority() or amount <= 0.0:
		return
	maximum += amount
	current += amount


func is_dead() -> bool:
	return maximum > 0.0 and current <= 0.0


func is_full() -> bool:
	return current >= maximum


## A hit whose caller already applied the body's damage_factor and resistance (melee, rituals). The states the body is
## in still scale it (_state_factor, REVIEW-F139 N5).
## F164: returns the damage taken (capped at the health left, like damage_typed); 0 when nothing reached the body. With a
## deflector, the damage its stand-ins took (F164b). LifeDrain.feed reads it; callers that ignore it do not change.
func damage(amount: float, from_slot: int = 0) -> float:
	deflected_last = false
	if not _has_authority() or amount <= 0.0 or is_dead() or not _can_be_damaged():
		return 0.0
	## A caller that does not say the kind (melee, rituals) is asked as melee.
	var passed := _deflect(amount, MELEE, from_slot)
	if not is_nan(passed):
		return passed
	## Before F139 this path did not look at the side; with no MatchState it still does not.
	var side := _side_factor(from_slot, false, 1.0)
	if side <= 0.0:
		return 0.0
	var scaled := amount * side * _state_factor() * _passive_factor()
	var taken := minf(current, scaled)
	_hit(scaled, from_slot)
	return taken


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
## `mods` (F130): the DamageMod bits of the hit (LIGHTNING, IGNITE). The body's passive and the oil read them.
## `pierce_shield` (sacengine DamageMod.peirceShield, state.d:8962-8969): the body's shields and states (damage_factor:
## Rockform, Life Shield; _state_factor: petrified) do not scale it. The Pyromaniac's fire (F123).
func damage_typed(amount: float, kind: StringName, from_slot: int = 0, ignore_friendly := false, pierce_shield := false, mods := 0) -> float:
	deflected_last = false
	if not _has_authority() or amount <= 0.0 or is_dead() or not _can_be_damaged():
		return 0.0
	var passed := _deflect(amount, kind, from_slot)
	if not is_nan(passed):
		return passed
	var taken := 0.0
	var side := _side_factor(from_slot, ignore_friendly, 0.0)
	if side > 0.0:
		var factor := float(kind_factors.get(kind, 1.0))
		var shields := 1.0 if pierce_shield else shield_factor() * _state_factor()
		var before := amount * side * resistance(kind) * maxf(0.0, factor) * shields
		var scaled := before * _passive_factor(before, mods, from_slot)
		if mods & IGNITE != 0 and oil != null and oil.ignite():
			scaled *= 2.0
		taken = minf(current, scaled)
	if taken > 0.0:
		_hit(taken, from_slot)
	hurt.emit(taken, kind, from_slot)
	return taken


## sacengine dealDamage (state.d:8962-8963): the body's damage_factor (Rockform) times the life shield's. The melee path asks it too.
func shield_factor() -> float:
	return maxf(0.0, damage_factor) * (life_shield.factor() if life_shield else 1.0)


## The body's resistance for `kind`: CreatureType for a UnitBody, WizardType for a wizard.
## sacengine stores them ×1e-3 (sacobject.d:156-160); a 0 is immunity (Trogg vs spells).
## F122: dealDamage adds the poison's resistanceBonus inside the max (state.d:8950-8957): max(0, resistance + bonus).
## F131: the resistance is the one the body has devoured down to (DevourGrowth, ×0.9 a soul).
func resistance(kind: StringName) -> float:
	var base := _base_resistance(kind) * (growth.resistance_factor() if growth else 1.0)
	return maxf(0.0, base + (poisoning.resistance_bonus() if poisoning else 0.0))


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
## F164b: the last hit was taken by the deflector's stand-ins (a building's guardians), not by this body. They are
## creatures, so the attacker drains from what they took (sacengine damageGuardians, state.d:9119-9141): LifeDrain reads it.
var deflected_last := false
## F139: the match's MatchState, found on the first hit between allies (group `match_state`).
var _match: MatchState


## F139 (RFC-031 §3.2): the one place that decides how much of a hit from `from_slot` this body takes for its side.
## Another side, or no side (0): ×1. The same side, or an ally by the stance (RFC-049 049c: 2v2 teams): 0 with friendly fire off (state.d:8961); with it on, ×1 if the hit
## ignores it (poison, state.d:9415-9419) and the match's ally_damage_factor otherwise (state.d:9005, 28892-28899).
## The rule is the one MatchState took from the world's rules. With no MatchState (a harness) it is `unruled`: the
## behaviour each caller had before F139 (damage_typed 0, damage ×1).
func _side_factor(from_slot: int, ignore_friendly: bool, unruled: float) -> float:
	if from_slot <= 0:
		return 1.0
	var owner_slot := _owner_slot()
	if from_slot != owner_slot and SideRelations.stance(from_slot, owner_slot) != SideRelations.Stance.ALLY:
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


## sacengine dealRawDamage (state.d:9010-9028): the passive scales every kind of hit by the health before it. F130: it also
## gets the hit's `mods`, the damage that reached it (`before`: side, resistance and shields already applied) and whether the
## attacker is of the body's side, which the Lightning Charge reads (state.d:9017-9022).
func _passive_factor(before := 0.0, mods := 0, from_slot := 0) -> float:
	if passive == null or maximum <= 0.0:
		return 1.0
	var ally := from_slot > 0 and from_slot == _owner_slot()
	return passive.incoming_factor(current / maximum, mods, before, ally)


## One query per hit: the damage the deflector's stand-ins took, or NAN if it did not deflect.
func _deflect(amount: float, kind: StringName, from_slot: int) -> float:
	if deflector == null or not is_instance_valid(deflector) or _deflecting:
		return NAN
	_deflecting = true
	var taken: float = deflector.deflect(amount, kind, from_slot)
	_deflecting = false
	deflected_last = not is_nan(taken)
	return taken


## sacengine updateCreatureStats (state.d:14403): heal(max(0, regeneration · poisonRegeneration) · …). The body's
## regeneration (amount already scaled by mana and delta) times the poison's factor (freg 0: none while it lasts).
## F159: a state that blocks regeneration (Vined: sacengine regenerationBlocked, stats.d:73) makes it nothing.
func regenerate(amount: float) -> void:
	if afflictions != null and afflictions.blocks_regeneration():
		return
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
