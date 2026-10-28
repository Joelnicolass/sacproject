class_name Health
extends Node

## Hit points of a body. The server (or solo) changes them; clients get `current`
## and `maximum` from the owner's MultiplayerSynchronizer.

signal changed(current: float, maximum: float)
signal died(from_slot: int)
## After damage_typed(): what was really taken (0 = immune, an ally with no friendly fire, or dead).
signal hurt(amount: float, kind: StringName, from_slot: int)
## Every hit that took health, whatever called (a blow, a shot, a spell, a ritual): what was taken, who
## took it and whether the bar was full before.
signal hit(amount: float, from_slot: int, was_full: bool)

## The kinds of damage, each the resistance the body uses against it.
const MELEE := &"melee"
const DIRECT_SPELL := &"direct_spell"
const SPLASH_SPELL := &"splash_spell"
const DIRECT_RANGED := &"direct_ranged"
const SPLASH_RANGED := &"splash_ranged"

## The damage bits that are not the kind, for damage_typed(..., mods). Lightning (it charges the
## Storm Giant) and ignite (it lights the oil) read them; the kinds above stay the resistance's.
const LIGHTNING := 1 << 5
const IGNITE := 1 << 6

## Only read by setup(): MatchRules.start_health, if not negative, replaces a full bar.
@export var rules: MatchRules
@export var maximum: float = 0.0:
	set(value):
		maximum = maxf(value, 0.0)
		changed.emit(current, maximum)
## Every drop on any peer (a hit here, or the replicated value on a client) is also told game-wide as Events.body_hurt.
@export var current: float = 0.0:
	set(value):
		var before := current
		current = value
		changed.emit(current, maximum)
		if current < before and is_inside_tree():
			Events.body_hurt.emit(get_parent() as Node3D, before - current, current, maximum)

## What changes the hits this body takes and what it heals, asked in this order at every stage
## (DamageModifier lists the stages). Order matters only where two add up: the poison before the
## states, so the resistance sums as resistance + poison + states. The body scenes set it:
## a building's guardians (GuardPost) · DevourGrowth · Poisoning · the states and the oil
## (AfflictionsDamage) · the wards (WardsDamage) · the creature's passive (PassiveDamage).
## Empty = every hit ×1 with the plain resistance.
@export var modifiers: Array[DamageModifier] = []

## Multiplies damage_typed on top of the resistance: the body's own effects, as the original's damage
## stacks them; Rockform sets 0.05.
var damage_factor := 1.0
## Per kind of damage (the constants above): multiplies damage_typed on top of the resistance. The
## body's own effects write here, Health reads (Guardian: spells ×0.5, ranged ×0.25).
var kind_factors: Dictionary = {}
## The last hit was taken by the deflector's stand-ins (a building's guardians), not by this body. They are
## creatures, so the attacker drains from what they took: LifeDrain reads it.
var deflected_last := false

var _deflecting := false
## The match's MatchState, found on the first hit between allies.
var _match: MatchState


func setup(full: float) -> void:
	maximum = full
	# Set once: a start below full is not a hit (no body_hurt).
	current = minf(rules.start_health, full) if rules and rules.start_health >= 0.0 else full


## Server or solo. The maximum goes up by `amount` and so does the health (health += 500, max health += 500).
func raise_maximum(amount: float) -> void:
	if not is_multiplayer_authority() or amount <= 0.0:
		return
	maximum += amount
	current += amount


## The Health of `node`, or null (a body that cannot be hurt has none).
static func of(node: Node) -> Health:
	for child in node.get_children() if node else []:
		if child is Health:
			return child
	return null


func is_dead() -> bool:
	return maximum > 0.0 and current <= 0.0


func is_full() -> bool:
	return current >= maximum


