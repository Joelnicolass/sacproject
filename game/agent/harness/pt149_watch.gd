extends Node

## Read-only observer for the F149 window run (RFC-030 030k-b: Silverback rdba freezes). It never moves, orders, damages
## or freezes anything; it reads the targets' Afflictions mask, Health and mesh overrides, and re-frames the screen camera
## (like a player scrolling the view; the bench camera is fixed).
##
##   frame(x, z, ox, oy, oz)   screen camera at ground(x, z) + offset, looking at ground(x, z).
##   frame_on(name, ox, oy, oz) the same, centred on a target.
##   report()                   one line per target: frozen episodes (ticks, flat drift, strikes while frozen, ice overrides).
## Props: tick, rel, trogg1_frozen, druid1_frozen, druid2_frozen (0/1).

const FROZEN_BIT := 1 << 3
const NAMES := ["Trogg1", "Druid1", "Druid2"]

var tick := 0
## Ticks since the bench started (Enter): the bench times of the f149 log (MatchClock also counts the wait for Enter).
var rel := -1
var _start := -1
var trogg1_frozen := 0
var druid1_frozen := 0
var druid2_frozen := 0

var _bodies: Dictionary = {}
var _info: Dictionary = {}


func _ready() -> void:
	process_physics_priority = 1000


func _find(n: String) -> Node3D:
	if _bodies.has(n) and is_instance_valid(_bodies[n]):
		return _bodies[n] as Node3D
	var found := get_tree().root.find_child(n, true, false) as Node3D
	if found:
		_bodies[n] = found
		_info[n] = {"eps": [], "cur": {}, "strikes": 0}
		if found.has_signal("struck"):
			found.connect("struck", _on_struck.bind(n))
	return found


func _frozen(b: Node3D) -> bool:
	var a := b.get_node_or_null("Afflictions") if b else null
	return a != null and int(a.get("shown")) & FROZEN_BIT != 0


func _on_struck(_target: Node3D, _amount: float, _c: float, _r: float, n: String) -> void:
	if _frozen(_find(n)):
		_info[n]["strikes"] = int(_info[n]["strikes"]) + 1


func _iced(b: Node3D) -> bool:
	var mesh := b.get_node_or_null("Tilt/Mesh") as MeshInstance3D
	return mesh != null and mesh.get_surface_override_material_count() > 0 and mesh.get_surface_override_material(0) is ShaderMaterial


func _physics_process(_delta: float) -> void:
	tick = MatchClock.now()
	if _start < 0:
		var runner := get_tree().root.find_child("Runner", true, false)
		if runner and bool(runner.get("_running")):
			_start = tick
	rel = tick - _start if _start >= 0 else -1
	var flags := []
	for n in NAMES:
		var b := _find(n)
		var on := b != null and is_instance_valid(b) and _frozen(b)
		flags.append(1 if on else 0)
		if b == null or not _info.has(n):
			continue
		var i: Dictionary = _info[n]
		var cur: Dictionary = i["cur"]
		var o := b.global_transform.origin
		if on and cur.is_empty():
			i["cur"] = {"start": tick, "at": o, "drift": 0.0, "iced": 0, "frames": 0, "strikes0": int(i["strikes"])}
		elif on:
			cur["drift"] = maxf(float(cur["drift"]), Vector2(o.x - cur["at"].x, o.z - cur["at"].z).length())
			cur["frames"] = int(cur["frames"]) + 1
			if _iced(b):
				cur["iced"] = int(cur["iced"]) + 1
		elif not cur.is_empty():
			cur["end"] = tick
			(i["eps"] as Array).append(cur)
			print("PT149 THAW %s rel %d..%d drift %.4f iced %d/%d strikes %d" % [n, int(cur["start"]) - _start, tick - _start, cur["drift"],
				cur["iced"], cur["frames"], int(i["strikes"]) - int(cur["strikes0"])])
			i["cur"] = {}
	trogg1_frozen = flags[0]
	druid1_frozen = flags[1]
	druid2_frozen = flags[2]


func report() -> String:
	var parts: PackedStringArray = []
	for n in NAMES:
		var b := _find(n)
		var h := b.get_node_or_null("Health") as Health if b and is_instance_valid(b) else null
		parts.append("%s vida %.1f congelado %d hielo %d" % [n, h.current if h else -1.0, 1 if b and _frozen(b) else 0,
			1 if b and is_instance_valid(b) and _iced(b) else 0])
	var line := "PT149 tick %d rel %d · %s" % [tick, rel, " · ".join(parts)]
	print(line)
	return line


func frame(x: float, z: float, ox: float, oy: float, oz: float) -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return "no camera"
	var t := TerrainShape.of(self)
	var y := 0.0
	if t != null:
		var g: float = t.height_at(x, z)
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
