@tool
class_name AfflictionsDamage
extends DamageModifier

## Hands Health what the states the body is in do to it: their factor on every hit (petrified
## ×0.2), their resistance bonus (Slime +0.2 a layer), a state that stops regeneration (Vined), and
## the oil, which doubles the first IGNITE hit and lights up. Not: which states are on (Afflictions)
## nor how the oil burns (Oiled). A child of the body's Health, listed in Health.modifiers.

## The body's states. Empty = ×1, no bonus, regeneration untouched.
@export var afflictions: Afflictions
## The body's oil. Empty = never doubled.
@export var oil: Oiled


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if afflictions else PackedStringArray(["Assign afflictions."])


func state_factor() -> float:
	return maxf(0.0, afflictions.damage_factor()) if afflictions else 1.0


func resistance_bonus() -> float:
	return afflictions.resistance_bonus() if afflictions else 0.0


## ×2 the first time an IGNITE hit reaches the oiled body (the oil lights up), ×1 otherwise.
func final_factor(mods: int) -> float:
	if mods & Health.IGNITE != 0 and oil != null and oil.ignite():
		return 2.0
	return 1.0


func regeneration_factor() -> float:
	return 0.0 if afflictions != null and afflictions.blocks_regeneration() else 1.0
