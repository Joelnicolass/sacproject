extends Node

## Read-only observer for the F152 window run (RFC-030 030o-b: the Warmonger's Firewalk, lane B of f126_protector_firewalk).
## It never moves, orders or damages anything: it reads the bodies and re-frames the screen camera (like a player scrolling
## the view; the bench camera is fixed).
##
##   frame(x, z, ox, oy, oz)    screen camera at ground(x, z) + offset, looking at ground(x, z).
##   frame_on(name, ox, oy, oz) the same, centred on a body.
##   report()                   state of the Warmongers: using ability, firewalking, mesh shown, targetable, obstacle.
## Props: tick, rel (ticks since the bench started: Enter).

const _TERRAIN := preload("res://scenes/map/terrain/terrain.gd")
const BODIES := ["Warmonger1", "Warmonger2", "Warmonger3"]

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


func report() -> String:
	var parts: PackedStringArray = []
	for n in BODIES:
		var b := _find(n) as UnitBody
		if b == null:
			parts.append("%s -" % n)
			continue
		var afflictions := b.get_node("Afflictions") as Afflictions
		var walker := Firewalking.of(b)
		var tilt := b.get_node("Tilt") as Node3D
		parts.append("%s preparando %s caminando %s malla %s blanco %s obstáculo %s" % [
			n, afflictions.is_on(b.get_node("Afflictions/UsingAbility").type), walker.is_on(),
			"visible" if tilt.visible else "oculta", b.is_targetable(), b.is_obstacle()])
	var line := "PT152 tick %d rel %d · %s" % [tick, rel, " · ".join(parts)]
	print(line)
	return line


func frame(x: float, z: float, ox: float, oy: float, oz: float) -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return "no camera"
	var t := get_tree().root.find_child("Terrain", true, false) as _TERRAIN
	var y := 0.0
	if t != null:
		var g: float = t.ground_height(x, z)
		y = 0.0 if is_nan(g) else g
	var look := Vector3(x, y + 1.0, z)
	cam.look_at_from_position(look + Vector3(ox, oy, oz), look, Vector3.UP)
	return "framed (%.0f, %.0f) y %.1f" % [x, z, y]


func frame_on(n: String, ox: float, oy: float, oz: float) -> String:
	var b := _find(n)
	var cam := get_viewport().get_camera_3d()
	if b == null or cam == null:
		return "no %s" % n
	var look := b.global_transform.origin + Vector3(0, 1.0, 0)
	cam.look_at_from_position(look + Vector3(ox, oy, oz), look, Vector3.UP)
	return "framed %s at (%.0f, %.0f)" % [n, look.x, look.z]
