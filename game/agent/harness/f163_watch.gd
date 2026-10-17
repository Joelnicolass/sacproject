extends Node

## F163 (RFC-030 030w-f): read-only observer for the window run of debug/f163_phoenix_shield. It moves, orders and damages nothing: it
## re-frames the screen camera on the pair of Phoenixes (like a player scrolling the view; the bench camera is fixed).
##
##   look(ox, oy, oz)   from now on, every frame, the camera sits at the midpoint of Phoenix1, Phoenix2 and Druid1 + offset and looks at it.
##   report()           the bodies' life now.

var _offset := Vector3(0.0, 8.0, 18.0)
var _on := false


func look(ox: float, oy: float, oz: float) -> String:
	_offset = Vector3(ox, oy, oz)
	_on = true
	return "ok"


func _process(_delta: float) -> void:
	if not _on:
		return
	var camera := get_viewport().get_camera_3d()
	var sum := Vector3.ZERO
	var count := 0
	for name_ in ["Phoenix1", "Phoenix2", "Druid1"]:
		var body := get_tree().root.find_child(name_, true, false) as Node3D
		if body != null:
			sum += body.global_transform.origin
			count += 1
	if camera == null or count == 0:
		return
	var middle := sum / float(count)
	camera.global_transform = Transform3D(camera.global_transform.basis, middle + _offset)
	camera.look_at(middle + Vector3.UP * 4.0, Vector3.UP)


func report() -> String:
	var parts := []
	for name_ in ["Phoenix1", "Phoenix2", "Phoenix3", "Phoenix4", "Druid1"]:
		var body := get_tree().root.find_child(name_, true, false)
		var health := body.get_node_or_null("Health") if body else null
		parts.append("%s %s" % [name_, "%.0f" % float(health.get("current")) if health else "-"])
	return "; ".join(parts)
