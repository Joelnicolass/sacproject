extends Node

## RFC-033 033a: fixed cameras for the before/after captures. Observation only; it moves no actor.
##
##   frame(x, y, z, tx, ty, tz, size)   puts the scene's orthographic "Camera" at (x, y, z) looking at (tx, ty, tz);
##                                      size > 0 also sets the orthographic size (zoom).

func frame(x: float, y: float, z: float, tx: float, ty: float, tz: float, size: float) -> String:
	var root := get_tree().current_scene
	var camera := root.get_node_or_null("Camera") as Camera3D if root else null
	if camera == null:
		return "no Camera"
	camera.position = Vector3(x, y, z)
	camera.look_at(Vector3(tx, ty, tz), Vector3.UP)
	if size > 0.0:
		camera.size = size
	return "ok"


## hide_log(): turns the group scene's text overlay off (it prints frame_ms, which changes every run), so the HUD
## captures can be compared at 0 differing pixels.
func hide_log() -> String:
	var root := get_tree().current_scene
	var label := root.find_child("OrdersLog", true, false) as CanvasItem if root else null
	if label == null:
		return "no OrdersLog"
	label.visible = false
	return "ok"
