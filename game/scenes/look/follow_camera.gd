@tool
class_name FollowCamera
extends Node3D

## Keeps itself a little ahead of the camera that is drawing (the game's, or the editor's in the 3D
## view), level with it, so what hangs below it (rain, the air life) always surrounds what the
## player sees. It does nothing else.

## How far ahead of the camera, on the ground plane, along where it looks.
@export_range(0.0, 200.0, 0.5, "suffix:m") var ahead_m: float = 25.0


func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_priority = 15001  # after the camera (15000), which it follows


func _process(_delta: float) -> void:
	var camera := _camera()
	if camera == null:
		return
	var forward := -camera.global_basis.z
	forward.y = 0.0
	var ahead := forward.normalized() * ahead_m if forward.length_squared() > 1e-6 else Vector3.ZERO
	global_position = camera.global_position + ahead


func _camera() -> Camera3D:
	if Engine.is_editor_hint() and Engine.has_singleton(&"EditorInterface"):
		# by name: the class does not exist in an export
		var editor: Object = Engine.get_singleton(&"EditorInterface")
		var viewport: SubViewport = editor.get_editor_viewport_3d(0) if editor else null
		return viewport.get_camera_3d() if viewport else null
	return get_viewport().get_camera_3d() if is_inside_tree() else null
