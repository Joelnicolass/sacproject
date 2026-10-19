class_name DamagePassiveType
extends Resource

## One passiveOnDamage of a CRE8 (sacobject.d:426 abilities[2]) as two linear knobs on the body's relative health h
## (health / maxHealth, read before the hit):
##   incoming  = incoming_base + incoming_per_health · h             (damage the body takes, every kind)
##   outgoing  = 1 + outgoing_melee_per_missing · (1 − h)             (its own melee blows only)
## The defaults change nothing. A new passive of this shape is a new .tres in DamagePassive.types; a passive with
## side effects (gcil lightning charge, rifl phoenix shield) is not of this shape and gets its own component.

## SpellTag of the passive, as CreatureType.passive_on_damage holds it.
@export var tag := ""
## sacengine dealRawDamage taurockPassive (state.d:9011-9015): 0.25 + 0.75·h.
@export var incoming_base := 1.0
@export var incoming_per_health := 0.0
## sacengine attackDamageFactor firefistPassive (state.d:8886-8890): melee ×(1 + 1.5·(1 − h)).
@export var outgoing_melee_per_missing := 0.0


func incoming(health_fraction: float) -> float:
	return maxf(0.0, incoming_base + incoming_per_health * clampf(health_fraction, 0.0, 1.0))


func outgoing_melee(health_fraction: float) -> float:
	return maxf(0.0, 1.0 + outgoing_melee_per_missing * (1.0 - clampf(health_fraction, 0.0, 1.0)))
