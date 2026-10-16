@tool
class_name DamagePassive
extends Node

## F117 (RFC-030f): the only owner of the damage multipliers of a creature's passiveOnDamage (sacobject.d:426). Health asks
## incoming_factor() for every hit the body takes; MeleeAttack asks outgoing_melee_factor() for every blow it lands. The
## formula lives in the DamagePassiveType of the creature's tag; a creature without one (or a tag with no resource here) is ×1.
## A child of unit.tscn; take it out and no passive applies.

## The body whose CreatureType.passive_on_damage picks the resource. Read on every query: a body that changes its tag
## (replication, a late join) changes its passive with it.
@export var body: UnitBody
## The passives of this shape (korq, ahtf). A new one is a new .tres here; Health and MeleeAttack do not change.
@export var types: Array[DamagePassiveType] = []

var _cached_tag := ""
var _cached: DamagePassiveType


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null:
		warnings.append("Falta el cuerpo (body).")
	return warnings


## Multiplier on the damage the body takes at relative health `health_fraction` (before the hit).
func incoming_factor(health_fraction: float) -> float:
	var passive := active()
	return passive.incoming(health_fraction) if passive else 1.0


## Multiplier on the melee damage the body deals at relative health `health_fraction`.
func outgoing_melee_factor(health_fraction: float) -> float:
	var passive := active()
	return passive.outgoing_melee(health_fraction) if passive else 1.0


## The resource of the body's passive, or null.
func active() -> DamagePassiveType:
	var tag := body.type.passive_on_damage if body != null and body.type != null else ""
	if tag != _cached_tag:
		_cached_tag = tag
		_cached = null
		for candidate in types:
			if candidate != null and not tag.is_empty() and candidate.tag == tag:
				_cached = candidate
				break
	return _cached
