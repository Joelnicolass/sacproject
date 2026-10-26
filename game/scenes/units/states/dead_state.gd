class_name DeadState
extends UnitState

## DEAD: the body stops acting (no target, no attacks) and becomes a corpse that falls until it rests on the floor.
## Leaving it (a Convert doctor pumped the creature back to life) makes it a creature again. It does not touch the
## health bar (the bar hides itself) and it does not animate the body: CorpseLook decides how the death looks.


func present(animate: bool) -> void:
	body.target = null
	body.engagement.cancel_attacks()
	body.corpse().lay_down(body, _death_role(), not animate)


func exit() -> void:
	body.corpse().stand_up(body)
	super.exit()


## The corpse stops moving once it rested; until then it falls like any body.
func rests_on_floor() -> bool:
	return body.corpse().is_settled


## The clip that lays the body down ("" = none: baked meshes, dedicated server, no dying clip).
func _death_role() -> String:
	for role: String in ["fly_death" if body.is_flying() else "death", "death"]:
		if body.clip_pose.is_skeletal() and body.has_clip(role):
			return role
	return ""
