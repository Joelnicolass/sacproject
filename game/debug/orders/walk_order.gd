extends Node

@export var subject: Node3D
## Used when subject is empty: the world's local wizard (spawned at runtime).
@export var world: Node
@export var camera: Camera3D
@export var goal_point: Node3D


func _ready() -> void:
	add_to_group("walk_order")
	%WalkState.text = "Quieto"
	_subject()
	if subject and subject.has_signal("walk_changed"):
		subject.walk_changed.connect(_on_walk_changed)


func _get_configuration_warnings() -> PackedStringArray:
	var missing := PackedStringArray()
	if subject == null and world == null:
		missing.append("Falta el mago.")
	if goal_point == null:
		missing.append("Falta el poste.")
	return missing


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("order_units"):
		return
	if not event is InputEventMouse:
		order_move(_post_point())
		return
	var picked: Variant = _terrain_point(event)
	if picked == null:
		order_move(_post_point())
	else:
		order_move(picked)


func order_move(goal: Vector3) -> void:
	if subject and subject.has_method("request_walk"):
		subject.request_walk(goal)


func _on_walk_changed(walking: bool) -> void:
	%WalkState.text = "Caminando" if walking else "Quieto"


func _post_point() -> Vector3:
	if goal_point == null:
		return Vector3.ZERO
	return goal_point.global_position


func _terrain_point(event: InputEvent) -> Variant:
	if camera == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	if event is InputEventMouse:
		mouse = (event as InputEventMouse).position
	var origin := camera.project_ray_origin(mouse)
	var normal := camera.project_ray_normal(mouse)
	var world := camera.get_world_3d()
	if world == null:
		return null
	var query := PhysicsRayQueryParameters3D.create(origin, origin + normal * 10000.0)
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.position


func _subject() -> Node3D:
	if subject == null and world and world.has_method("local_wizard"):
		subject = world.call("local_wizard")
	return subject
