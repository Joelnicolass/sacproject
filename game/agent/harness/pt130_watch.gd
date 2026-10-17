extends Node

## Read-only observer for the F130 window run (RFC-030 030s-a: the Storm Giant's Call lightning and Lightning Charge on lane L of
## f130_lightning). It never moves, orders or damages anything: it reads the bodies and re-frames the screen camera (like a player
## scrolling the view; the bench camera is fixed).
##
##   frame_on(name, ox, oy, oz)           screen camera at the body + offset, looking at the body (+1 m).
##   frame_between(a, b, ox, oy, oz)      the camera looks at the middle of two bodies.
##   frame_point(x, y, z, ox, oy, oz)     the camera looks at a world point.
##   report(name)                         the body: charge frames, shown, speed_factor, strikes in flight.
##   pixels(name)                         the screen pixel (viewport) of the body.
## Props: tick, rel (ticks since the bench started: Enter or --autostart).

var tick := 0
var rel := -1
## gcil strikes in flight (the Giant's discharges), for the flow to wait on.
var discharges := 0
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
	discharges = 0
	for node in get_tree().root.find_children("*", "LightningStrike", true, false):
		if (node as LightningStrike).label == "gcil":
			discharges += 1


func report(n: String) -> String:
	var b := _find(n)
	var line := "PT130 tick %d rel %d · " % [tick, rel]
	if b == null:
		line += "no %s" % n
	else:
		var charge := LightningCharge.of(b)
		line += "%s carga %s cuadros %d speed_factor %.4f · rayos en vuelo %d" % [
			n, str(charge.shown) if charge else "-", charge.frames if charge else -1, float(b.get("speed_factor")),
			get_tree().root.find_children("*", "LightningStrike", true, false).size()]
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
	_look(b.global_transform.origin + Vector3(0, 4.0, 0), ox, oy, oz)
	return "framed %s" % n


func frame_between(a: String, b: String, ox: float, oy: float, oz: float) -> String:
	var na := _find(a)
	var nb := _find(b)
	if na == null or nb == null:
		return "no %s/%s" % [a, b]
	_look((na.global_transform.origin + nb.global_transform.origin) * 0.5 + Vector3(0, 3.0, 0), ox, oy, oz)
	return "framed %s-%s" % [a, b]


func frame_point(x: float, y: float, z: float, ox: float, oy: float, oz: float) -> String:
	_look(Vector3(x, y, z), ox, oy, oz)
	return "framed point"


func pixels(n: String) -> String:
	var b := _find(n)
	var cam := get_viewport().get_camera_3d()
	if b == null or cam == null:
		return "no %s" % n
	var center := cam.unproject_position(b.global_transform.origin + Vector3(0, 4.0, 0))
	var line := "PT130 pixeles %s: cuerpo (%d, %d) (vista %s)" % [n, center.x, center.y, str(get_viewport().get_visible_rect().size)]
	print(line)
	return line
