extends MeshInstance3D

@export var distance: float = 12.0
@export var subject: Node3D
## Used when subject is empty: the world's local wizard (spawned at runtime).
@export var world: Node
@export var camera: Camera3D

const _ALMOST_POSITIVE_X := 0.85

@onready var _goal_point: Marker3D = %GoalPoint


func _ready() -> void:
	visible = false
	call_deferred("_place_after_ground")


func _get_configuration_warnings() -> PackedStringArray:
	var missing := PackedStringArray()
	if subject == null and world == null:
		missing.append("Falta el mago.")
	if camera == null:
		missing.append("Falta la cámara.")
	return missing


func _place_after_ground() -> void:
	await get_tree().physics_frame
	if _place():
		return
	await get_tree().physics_frame
	_place()


func _place() -> bool:
	if _subject() == null or camera == null:
		return false
	var origin := subject.global_position
	var aimed := origin + _horizontal_right() * distance
	var grounded := _sample_ground(aimed, origin.y)
	_seat(grounded["point"])
	visible = true
	return grounded["hit"]


func _horizontal_right() -> Vector3:
	var axis := camera.global_basis.x
	var flat := Vector3(axis.x, 0.0, axis.z)
	if flat.length_squared() < 0.000001:
		flat = Vector3.RIGHT
	else:
		flat = flat.normalized()
	# El campesino está a +6 m en X. Si el derecho mira casi todo hacia +X, el poste va al otro lado.
	if flat.dot(Vector3.RIGHT) > _ALMOST_POSITIVE_X:
		flat = -flat
	return flat


func _sample_ground(at: Vector3, fallback_y: float) -> Dictionary:
	var point := Vector3(at.x, fallback_y, at.z)
	var world := get_world_3d()
	if world == null:
		return {"hit": false, "point": point}
	var from := Vector3(at.x, fallback_y + 200.0, at.z)
	var to := Vector3(at.x, fallback_y - 200.0, at.z)
	var hit := world.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty():
		return {"hit": false, "point": point}
	return {"hit": true, "point": hit.position}


func _seat(ground: Vector3) -> void:
	var half := _half_height()
	if _goal_point:
		_goal_point.position = Vector3(0.0, -half, 0.0)
	global_position = ground + Vector3(0.0, half, 0.0)


func _half_height() -> float:
	var pole := mesh as CylinderMesh
	if pole:
		return pole.height * 0.5
	var box := mesh as BoxMesh
	if box:
		return box.size.y * 0.5
	return 1.0


func _subject() -> Node3D:
	if subject == null and world and world.has_method("local_wizard"):
		subject = world.call("local_wizard")
	return subject
