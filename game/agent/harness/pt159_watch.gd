extends Node

## Read-only observer for the F159 window run (RFC-030 030u-c: the Dragon's Grasping Vines on hit, lane V of f132_quake_onhit). It never
## moves, orders or damages anything: it reads the bodies, prints one line per tick of Jabberocky3 while the bench runs, and re-frames
## the screen camera (like a player scrolling the view; the bench camera is fixed).
##
##   frame_on(name, ox, oy, oz)         screen camera at the body + offset, looking at the body (+1 m).
##   frame_between(a, b, ox, oy, oz)    the camera looks at the middle of two bodies.
##   state(names)                       "name enredado|libre" of each body.
## Log line every tick from rel 0 to WATCH_TICKS: `vigila Jabberocky3 pos (x, y, z) vida V (tick N)` (f159_expect.py reads it).
## Props: tick, rel (ticks since the bench started: Enter).

const WATCHED := "Jabberocky3"
const WATCH_TICKS := 900

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
	if rel < 0 or rel > WATCH_TICKS:
		return
	var body := _find(WATCHED)
	var health := body.get_node_or_null("Health") as Health if body else null
	if body == null or health == null:
		return
	var at := body.global_transform.origin
	print("vigila %s pos (%.3f, %.3f, %.3f) vida %.3f (tick %d)" % [WATCHED, at.x, at.y, at.z, health.current, tick])


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


func state(names: Array) -> String:
	var parts: Array[String] = []
	for n in names:
		var b := _find(str(n))
		parts.append("%s %s" % [n, "enredado" if b != null and Vined.is_vined(b) else "libre"])
	var line := "PT159 tick %d rel %d · %s" % [tick, rel, " | ".join(parts)]
	print(line)
	return line
