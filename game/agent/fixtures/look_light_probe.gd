extends "res://debug/look_gallery.gd"

## Measurement helper (agent only): prints where each gallery body is on screen
## (`LOOKPROBE <cam> <body> <x> <y>`, pixels of the 1280x720 capture) when the camera changes.

var _last_cam := Transform3D()


func _process(_delta: float) -> void:
	if view_camera == null or view_camera.global_transform == _last_cam:
		return
	_last_cam = view_camera.global_transform
	for body in bodies.get_children():
		var pos := (body as Node3D).global_position + Vector3(0, 1.2, 0)
		var screen := view_camera.unproject_position(pos)
		var size := get_viewport().get_visible_rect().size
		print("LOOKPROBE %d %s %.0f %.0f %.0f %.0f" % [_camera_index, body.name, screen.x, screen.y, size.x, size.y])
