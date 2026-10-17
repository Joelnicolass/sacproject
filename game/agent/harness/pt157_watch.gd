extends Node

## Read-only observer for the F157 window run (RFC-030 030t-b: the Styx's Rend Soul on lane R of f131_devour_rend). It never moves,
## orders or damages anything: it reads the bodies and the souls and re-frames the screen camera (like a player scrolling the view;
## the bench camera is fixed).
##
##   frame_on(name, ox, oy, oz)         screen camera at the body + offset, looking at the body (+1 m).
##   frame_between(a, b, ox, oy, oz)    the camera looks at the middle of two bodies.
##   frame_at(x, z, ox, oy, oz)         the camera looks at a point of the lane (map x, z; the anchor's land height).
##   healths(names)                     "name vida/máximo" of every body that is still there (the Jabberocky take the blast).
##   souls()                            every soul: state and scaling.
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


func healths(names: Array) -> String:
	var parts: Array[String] = []
	for n in names:
		var body := _find(str(n))
		var health := body.get_node_or_null("Health") as Health if body else null
		parts.append("%s %s" % [n, "%d/%d" % [roundi(health.current), roundi(health.maximum)] if health else "ya no está"])
	var line := "PT157 tick %d rel %d · vidas: %s" % [tick, rel, " | ".join(parts)]
	print(line)
	return line


func souls() -> String:
	var parts: Array[String] = []
	for node in get_tree().get_nodes_in_group(&"soul"):
		var soul := node as Soul
		if soul != null:
			parts.append("%s %s escala %.2f" % [soul.label(), Soul.State.keys()[soul.state], soul.scaling])
	var line := "PT157 tick %d rel %d · almas: %s" % [tick, rel, " | ".join(parts) if not parts.is_empty() else "ninguna"]
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


func frame_at(x: float, z: float, ox: float, oy: float, oz: float) -> String:
	var ref := _find("Jabberocky2")
	var y := ref.global_transform.origin.y if ref else 11.0
	_look(Vector3(x, y + 1.0, z), ox, oy, oz)
	return "framed %.0f,%.0f" % [x, z]
