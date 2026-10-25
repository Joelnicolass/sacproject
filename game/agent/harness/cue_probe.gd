extends Node

## Observation helper for the F80 flows (RFC-025c). It never changes the match: it points the world
## camera's debug pointer (what the `select` action and the cursor probe read) and turns the cursor
## mirror on, because a window capture does not contain the system cursor.
##
##   mirror(on)    CommandCue.mirror_cursor: the hardware cursor's image is also drawn in the viewport.
##   aim_sky()     the pointer goes to a spot whose ray hits nothing: a screen pixel when one exists,
##                 else above the top edge (the RTS camera looks down at the ground).
##   aim_ground()  the pointer goes to a screen pixel whose ray lands on the ground with no body within
##                 `clear_m` (a big wizard right in front of the camera hides the screen center).
##   aim_on(name)  the pointer goes to a pixel whose ray hits the body named `name`; "hidden <name>" and
##                 no change when every sampled pixel hits something in front of it.
##   report()      "cursor armed icon kind" as a line for the log.

const BODY_GROUPS: PackedStringArray = ["unit", "wizard", "structure", "corpse", "soul_target", "doctor"]

@export var clear_m := 3.0

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
	return _cast(cam, screen).is_empty()


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


func aim_ground() -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return "no camera"
	var view := get_viewport().get_visible_rect().size
	for column: float in [0.5, 0.35, 0.65, 0.2, 0.8]:
		for y in range(int(view.y) - 80, int(view.y * 0.4), -40):
			var screen := Vector2(view.x * column, float(y))
			var hit := _cast(cam, screen)
			if hit.is_empty() or _is_body(hit["collider"]) or _near_body(hit["position"]):
				continue
			cam.set("debug_pointer", screen)
			return "%d,%d" % [screen.x, screen.y]
	return "no ground"


func aim_on(body_name: String) -> String:
	var cam := get_viewport().get_camera_3d()
	var body := _scene().find_child(body_name, true, false) as Node3D
	if cam == null or body == null:
		return "missing %s" % body_name
	var base := body.global_transform.origin
	for lift: float in [1.0, 0.5, 1.5, 2.0, 0.25, 2.5]:
		for side: float in [0.0, -0.3, 0.3]:
			var spot := base + Vector3.UP * lift + cam.global_transform.basis.x * side
			if cam.is_position_behind(spot):
				continue
			var screen := cam.unproject_position(spot)
			var hit := _cast(cam, screen)
			if not hit.is_empty() and hit["collider"] == body:
				cam.set("debug_pointer", screen)
				return "%d,%d" % [screen.x, screen.y]
	return "hidden %s" % body_name


func _cast(cam: Camera3D, screen: Vector2) -> Dictionary:
	var origin := cam.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + cam.project_ray_normal(screen) * 10000.0)
	query.collision_mask = 15
	return cam.get_world_3d().direct_space_state.intersect_ray(query)


func _is_body(collider: Object) -> bool:
	if not collider is Node:
		return false
	for group in BODY_GROUPS:
		if (collider as Node).is_in_group(group):
			return true
	return false


func _near_body(point: Vector3) -> bool:
	for group in BODY_GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node3D and (node as Node3D).global_transform.origin.distance_to(point) < clear_m:
				return true
	return false
