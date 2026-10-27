class_name DivineSight
extends AbilityEffect

## F133 (RFC-030 030v-a) moved the Ranger's Divine Sight (eesd) here; F165 makes it faithful. sacengine divineSight (state.d:13102-13109,
## called by useAbility, 13527-13528): no target and no preparation. The eye is born 2 m ahead of the user (along its facing), on the
## land (or a building top) there, with velocity speed · facing, and the ability applies (AbilitySlot spends the 50 mana and starts
## the 25 s cooldown). What the eye does is DivineSightEye's (updateDivineSight, 25161-25214). The SPEL has flags 0, so the UI sends
## the use at once, without arming a target (MatchCommand._use_ability).
## Divergence (declared): none in the rule; the original plays no sound at the cast either.

## The eye (divine_sight_eye.tscn), put in the shot container through the ShotSpawner (replicated like a shot).
@export var eye_scene: PackedScene
## sacengine `object.position + 2.0f * direction`.
@export var spawn_ahead := 2.0


## No target is needed or looked at: a click with a body or a spot works the same.
func status(_target_pos: Vector3, _target: Node3D) -> String:
	return "" if user != null and ability != null and eye_scene != null else Refusal.BAD_TARGET


func fire(_target_pos: Vector3, _target: Node3D) -> bool:
	if not is_multiplayer_authority() or user == null or ability == null or eye_scene == null:
		return false
	var spawner := user.get_tree().get_first_node_in_group(&"shot_spawner") as ShotSpawner
	if spawner == null:
		push_warning("DivineSight: no hay ShotSpawner en el mundo.")
		return false
	var ahead := user.facing_flat()
	var at := user.global_position + spawn_ahead * ahead
	at.y = RangedShot.land_height(user, at)
	if at.y == -INF:
		at.y = user.global_position.y
	var velocity := ability.speed_m_s * ahead
	var eye := spawner.spawn_scene({
		"scene": eye_scene.resource_path, "prefix": "Eye",
		"x": at.x, "y": at.y, "z": at.z,
		"vx": velocity.x, "vy": velocity.y, "vz": velocity.z,
		"slot": int(user.get("owner_slot")), "tag": ability.tag, "shooter": who(user),
	})
	if DebugLog.on(&"effects"):
		print("ojo %s de %s (tick %d)" % [eye.name if eye else "?", who(user), MatchClock.now()])
	return eye != null