## A hit whose caller already applied the body's damage_factor and resistance (melee, rituals). The states the body is
## in still scale it (_state_factor).
## Returns the damage taken (capped at the health left, like damage_typed); 0 when nothing reached the body. With a
## deflector, the damage its stand-ins took. LifeDrain.feed reads it; callers that ignore it do not change.
func damage(amount: float, from_slot: int = 0) -> float:
	deflected_last = false
	if not is_multiplayer_authority() or amount <= 0.0 or is_dead() or not _can_be_damaged():
		return 0.0
	# A caller that does not say the kind (melee, rituals) is asked as melee.
	var passed := _deflect(amount, MELEE, from_slot)
	if not is_nan(passed):
		return passed
	# With no MatchState the side does not change the hit.
	var side := _side_factor(from_slot, false, 1.0)
	if side <= 0.0:
		return 0.0
	var scaled := amount * side * _state_factor() * _passive_factor()
	var taken := minf(current, scaled)
	_hit(scaled, from_slot)
	return taken


## Server or solo. The health goes to 0 whatever the body wears: no resistance, shield or side rule (Death's blow, a gib). A dead body
## or one that cannot be hurt (maximum 0) takes nothing.
func kill(from_slot: int = 0) -> void:
	if is_multiplayer_authority() and not is_dead() and maximum > 0.0:
		_hit(current, from_slot)


func _hit(amount: float, from_slot: int) -> void:
	var was_full := current >= maximum
	current = maxf(current - amount, 0.0)
	hit.emit(amount, from_slot, was_full)
	if current <= 0.0:
		died.emit(from_slot)


## The damage a hit does to this body:
## amount · side factor · max(0, resistance) · damage_factor of the body's CRE8/WIZD data · its states, capped at the
## health left.
## The side factor is the match's friendly fire (_side_factor): an ally takes nothing with it off
## and ally_damage_factor with it on; `ignore_friendly`
## (poison) takes ×1 then. A dead body takes nothing.
## Melee callers still apply the original's extra 0.4 themselves (melee_weapon.gd).
## Returns the damage taken.
## `mods`: the DamageMod bits of the hit (LIGHTNING, IGNITE). The body's passive and the oil read them.
## `pierce_shield`: the body's shields and states (damage_factor:
## Rockform, Life Shield; _state_factor: petrified) do not scale it. The Pyromaniac's fire.
func damage_typed(
	amount: float,
	kind: StringName,
	from_slot: int = 0,
	ignore_friendly := false,
	pierce_shield := false,
	mods := 0
) -> float:
	deflected_last = false
	if not is_multiplayer_authority() or amount <= 0.0 or is_dead() or not _can_be_damaged():
		return 0.0
	var passed := _deflect(amount, kind, from_slot)
	if not is_nan(passed):
		return passed
	var taken := 0.0
	var side := _side_factor(from_slot, ignore_friendly, 0.0)
	if side > 0.0:
		var factor := float(kind_factors.get(kind, 1.0))
		var shields := 1.0 if pierce_shield else shield_factor(kind) * _state_factor()
		var before := amount * side * resistance(kind) * maxf(0.0, factor) * shields
		var scaled := before * _passive_factor(before, mods, from_slot)
		for modifier in _modifiers():
			scaled *= modifier.final_factor(mods)
		taken = minf(current, scaled)
	if taken > 0.0:
		_hit(taken, from_slot)
	hurt.emit(taken, kind, from_slot)
	return taken


## The body's damage_factor (Rockform) times its modifiers' shield_factor for `kind` (the wards).
## The melee path asks it too.
func shield_factor(kind := MELEE) -> float:
	var factor := 1.0
	for modifier in _modifiers():
		factor *= modifier.shield_factor(kind)
	return maxf(0.0, damage_factor) * factor


## The body's resistance for `kind`: CreatureType for a UnitBody, WizardType for a wizard.
## A 0 is immunity (Trogg vs spells).
## The modifiers scale the base (DevourGrowth, ×0.9 a soul), then add their bonuses inside the
## max, in list order: max(0, resistance + poison + spell states (Slime +0.2 a layer)).
func resistance(kind: StringName) -> float:
	var scale := 1.0
	for modifier in _modifiers():
		scale *= modifier.resistance_factor()
	var total := _base_resistance(kind) * scale
	for modifier in _modifiers():
		total += modifier.resistance_bonus()
	return maxf(0.0, total)


