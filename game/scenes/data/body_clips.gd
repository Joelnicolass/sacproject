@tool
class_name BodyClips
extends Resource

## RFC-023 (023b): which clip of a skeletal model plays each ROLE of a body (idle, run, attack...).
## A model is one .glb with every clip; the role is what the game asks for, the tag is what the .glb calls it.
## One .tres per model with special aliases (data/bodies/clips/); the rest derives them from CreatureType (023c).
## A role without a tag here (or whose tag the model lacks) falls back to idle, like the baked player did.

## Roles the BodyRig state machine has a state for (body_rig.tscn). A new role needs a state there.
## The unit roles after "rise"/"fly" (023c): the peasant clips, the hybrid fliers' takeoff/land, the stun clips and the
## idle gesture (sacengine plays idle0 now and then on top of the rest pose, state.d:7957-7992).
const ROLES: PackedStringArray = ["idle", "run", "attack", "shoot", "cast", "hit", "death", "held", "thrash", "rise", "fly",
	"cower", "talk_cower", "work", "takeoff", "land", "knock", "get_up", "fly_damage", "gesture"]
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


## A BodyClips made at run time from a role -> tag map (a unit's CreatureType gives it, see UnitClipRoles): every role
## repeats, because the clip clock wraps whatever it plays (ClipClock). Not saved anywhere.
static func from_roles(model_tag: String, role_to_tag: Dictionary) -> BodyClips:
	var made := BodyClips.new()
	made.model = model_tag
	made.roles = role_to_tag.duplicate()
	made.looping_roles = PackedStringArray(role_to_tag.keys())
	return made


## The clip tag of `role`, "" when the model has none.
func tag_for(role: String) -> String:
	return str(roles.get(role, ""))


func is_looping(role: String) -> bool:
	return looping_roles.has(role)
