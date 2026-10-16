extends Node

## Observation only (F93 / RFC-028b playtest). Moves no actor, edits no rule, never touches the selection
## or the inspector state.
##   line_up(front, back, dist, height)  frames the world camera on `front` from the side opposite `back`,
##                                       so `front` stands between the camera and `back` on screen.
##   frame(spec, dist, height, yaw)      frames the camera on a body (yaw: side the camera stands on).
##   stop()                              hands the camera back.
##   aim(spec, lift)                     the world camera's debug pointer (what `select` uses) on a body;
##                                       reports the first collider under it (mask 15) and the next one
##                                       behind it, to prove what the click would meet.
##   watch_inspector()                   logs every %Inspector.inspected_changed with the frame and, on
##                                       null, whether the last inspected body was dead or gone.
##   events()                            the log.
## back may be "near:<tag>" (nearest map building with that tag). spec: a node name, "wizard" (local wizard), "altar" (nearest altar to the wizard), "corpse" (first corpse).

var _front := ""
var _back := ""
var _yaw := 0.0
var _dist := 10.0
var _height := 2.0
var _lift := 1.0
var _events: PackedStringArray = []
var _last: Node3D


func _ready() -> void:
	process_priority = 1001


func _root() -> Node:
	return get_tree().current_scene


func _cam() -> Camera3D:
	return get_viewport().get_camera_3d()


func _find(spec: String) -> Node3D:
	var root := _root()
	if root == null:
		return null
	match spec:
		"wizard":
			return get_tree().get_first_node_in_group("local_wizard") as Node3D
		"corpse":
			for node in get_tree().get_nodes_in_group("corpse"):
				if node is Node3D:
					return node as Node3D
			return null
		"altar":
			var wizard := get_tree().get_first_node_in_group("local_wizard") as Node3D
			var best: Node3D = null
			var best_d := INF
			for node in get_tree().get_nodes_in_group(&"altar"):
				var d := (node as Node3D).global_transform.origin.distance_to(wizard.global_transform.origin) if wizard else 0.0
				if d < best_d:
					best_d = d
					best = node as Node3D
			return best
	return root.find_child(spec, true, false) as Node3D


func line_up(front: String, back: String, dist: float, height: float, lift: float = 1.0) -> String:
	var a := _find(front)
	var b := _nearest_tag(a, back.substr(5)) if back.begins_with("near:") else _find(back)
	if a == null or b == null:
		return "falta %s o %s" % [front, back]
	var away := a.global_transform.origin - b.global_transform.origin
	away.y = 0.0
	_front = front
	_back = str(b.name)
	_yaw = atan2(away.x, away.z)
	_dist = dist
	_height = height
	_lift = lift
	return "%s (%.1f,%.1f) delante de %s (%.1f,%.1f), %.1f m" % [a.name, a.global_transform.origin.x, a.global_transform.origin.z, b.name, b.global_transform.origin.x, b.global_transform.origin.z, away.length()]


## The map building tagged `tag` nearest to `a` ("near:jhut").
func _nearest_tag(a: Node3D, tag: String) -> Node3D:
	if a == null:
		return null
	var best: Node3D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("map_building"):
		if str(node.get("tag")) != tag:
			continue
		var d := (node as Node3D).global_transform.origin.distance_to(a.global_transform.origin)
		if d < best_d:
			best_d = d
			best = node as Node3D
	return best


func frame(spec: String, dist: float, height: float, yaw_deg: float, lift: float = 1.0) -> String:
	_front = spec
	_back = ""
	_yaw = deg_to_rad(yaw_deg)
	_dist = dist
	_height = height
	_lift = lift
	var a := _find(spec)
	return "encuadre %s" % (str(a.name) if a else "falta")


func stop() -> String:
	_front = ""
	return "camara libre"


func _process(_delta: float) -> void:
	if _front.is_empty():
		return
	var a := _find(_front)
	var cam := _cam()
	if a == null or cam == null:
		return
	var center := a.global_transform.origin + Vector3.UP * _lift
	cam.position = center + Vector3(sin(_yaw), 0.0, cos(_yaw)) * _dist + Vector3.UP * _height
	cam.look_at(center, Vector3.UP)


func aim(spec: String, lift: float = 1.0) -> String:
	var a := _find(spec)
	var cam := _cam()
	if a == null or cam == null:
		return "falta %s" % spec
	var screen := cam.unproject_position(a.global_transform.origin + Vector3.UP * lift)
	cam.set("debug_pointer", screen)
	var first := _ray(cam, screen, [])
	var behind := {}
	if not first.is_empty() and first.collider is CollisionObject3D:
		behind = _ray(cam, screen, [(first.collider as CollisionObject3D).get_rid()])
	return "pointer (%d,%d) en %s: primero=%s detras=%s cam_d=%.1f" % [screen.x, screen.y, a.name, _describe(first), _describe(behind),
		cam.global_transform.origin.distance_to(a.global_transform.origin)]


func _ray(cam: Camera3D, screen: Vector2, skip: Array) -> Dictionary:
	var origin := cam.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + cam.project_ray_normal(screen) * 10000.0)
	query.collision_mask = 15
	query.exclude = skip
	return cam.get_world_3d().direct_space_state.intersect_ray(query)


func _describe(hit: Dictionary) -> String:
	if hit.is_empty():
		return "nada"
	var node := hit.collider as Node
	var groups: PackedStringArray = []
	for group in ["unit", "wizard", "corpse", "structure", "map_building", "altar"]:
		if node.is_in_group(group):
			groups.append(group)
	return "%s[%s]" % [node.name, ",".join(groups) if not groups.is_empty() else "suelo"]


func watch_inspector() -> String:
	var inspector := _root().find_child("Inspector", true, false)
	if inspector == null:
		return "sin Inspector"
	if not inspector.is_connected("inspected_changed", _on_inspected):
		inspector.connect("inspected_changed", _on_inspected)
	return "mirando %s" % inspector.get_path()


func _on_inspected(body: Node3D) -> void:
	var frame_no := Engine.get_physics_frames()
	if body != null:
		_last = body
		_events.append("f%d inspecciona %s" % [frame_no, body.name])
		return
	if _last == null or not is_instance_valid(_last):
		_events.append("f%d null (el anterior ya no existe)" % frame_no)
		return
	var health: Variant = _last.get_node_or_null("Health")
	var dead := bool(health.is_dead()) if health else false
	_events.append("f%d null; %s vida=%s muerto=%s" % [frame_no, _last.name, health.get("current") if health else "-", dead])


func events() -> String:
	return " | ".join(_events)
