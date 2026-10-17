extends Node

## Read-only observer for the F128 / F154 window run (RFC-030 030q-a, 030q-b: Web pull on lane Q, Cage pull on lane C of f128_pull).
## It never moves, orders or damages anything: it reads the bodies and re-frames the screen camera (like a player scrolling the
## view; the bench camera is fixed). The grass covers low shots, so every frame looks down.
##
##   frame_on(name, ox, oy, oz)           screen camera at the body + offset, looking at the body (+1 m).
##   frame_between(a, b, ox, oy, oz)      the camera looks at the middle of two bodies.
##   report(a, b)                         both bodies: mode, height, distance; the threads alive.
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


func report(a: String, b: String) -> String:
	var na := _find(a)
	var nb := _find(b)
	var line := "PT128 tick %d rel %d · " % [tick, rel]
	if na == null or nb == null:
		line += "no %s/%s" % [a, b]
	else:
		var pa := na.global_transform.origin
		var pb := nb.global_transform.origin
		line += "%s y %.2f %s y %.2f dist %.2f hilos %d" % [a, pa.y, b, pb.y, pa.distance_to(pb), get_tree().root.find_children("*", "PullThread", true, false).size()]
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
