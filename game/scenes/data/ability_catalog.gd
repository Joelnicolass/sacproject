class_name AbilityCatalog
extends Resource

## F126 (RFC-030 030o-a): the one owner of «which active ability has an effect scene of its own». Each entry is a SpellTag
## of @ABI (as AbilityType.tag holds it, case and all: `HSba` Protector is not `hsba` Life Shield) and the packed scene of
## an AbilityEffect that holds that ability's own rule and does it. ActiveAbility instances it under itself as "Effect";
## cooldown, mana and the spend stay in ActiveAbility. A tag that is not here keeps ActiveAbility's own branch.
## A new ability is a new entry here and a new scene under scenes/world/units/abilities/, never a new branch elsewhere.

## SpellTag (String) → PackedScene whose root is an AbilityEffect.
@export var effects: Dictionary = {}


## The effect scene of `tag`, or null when the tag has none (or the entry is not a PackedScene).
func scene_for(tag: String) -> PackedScene:
	return effects.get(tag) as PackedScene if effects.has(tag) else null


func has_effect(tag: String) -> bool:
	return scene_for(tag) != null
