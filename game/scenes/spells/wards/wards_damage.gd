@tool
class_name WardsDamage
extends DamageModifier

## Hands Health what the body's wards do to a hit: a ward that makes it immune (Ethereal Form)
## blocks every hit, and the others scale the typed hits of their kinds (Life Shield, Skin of
## Stone, Air Shield...). Not: which wards are on (Wards) nor what each one does (Ward). A child
## of the body's Health, listed in Health.modifiers.

## The body's wards. Empty = no ward, every hit ×1.
@export var wards: Wards


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if wards else PackedStringArray(["Assign wards."])


func blocks_damage() -> bool:
	return wards != null and wards.immune()


func shield_factor(kind: StringName) -> float:
	return wards.factor(kind) if wards else 1.0
