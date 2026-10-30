@tool
class_name PassiveDamage
extends DamageModifier

## Hands Health the creature's DamagePassive (Taurock's hide, the Storm Giant's Lightning Charge):
## every hit ×passive.incoming_factor() from the health before it. Not: the numbers (DamagePassive).
## A child of the creature's Health, listed in Health.modifiers; DamagePassive.attach() fills
## `passive` through PassiveMount, so a creature without one keeps ×1.

## Set by DamagePassive.attach(). Empty = every hit ×1.
var passive: DamagePassive


func incoming_factor(health_fraction: float, mods: int, before: float, ally: bool) -> float:
	return passive.incoming_factor(health_fraction, mods, before, ally) if passive else 1.0