func _base_resistance(kind: StringName) -> float:
	var body := get_parent()
	var data: Resource = null
	var type: Variant = body.get("type") if body and "type" in body else null
	if type is CreatureType:
		data = type
	elif body and "wizard_type" in body:
		data = body.get("wizard_type")
	if data == null:
		return 1.0
	var value: Variant = data.get("%s_resistance" % kind)
	return float(value) if value != null else 1.0


## The side factor a typed hit (damage_typed: a spell, a splash) from `from_slot` gets on this body. The AI reads it to
## foresee what its own burst would take from its own bodies (AiSpellEval.own_splash); it changes nothing.
func side_factor(from_slot: int) -> float:
	return _side_factor(from_slot, false, 0.0)


## The one place that decides how much of a hit from `from_slot` this body takes for its side.
## Another side, or no side (0): ×1. The same side, or an ally by the stance (2v2 teams): 0 with friendly fire off; with it on, ×1 if the hit
## ignores it (poison) and the match's ally_damage_factor otherwise.
## The rule is the one MatchState took from the world's rules. With no MatchState (a test scene) it is `unruled`
## (damage_typed 0, damage ×1).
func _side_factor(from_slot: int, ignore_friendly: bool, unruled: float) -> float:
	if from_slot <= 0:
		return 1.0
	var owner_slot := _owner_slot()
	if (
		from_slot != owner_slot
		and SideRelations.stance(from_slot, owner_slot) != SideRelations.Stance.ALLY
	):
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
			_match = get_tree().get_first_node_in_group(MatchState.GROUP) as MatchState
	return _match


## The one place both damage paths ask for the factor of the states the body is in.
func _state_factor() -> float:
	var factor := 1.0
	for modifier in _modifiers():
		factor *= modifier.state_factor()
	return factor


## The modifiers' incoming_factor (a creature's passive) scales every kind of hit by the health
## before it. They also get the hit's `mods`, the damage that reached them (`before`: side,
## resistance and shields already applied) and whether the attacker is of the body's side, which
## the Lightning Charge reads.
func _passive_factor(before := 0.0, mods := 0, from_slot := 0) -> float:
	if maximum <= 0.0:
		return 1.0
	var ally := from_slot > 0 and from_slot == _owner_slot()
	var factor := 1.0
	for modifier in _modifiers():
		factor *= modifier.incoming_factor(current / maximum, mods, before, ally)
	return factor


## One query per hit: the damage the first deflecting modifier's stand-ins took, or NAN if none did.
func _deflect(amount: float, kind: StringName, from_slot: int) -> float:
	if _deflecting:
		return NAN
	_deflecting = true
	var taken := NAN
	for modifier in _modifiers():
		taken = modifier.deflect(amount, kind, from_slot)
		if not is_nan(taken):
			break
	_deflecting = false
	deflected_last = not is_nan(taken)
	return taken


## Heals the body's regeneration (amount already scaled by mana and delta) times each modifier's
## regeneration_factor, each clamped at 0: the poison's freg (0: none while it lasts), a state that
## blocks regeneration (Vined) 0.
func regenerate(amount: float) -> void:
	var factor := 1.0
	for modifier in _modifiers():
		factor *= maxf(0.0, modifier.regeneration_factor())
	heal(amount * factor)


func heal(amount: float) -> void:
	if not is_multiplayer_authority() or amount <= 0.0:
		return
	current = minf(current + amount, maximum)


## A wizard's ghost takes no damage while it heals; neither does a body with a modifier that
## blocks damage (the Ethereal Form ward), whatever the hit pierces.
func _can_be_damaged() -> bool:
	for modifier in _modifiers():
		if modifier.blocks_damage():
			return false
	var body := get_parent()
	return GameBody.targetable(body)


func _owner_slot() -> int:
	var body := get_parent()
	return int(body.get("owner_slot")) if body and "owner_slot" in body else 0


## The modifiers that are still there, in list order (a freed one is skipped).
func _modifiers() -> Array[DamageModifier]:
	var live: Array[DamageModifier] = []
	for modifier in modifiers:
		if is_instance_valid(modifier):
			live.append(modifier)
	return live
