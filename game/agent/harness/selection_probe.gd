extends Node

## Observation helper for the F78 selection flows (RFC-025). Never moves an actor and never changes
## the selection: it only aims the world camera's debug pointer (what the `select` action uses) at
## a point on the screen, and reports what is under a pixel.
##
##   aim_empty()      a ground point a few meters off the cluster of own creatures with no body
##                    within `clear_m`; the pointer goes there. Returns "x,y" (screen pixels).
##   aim_empty(far_m) the same, but at least far_m from the cluster's center (rings far_m, 1.25x, 1.5x),
##                    at least `far_edge_px` inside the view (off the camera's edge scroll) and where the
##                    screen ray lands within `far_hit_m` of the spot. Returns "x,y d=<m>" (F87 B1).
##   aim_body(name)   the pointer goes on the body named `name` (a creature or a wizard).
##   under(x, y)      "ground", "none" or "body:<Name>" at that pixel (no pointer change).

@export var clear_m := 3.0
@export var margin_m := 8.0
@export var far_edge_px := 110.0
@export var far_hit_m := 6.0


func _camera() -> Camera3D:
	return get_viewport().get_camera_3d()


func _cast(cam: Camera3D, screen: Vector2, mask: int) -> Dictionary:
	var origin := cam.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + cam.project_ray_normal(screen) * 10000.0)
	query.collision_mask = mask
	return cam.get_world_3d().direct_space_state.intersect_ray(query)


func _bodies() -> Array:
	var all: Array = []
	for group in ["unit", "wizard", "structure", "corpse"]:
		all.append_array(get_tree().get_nodes_in_group(group))
	return all


func aim_empty(far_m: float = 0.0) -> String:
	var cam := _camera()
	if cam == null:
		return "no camera"
	var own: Array[Vector3] = []
	var center := Vector3.ZERO
	for node in get_tree().get_nodes_in_group("unit"):
		if int(node.get("owner_slot")) == MpKit.local_slot():
			own.append((node as Node3D).global_transform.origin)
			center += own[-1]
	if own.is_empty():
		return "no own creatures"
	center /= own.size()
	var radius := 0.0
	for at in own:
		radius = maxf(radius, at.distance_to(center))
	var view := get_viewport().get_visible_rect().size
	var bodies := _bodies()
	var rings: Array = [margin_m, margin_m * 1.5, margin_m * 2.0]
	var steps := 16
	var edge := 40.0
	if far_m > 0.0:
		rings = [far_m, far_m * 1.25, far_m * 1.5]
		radius = 0.0
		steps = 64
		edge = far_edge_px
	for ring: float in rings:
		for step in steps:
			var angle := TAU * step / float(steps)
			var spot: Vector3 = center + Vector3(sin(angle), 0.0, cos(angle)) * (radius + float(ring))
			var ground := _cast_down(cam, spot)
			if ground.is_empty():
				continue
			var point: Vector3 = ground["position"]
			if cam.is_position_behind(point):
				continue
			var screen := cam.unproject_position(point)
			if screen.x < edge or screen.y < edge or screen.x > view.x - edge or screen.y > view.y - edge:
				continue
			if _near_body(bodies, point):
				continue
			var hit := _cast(cam, screen, 15)
			if hit.is_empty() or not _is_ground(hit["collider"]):
				continue
			if far_m > 0.0 and (hit["position"] as Vector3).distance_to(point) > far_hit_m:
				continue
			cam.set("debug_pointer", screen)
			if far_m > 0.0:
				var at: Vector3 = hit["position"]
				return "%d,%d d=%.1f at=(%.0f, %.0f)" % [screen.x, screen.y, Vector2(at.x - center.x, at.z - center.z).length(), at.x, at.z]
			return "%d,%d" % [screen.x, screen.y]
	return "no empty spot"


func aim_body(body_name: String, lift: float = 1.0) -> String:
	var cam := _camera()
	var scene := get_tree().current_scene
	var body := scene.find_child(body_name, true, false) as Node3D if scene else null
	if cam == null or body == null:
		return "missing %s" % body_name
	var screen := cam.unproject_position(body.global_transform.origin + Vector3.UP * lift)
	cam.set("debug_pointer", screen)
	return "%d,%d" % [screen.x, screen.y]


func under(x: float, y: float) -> String:
	var cam := _camera()
	if cam == null:
		return "no camera"
	var hit := _cast(cam, Vector2(x, y), 15)
	if hit.is_empty():
		return "none"
	var body: Object = hit["collider"]
	if _is_ground(body):
		return "ground"
	return "body:%s" % (body as Node).name


func _cast_down(cam: Camera3D, spot: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 200.0, spot + Vector3.DOWN * 400.0)
	query.collision_mask = 1
	return cam.get_world_3d().direct_space_state.intersect_ray(query)


func _near_body(bodies: Array, point: Vector3) -> bool:
	for node in bodies:
		if (node as Node3D).global_transform.origin.distance_to(point) < clear_m:
			return true
	return false


func _is_ground(body: Object) -> bool:
	if not body is Node:
		return false
	var node := body as Node
	for group in ["unit", "wizard", "structure", "corpse", "soul_target", "doctor"]:
		if node.is_in_group(group):
			return false
	return true
