class_name DeadState
extends UnitState

## DEAD (dying + dead): the corpse lies down, by a clip when the model has one (RFC-023f) or by Corpse's Tween. Leaving
## it (a Convert doctor pumped the creature back to life, RFC-020e) stands the corpse up.


func present(animate: bool) -> void:
	body.target = null
	body.cancel_attacks()
	body.get_node("HealthBar").visible = false
	var visual := body.get_node_or_null("Tilt/Mesh")
	var radius := float(visual.call("body_radius")) if visual else 0.3
	var role := _death_role()
	if not role.is_empty():
		body.clip_pose.call("play", role, true) if animate else body.clip_pose.call("play_ended", role)
	body.get_node("Corpse").call("lay_down", body, radius, animate, not role.is_empty())


func exit() -> void:
	body.get_node("HealthBar").visible = true
	body.get_node("Corpse").call("stand_up", body)
	super.exit()


func rests_on_floor() -> bool:
	return true


## The clip that lays the body down ("" = a Tween does: baked meshes, dedicated server, no dying clip).
func _death_role() -> String:
	for role: String in ["fly_death" if body.is_flying() else "death", "death"]:
		if bool(body.clip_pose.call("is_skeletal")) and body.has_clip(role):
			return role
	return ""
