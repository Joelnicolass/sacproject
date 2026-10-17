extends Node

## F162 (RFC-030 030w-c): read-only observer for the window run of debug/f162_waves. It moves, orders and damages nothing: it re-frames
## the screen camera on the wave in flight, like a player scrolling the view (the bench camera is fixed).
##
##   follow(kind, ox, oy, oz)   from now on, every frame, the camera sits at the wave + offset and looks at it. kind: "ignite" (the
##                              Spitfire's, the one with an IgniteTouch child) or "plain" (the Gargoyle's, no touch child).
##   report()                   the waves alive now: name, position, radius of the update and bodies touched.

var _kind := ""
var _offset := Vector3(-8.0, 9.0, 16.0)
var _last := Vector3.ZERO
var _has_last := false


func follow(kind: String, ox: float, oy: float, oz: float) -> String:
	_kind = kind
	_offset = Vector3(ox, oy, oz)
	return "ok"


func _process(_delta: float) -> void:
	if _kind.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	var wave := _find()
	if camera == null:
		return
	if wave != null:
		_last = (wave.get_parent() as Node3D).global_transform.origin
		_has_last = true
	if _has_last:
		camera.global_transform = Transform3D(camera.global_transform.basis, _last + _offset)
		camera.look_at(_last, Vector3.UP)


func _find() -> GrowingWave:
	for shot in get_tree().root.find_children("*", "RangedShot", true, false):
		var wave := _wave_of(shot)
		if wave == null:
			continue
		var ignites := false
		for child in wave.get_children():
			ignites = ignites or child is IgniteTouch
		if (_kind == "ignite") == ignites:
			return wave
	return null


func _wave_of(shot: Node) -> GrowingWave:
	for child in shot.get_children():
		if child is GrowingWave:
			return child
	return null


func report() -> String:
	var lines := []
	for shot in get_tree().root.find_children("*", "RangedShot", true, false):
		var wave := _wave_of(shot)
		if wave != null:
			var at := (shot as Node3D).global_transform.origin
			lines.append("%s en (%.1f, %.1f, %.1f) update %d tocados %d" % [shot.name, at.x, at.y, at.z, wave.ticks, wave._touched.size()])
	return "; ".join(lines) if not lines.is_empty() else "ninguna onda"
