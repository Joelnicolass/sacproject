extends Node

## Read-only observer for the F153 window run (RFC-030 030p-b: the Dragon's Breath of life, lane D of f153_breath).
## It never moves, orders or damages anything: it reads the bodies, the breath (a RangedShot of the shot container) and the
## souls, and re-frames the screen camera (like a player scrolling the view; the bench camera is fixed).
##
##   frame_on(name, ox, oy, oz)           screen camera at the body + offset, looking at the body (+1 m).
##   frame_between(a, b, ox, oy, oz)      the camera looks at the middle of two bodies.
##   frame_breath(ox, oy, oz)             the camera looks at the breath in flight.
##   report()                             Druid1: mode, group «unit», life, height, facing; its soul; the breath.
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


func _breath() -> Node3D:
	var found := get_tree().root.find_children("Shot*", "RangedShot", true, false)
	return found[0] as Node3D if not found.is_empty() else null


func report() -> String:
	var druid := _find("Druid1") as UnitBody
	var line := "PT153 tick %d rel %d · " % [tick, rel]
	if druid == null:
		line += "Druid1 -"
	else:
		var health := druid.get_node_or_null("Health") as Health
		var souls := 0
		for soul in get_tree().get_nodes_in_group(&"soul"):
			if (soul as Soul).corpse == druid:
				souls += 1
		line += "Druid1 modo %d unit %s corpse %s vida %s y %.2f giro %.2f almas %d seleccionable %s" % [
			druid.mode, druid.is_in_group("unit"), druid.is_in_group("corpse"),
			"%d" % roundi(health.current) if health != null else "-",
			druid.global_transform.origin.y, druid.rotation.y, souls, druid.collision_layer == druid.unit_layer]
	var breath := _breath()
	line += " · aliento %s" % ("-" if breath == null else "(%.1f, %.1f, %.1f)" % [
		breath.global_transform.origin.x, breath.global_transform.origin.y, breath.global_transform.origin.z])
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


func frame_breath(ox: float, oy: float, oz: float) -> String:
	var breath := _breath()
	if breath == null:
		return "no breath"
	_look(breath.global_transform.origin, ox, oy, oz)
	return "framed breath"
