extends Node

## Read-only observer for the F156 window run (RFC-030 030s-b: the Blight's Bilemites on lane M of f156_mites). It never moves,
## orders or damages anything: it reads the bodies and the shots and re-frames the screen camera (like a player scrolling the
## view; the bench camera is fixed). The grass covers low shots, so every frame looks down.
##
##   frame_on(name, ox, oy, oz)           screen camera at the body + offset, looking at the body (+1 m).
##   frame_between(a, b, ox, oy, oz)      the camera looks at the middle of two bodies.
##   frame_mites(ox, oy, oz)              the camera looks at the middle of the mites in the air.
##   report(b)                            the body: speed_factor, the mites stuck; the mites in the air.
##   pixels(b)                            screen pixel, size in pixels and contrast (against a ring around it) of every mite
##                                        in the air and stuck on the body.
## Props: tick, rel (ticks since the bench started: Enter).

var tick := 0
var rel := -1
var _start := -1
var _bodies: Dictionary = {}


func _ready() -> void:
	process_physics_priority = 1000


func _find(n: String) -> Node3D:
	if _bodies.has(n) and is_instance_valid(_bodies[n]):
		return _bodies[n] as Node3D
	var found := get_tree().root.find_child(n, true, false) as Node3D
	if found:
		_bodies[n] = found
	return found


func _physics_process(_delta: float) -> void:
	tick = MatchClock.now()
	if _start < 0:
		var runner := get_tree().root.find_child("Runner", true, false)
		if runner and bool(runner.get("_running")):
			_start = tick
	rel = tick - _start if _start >= 0 else -1


func _mites() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for shot in get_tree().root.find_children("*", "RangedShot", true, false):
		if shot.get_node_or_null("MiteHop") != null or shot.find_child("*MiteHop*", true, false) != null:
			out.append(shot as Node3D)
	return out


func report(b: String) -> String:
	var nb := _find(b)
	var line := "PT156 tick %d rel %d · " % [tick, rel]
	if nb == null:
		line += "no %s" % b
	else:
		var cling := Clinging.of(nb)
		line += "%s speed_factor %.4f pegados %s · acaros en el aire %d" % [
			b, float(nb.get("speed_factor")), str(cling.shown) if cling else "-", _mites().size()]
	print(line)
	return line


func _look(target: Vector3, ox: float, oy: float, oz: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		cam.look_at_from_position(target + Vector3(ox, oy, oz), target, Vector3.UP)


func frame_on(n: String, ox: float, oy: float, oz: float) -> String:
	var b := _find(n)
	if b == null:
		return "no %s" % n
	_look(b.global_transform.origin + Vector3(0, 1.0, 0), ox, oy, oz)
	return "framed %s" % n


func frame_between(a: String, b: String, ox: float, oy: float, oz: float) -> String:
	var na := _find(a)
	var nb := _find(b)
	if na == null or nb == null:
		return "no %s/%s" % [a, b]
	_look((na.global_transform.origin + nb.global_transform.origin) * 0.5 + Vector3(0, 1.0, 0), ox, oy, oz)
	return "framed %s-%s" % [a, b]


func frame_mites(ox: float, oy: float, oz: float) -> String:
	var shots := _mites()
	if shots.is_empty():
		return "no mites"
	var sum := Vector3.ZERO
	for s in shots:
		sum += s.global_transform.origin
	_look(sum / shots.size(), ox, oy, oz)
	return "framed %d mites" % shots.size()


## Luminance of the pixel (x, y) of the image, 0 when outside.
func _lum(img: Image, x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return 0.0
	var c := img.get_pixel(x, y)
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


func _probe(cam: Camera3D, img: Image, at: Vector3, radius: float) -> String:
	if cam.is_position_behind(at):
		return "detras"
	var p := cam.unproject_position(at)
	var edge := cam.unproject_position(at + cam.global_transform.basis.x * radius)
	var px := maxf(1.0, absf(edge.x - p.x))
	var x := int(p.x)
	var y := int(p.y)
	var ring := 0.0
	var n := 0
	var r := int(maxf(6.0, px * 3.0))
	for a in 8:
		var ang := TAU * a / 8.0
		ring += _lum(img, x + int(cos(ang) * r), y + int(sin(ang) * r))
		n += 1
	var contrast := absf(_lum(img, x, y) - ring / n)
	return "(%d, %d) %.1f px contraste %.2f" % [x, y, px * 2.0, contrast]


func pixels(b: String) -> String:
	var nb := _find(b)
	var cam := get_viewport().get_camera_3d()
	if nb == null or cam == null:
		return "no %s" % b
	var img := get_viewport().get_texture().get_image()
	var parts: Array[String] = []
	for s in _mites():
		parts.append("aire " + _probe(cam, img, s.global_transform.origin, 0.1))
	var cling := Clinging.of(nb)
	if cling != null:
		for look in cling.get_children():
			if look is Node3D:
				parts.append("pegado " + _probe(cam, img, (look as Node3D).global_transform.origin, 0.1))
	var line := "PT156 pixeles %s: %s (vista %s)" % [b, " | ".join(parts), str(get_viewport().get_visible_rect().size)]
	print(line)
	return line
