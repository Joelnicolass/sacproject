extends Node

## Observation helper for the F80 flows (RFC-025c). It never changes the match: it points the world
## camera's debug pointer (what the `select` action and the cursor probe read) and turns the cursor
## mirror on, because a window capture does not contain the system cursor.
##
##   mirror(on)    CommandCue.mirror_cursor: the hardware cursor's image is also drawn in the viewport.
##   aim_sky()     the pointer goes to a spot whose ray hits nothing: a screen pixel when one exists,
##                 else above the top edge (the RTS camera looks down at the ground).
##   report()      "cursor armed icon kind" as a line for the log.

func _scene() -> Node:
	return get_tree().current_scene


func mirror(on: bool) -> String:
	var cue := _scene().find_child("CommandCue", true, false)
	if cue == null:
		return "no CommandCue"
	cue.set("mirror_cursor", on)
	return "ok"


func aim_sky() -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return "no camera"
	var view := get_viewport().get_visible_rect().size
	var spot := Vector2(view.x * 0.5, -4000.0)
	for y in range(40, int(view.y * 0.5), 40):
		var screen := Vector2(view.x * 0.5, float(y))
		if _hits_nothing(cam, screen):
			spot = screen
			break
	cam.set("debug_pointer", Vector2(spot.x, spot.y))
	return "%d,%d" % [spot.x, spot.y]


func _hits_nothing(cam: Camera3D, screen: Vector2) -> bool:
	var origin := cam.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + cam.project_ray_normal(screen) * 10000.0)
	query.collision_mask = 15
	return cam.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func report() -> String:
	var skin := _scene().find_child("CursorSkin", true, false)
	var battle := _scene().find_child("Battle", true, false)
	var probe := _scene().find_child("TargetProbe", true, false)
	if skin == null or battle == null or probe == null:
		return "missing nodes"
	var icon: Texture2D = battle.get("armed_icon")
	var line := "cursor=%s armed=%s icon=%s kind=%s applied=%d" % [skin.get("current"), battle.get("armed"), icon.resource_path.get_file() if icon else "", probe.get("kind"), skin.get("apply_count")]
	print("CUE_REPORT ", line)
	return line
