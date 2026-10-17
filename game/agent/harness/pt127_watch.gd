extends Node

## Read-only observer for the F127 window run (RFC-030 030p-a: the Rhinok's Halo of Earth, lane C of f127_halo_breath).
## It never moves, orders or damages anything: it reads the rocks (the RangedShot nodes of the shot container) and the
## bodies, and re-frames the screen camera (like a player scrolling the view; the bench camera is fixed).
##
##   frame_on(name, ox, oy, oz)       screen camera at the body + offset, looking at the body (+1 m).
##   frame_above(name, lift, ox, oy, oz)  the same, looking `lift` meters over the body (the rocks orbit ~10 m over the land).
##   frame_rock(shot, ox, oy, oz)     the same, on a rock by its node name (Shot1 = rock 0).
##   frame_between(a, b, ox, oy, oz)  the camera looks at the middle of two bodies.
##   report()                         the rocks alive and where they are on screen, and the Druid1's life.
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


func _rocks() -> Array:
	return get_tree().root.find_children("Shot*", "RangedShot", true, false)


func report() -> String:
	var cam := get_viewport().get_camera_3d()
	var parts: PackedStringArray = []
	for rock in _rocks():
		var at: Vector3 = (rock as Node3D).global_transform.origin
		var px := cam.unproject_position(at) if cam != null and not cam.is_position_behind(at) else Vector2(-1, -1)
		parts.append("%s (%.1f, %.1f, %.1f) pantalla (%.0f, %.0f)" % [rock.name, at.x, at.y, at.z, px.x, px.y])
	var druid := _find("Druid1")
	var health := druid.get_node_or_null("Health") as Health if druid != null else null
	var line := "PT127 tick %d rel %d · rocas %d · Druid1 vida %s · %s" % [
		tick, rel, parts.size(), "%d" % roundi(health.current) if health != null else "-", " · ".join(parts)]
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


func frame_above(n: String, lift: float, ox: float, oy: float, oz: float) -> String:
	var b := _find(n)
	if b == null:
		return "no %s" % n
	_look(b.global_transform.origin + Vector3(0, lift, 0), ox, oy, oz)
	return "framed %s +%.0f m" % [n, lift]


func frame_rock(n: String, ox: float, oy: float, oz: float) -> String:
	var rock := get_tree().root.find_child(n, true, false) as Node3D
	if rock == null:
		return "no %s" % n
	_look(rock.global_transform.origin, ox, oy, oz)
	return "framed %s" % n


func frame_between(a: String, b: String, ox: float, oy: float, oz: float) -> String:
	var na := _find(a)
	var nb := _find(b)
	if na == null or nb == null:
		return "no %s/%s" % [a, b]
	_look((na.global_transform.origin + nb.global_transform.origin) * 0.5 + Vector3(0, 1.0, 0), ox, oy, oz)
	return "framed %s-%s" % [a, b]
