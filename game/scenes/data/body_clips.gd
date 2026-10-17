@tool
class_name BodyClips
extends Resource

## RFC-023 (023b): which clip of a skeletal model plays each ROLE of a body (idle, run, attack...).
## A model is one .glb with every clip; the role is what the game asks for, the tag is what the .glb calls it.
## One .tres per model with special aliases (data/bodies/clips/); the rest derives them from CreatureType (023c).
## A role without a tag here (or whose tag the model lacks) falls back to idle, like the baked player did.

## Roles the BodyRig state machine has a state for (body_rig.tscn). A new role needs a state there.
const ROLES: PackedStringArray = ["idle", "run", "attack", "shoot", "cast", "hit", "death", "held", "thrash", "rise", "fly"]
## Roles that end by themselves and hand the body back to idle; the others loop or hold (death).
const ONE_SHOT_ROLES: PackedStringArray = ["attack", "shoot", "cast", "hit", "rise"]

## Model tag, as in assets/original/models/index.json (eorc, jnwr...).
@export var model := "":
	set(value):
		model = value
		emit_changed()
## role -> clip tag (String -> String).
@export var roles: Dictionary = {}:
	set(value):
		roles = value
		emit_changed()
## Roles that repeat. The rest play once and hold their last frame (or return to idle, see ONE_SHOT_ROLES).
@export var looping_roles: PackedStringArray = ["idle", "run", "held", "thrash", "fly"]


## The clip tag of `role`, "" when the model has none.
func tag_for(role: String) -> String:
	return str(roles.get(role, ""))


func is_looping(role: String) -> bool:
	return looping_roles.has(role)
