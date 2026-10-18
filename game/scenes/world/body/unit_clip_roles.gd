class_name UnitClipRoles
extends RefCounted

## RFC-023 (023c): which clip tag a creature unit plays for each ROLE, read from its CreatureType (creatures.json). The
## unit body hands this map to its BodyAnimator; the roles are the ones BodyClips.ROLES has a state for.
## Presentation only: the simulation takes its ticks from CreatureType and never reads these tags.

## Peasant, flight and stun roles come from these CreatureType dictionaries (role -> {tag, frames, framerate}).
const EXTRA_ROLES: PackedStringArray = ["cower", "talk_cower", "work"]
const FLIGHT_ROLES: PackedStringArray = ["takeoff", "fly", "land", "hover"]
const STUN_ROLES: PackedStringArray = ["knock", "get_up", "fly_damage"]
## RFC-023f: how it dies, on the ground and in the air.
const DEATH_ROLES: PackedStringArray = ["death", "fly_death"]


## role -> tag for `type` drawn with `model`. A role whose tag is "" has no clip: the body rests on idle.
static func for_type(type: CreatureType, model: String) -> Dictionary:
	var idle_tag := str(type.idle_animation.get("tag", "")) if type else ""
	var rest_tag := _rest_tag(type, model, idle_tag)
	var run: Dictionary = type.walk_animation if type else {}
	if int(run.get("frames", 0)) <= 1 and type:
		run = type.run_animation
	var attack_tag := ""
	if type and not type.melee_animations.is_empty():
		attack_tag = str((type.melee_animations[0] as Dictionary).get("tag", ""))
	var roles := {"idle": rest_tag, "run": str(run.get("tag", "")), "attack": attack_tag}
	# sacengine plays idle0 now and then on top of the rest pose (state.d:7957-7992): the gesture. Only when idle0 is not the rest.
	if BodyCatalog.has_skeletal(model) and rest_tag != idle_tag and not idle_tag.is_empty():
		roles["gesture"] = idle_tag
	if type == null:
		return roles
	# RFC-028c peasant clips, F116 takeoff/fly/land of a hybrid flier, F120 knock/get_up/fly_damage.
	var sets: Array = [[type.extra_animations, EXTRA_ROLES], [type.flight_animations, FLIGHT_ROLES], [type.stun_animations, STUN_ROLES], [type.death_animations, DEATH_ROLES]]
	for pair: Array in sets:
		for role: String in pair[1]:
			var clip: Variant = (pair[0] as Dictionary).get(role, {})
			var tag := str((clip as Dictionary).get("tag", "")) if clip is Dictionary else ""
			if not tag.is_empty():
				roles[role] = tag
	return roles


## F134 / RFC-023: the clip a creature stands in at rest. sacengine plays stance1 at the start of every idle loop
## (frame 0 -> stance1, or stance2 when damaged); idle0..3 are gestures. A model with no stance1 clip rests on idle0.
static func _rest_tag(type: CreatureType, model: String, idle_tag: String) -> String:
	if not BodyCatalog.has_skeletal(model):
		return _baked_rest_tag(model, idle_tag)
	var stance := str(type.stance_animation.get("tag", "")) if type else ""
	if stance.is_empty() or stance == idle_tag or not ClipClock.has_clip(model, stance):
		return idle_tag
	return stance


## The baked bodies (no skeleton for the model, or `--baked-bodies`): the old rule, F134. The body was baked from
## BodyCatalog's pose_source (stance1 for book creatures of level 2+, idle0 below); the idle role plays that clip.
static func _baked_rest_tag(model: String, idle_tag: String) -> String:
	var rest := str(BodyCatalog.info(model).get("pose_source", ""))
	if rest.is_empty() or rest == idle_tag:
		return idle_tag
	return rest if ClipClock.has_clip(model, rest) else idle_tag
