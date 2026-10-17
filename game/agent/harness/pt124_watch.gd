extends Node

## Read-only observer for the F124 window run (RFC-030 030m: Gnome plfa ray, Styx dhga blow, Warmonger fhga gun). It never moves, orders
## or damages anything: it reads Health and ManaPool, listens to RangedAttack.fired and re-frames the screen camera
## (like a player scrolling the view; the bench camera is fixed).
##
##   frame(x, z, ox, oy, oz)    screen camera at ground(x, z) + offset, looking at ground(x, z).
##   frame_on(name, ox, oy, oz) the same, centred on a body.
##   report()                   life of the targets and mana of the shooters.
## Props: tick, rel (ticks since the bench started: Enter).

const _TERRAIN := preload("res://scenes/world/terrain.gd")
const TARGETS := ["Druid1", "Druid2", "Trogg1", "Druid3", "Druid4", "Druid5", "Druid6", "Trogg2", "Druid7"]
const SHOOTERS := ["Gnome1", "Gnome2", "Styx1", "Warmonger1", "Warmonger2"]

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
		var ranged := found.get_node_or_null("RangedAttack")
		if ranged != null and ranged.has_signal("fired"):
			ranged.connect("fired", _on_fired.bind(n))
	return found


func _on_fired(_target: Node3D, _damage: float, before: float, after: float, n: String) -> void:
	print("PT124 FIRED %s tick %d rel %d maná %.2f → %.2f" % [n, MatchClock.now(), MatchClock.now() - _start, before, after])


func _physics_process(_delta: float) -> void:
	tick = MatchClock.now()
	if _start < 0:
		var runner := get_tree().root.find_child("Runner", true, false)
		if runner and bool(runner.get("_running")):
			_start = tick
			for n in SHOOTERS:
				_find(n)
	rel = tick - _start if _start >= 0 else -1


func report() -> String:
	var parts: PackedStringArray = []
	for n in TARGETS:
		var b := _find(n)
		var h := b.get_node_or_null("Health") as Health if b and is_instance_valid(b) else null
		parts.append("%s %.2f" % [n, h.current if h else -1.0])
	for n in SHOOTERS:
		var b := _find(n)
		var m := b.get_node_or_null("ManaPool") as ManaPool if b and is_instance_valid(b) else null
		parts.append("%s maná %.2f" % [n, m.current if m else -1.0])
	var line := "PT124 tick %d rel %d · %s" % [tick, rel, " · ".join(parts)]
	print(line)
	return line


## The FxBus beams on screen now (read-only): name, visible, start → end, age.
func beams() -> String:
	var parts: PackedStringArray = []
	for child in FxBus.get_children():
		if child is BeamFx:
			var b := child as BeamFx
			parts.append("%s vis %s %s→%s t %.3f" % [b.name, b.visible, b.get("_from"), b.get("_to"), float(b.get("_t"))])
	var line := "PT124 BEAMS rel %d · %s" % [rel, " · ".join(parts)]
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
