extends Node

## Read-only observer for the F126 window run (RFC-030 030o-a: Protector of the Ent and Life Shield, lane A of f126_protector_firewalk).
## It never moves, orders or damages anything: it reads Health and LifeShield and re-frames the screen camera (like a player
## scrolling the view; the bench camera is fixed).
##
##   frame(x, z, ox, oy, oz)    screen camera at ground(x, z) + offset, looking at ground(x, z).
##   frame_on(name, ox, oy, oz) the same, centred on a body.
##   report()                   life and shield (shown, bubble scale, ticks left) of every body of the lane.
## Props: tick, rel (ticks since the bench started: Enter).

const _TERRAIN := preload("res://scenes/world/terrain.gd")
const BODIES := ["Ent1", "Druid1", "Druid2", "Druid3", "Druid4", "Gnome1"]

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
		var b := _find(n)
		if b == null or not is_instance_valid(b):
			parts.append("%s -" % n)
			continue
		var h := b.get_node_or_null("Health") as Health
		var s := LifeShield.of(b)
		var look := "sin escudo"
		if s:
			look = "escudo %s burbuja %s x%.2f" % ["sí" if s.shown else "no", "visible" if s.bubble.visible else "oculta", s.bubble.scale.x]
		parts.append("%s %.1f %s px %s" % [n, h.current if h else -1.0, look, _px_rect(b)])
	var line := "PT126 tick %d rel %d · %s" % [tick, rel, " · ".join(parts)]
	print(line)
	return line


## Screen rect "x0,y0,x1,y1" (viewport px) of the body's box, for the PNG measurement (agent/tools/f126_bubble_px.py).
func _px_rect(b: Node3D) -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return "-"
	var box := BodyNudge.box(b)
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for i in 8:
		var p := box.get_endpoint(i)
		if cam.is_position_behind(p):
			return "-"
		var q := cam.unproject_position(p)
		lo = lo.min(q)
		hi = hi.max(q)
	return "%d,%d,%d,%d" % [lo.x, lo.y, hi.x, hi.y]


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
