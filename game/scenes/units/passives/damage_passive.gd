class_name DamagePassive
extends UnitPassive

## How a creature's own health scales the damage it takes and the melee blows it deals, as two
## linear knobs on its relative health h (health / maximum, read before the hit):
##   incoming = incoming_base + incoming_per_health · h        (every hit the body takes)
##   outgoing = 1 + outgoing_melee_per_missing · (1 − h)        (its own melee blows only)
## The defaults change nothing. Health asks incoming_factor() for every hit; the Weapons ask
## outgoing_melee_factor() and melee_accuracy_factor() for every blow. It is a node of the
## creature's `<name>_passives.tscn` (Taurock's hide, Firefist's fury); attach() makes it the
## `passive` of the creature's PassiveDamage (Health's modifier) and Weapons. With a `charge` (the
## Storm Giant's Lightning Charge) a lightning hit charges the body and a charged body hits and aims
## harder.

## Multiplier on every hit at full health minus `incoming_per_health`: the Taurock's hide is 0.25 +
## 0.75 · h.
@export var incoming_base := 1.0
@export var incoming_per_health := 0.0
## Extra melee damage per share of health missing: the Firefist's fury is ×(1 + 1.5 · (1 − h)).
@export var outgoing_melee_per_missing := 0.0
## The creature's Lightning Charge, in the same passives scene. Empty = no charge.
@export var charge: LightningCharge


func attach(mount: PassiveMount) -> void:
	super(mount)
	if mount.passive_damage:
		mount.passive_damage.passive = self
	else:
		push_error("DamagePassive on '%s': its PassiveMount has no passive_damage" % body.name)
	mount.weapons.passive = self


## Multiplier on the damage the body takes at relative health `health_fraction` (before the hit).
## `mods` are the hit's DamageMod bits, `before` the damage that reached the passive and `ally`
## whether the attacker is of the body's side: a lightning hit on a charged body charges it and
## leaves a quarter.
func incoming_factor(health_fraction: float, mods := 0, before := 0.0, ally := false) -> float:
	var factor := incoming(health_fraction)
	if charge != null and mods & Health.LIGHTNING != 0:
		factor *= charge.absorb(before, ally)
	return factor


## Multiplier on the melee damage the body deals at relative health `health_fraction`.
func outgoing_melee_factor(health_fraction: float) -> float:
	return outgoing_melee(health_fraction) * (charge.melee_factor() if charge else 1.0)


## ×1.5 on the body's melee accuracy while its Lightning Charge is on.
func melee_accuracy_factor() -> float:
	return charge.melee_factor() if charge else 1.0


## The incoming knob alone at relative health `health_fraction` (clamped to 0..1); never below 0.
func incoming(health_fraction: float) -> float:
	return maxf(0.0, incoming_base + incoming_per_health * clampf(health_fraction, 0.0, 1.0))


## The outgoing knob alone at relative health `health_fraction` (clamped to 0..1); never below 0.
func outgoing_melee(health_fraction: float) -> float:
	return maxf(0.0, 1.0 + outgoing_melee_per_missing * (1.0 - clampf(health_fraction, 0.0, 1.0)))
