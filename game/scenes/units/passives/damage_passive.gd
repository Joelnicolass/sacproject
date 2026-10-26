@tool
class_name DamagePassive
extends Node

## F117 (RFC-030f): the only owner of the damage multipliers of a creature's passiveOnDamage (sacobject.d:426). Health asks
## incoming_factor() for every hit the body takes; MeleeWeapon asks outgoing_melee_factor() for every blow it lands. The
## formula lives in the DamagePassiveType of the creature's `on_damage`; a creature without one (or an ability with no resource here) is ×1.
## A child of unit.tscn; take it out and no passive applies.
## F130: gcil (the Storm Giant's Lightning Charge) has side effects and is not a DamagePassiveType: its LightningCharge is the
## `charge` socket, and this node only asks it (a lightning hit charges, a charged body blows and aims ×1.5).

## The body whose CreatureType.on_damage picks the resource. Read on every query: a body that changes its type changes its
## passive with it.
@export var body: UnitBody
## The passives of this shape (korq, ahtf). A new one is a new .tres here; Health and MeleeWeapon do not change.
@export var types: Array[DamagePassiveType] = []
## F130: the body's Lightning Charge. Optional: empty = no charge. It only counts for a body whose `on_damage` is its `passive`.
@export var charge: LightningCharge

var _cached_for: AbilityType
var _cached: DamagePassiveType


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null:
		warnings.append("Falta el cuerpo (body).")
	return warnings


## Multiplier on the damage the body takes at relative health `health_fraction` (before the hit). F130: `mods` are the hit's
## DamageMod bits, `before` the damage that reached the passive and `ally` whether the attacker is of the body's side: a lightning
## hit on a Lightning Charge body charges it f · before frames and leaves a quarter (state.d:9017-9022).
func incoming_factor(health_fraction: float, mods := 0, before := 0.0, ally := false) -> float:
	var passive := active()
	var factor := passive.incoming(health_fraction) if passive else 1.0
	var lightning := _charge()
	if lightning != null and mods & Health.LIGHTNING != 0:
		factor *= lightning.absorb(before, ally)
	return factor


## Multiplier on the melee damage the body deals at relative health `health_fraction`.
func outgoing_melee_factor(health_fraction: float) -> float:
	var passive := active()
	var lightning := _charge()
	return (passive.outgoing_melee(health_fraction) if passive else 1.0) * (lightning.melee_factor() if lightning else 1.0)


## F130: ×1.5 on the body's melee accuracy while its Lightning Charge is on (dealMeleeDamage, state.d:9237).
func melee_accuracy_factor() -> float:
	var lightning := _charge()
	return lightning.melee_factor() if lightning else 1.0


## The Lightning Charge, when the body's passive is its (the other bodies carry the node and ignore it).
func _charge() -> LightningCharge:
	if charge == null or body == null or body.type == null or not body.type.has_passive(charge.passive):
		return null
	return charge


## The resource of the body's passive, or null.
func active() -> DamagePassiveType:
	var ability: AbilityType = body.type.on_damage if body != null and body.type != null else null
	if ability != _cached_for:
		_cached_for = ability
		_cached = null
		for candidate in types:
			if candidate != null and ability != null and candidate.ability == ability:
				_cached = candidate
				break
	return _cached
