extends "res://agent/fixtures/look_light_probe.gd"

## 022c: camera outside the map rim looking inward, so the cliff walls and slopes show their back faces.
func _show_camera() -> void:
	view_camera.global_position = Vector3(905.0, 30.0, 1275.0)
	view_camera.look_at(Vector3(960.0, 22.0, 1275.0), Vector3.UP)
