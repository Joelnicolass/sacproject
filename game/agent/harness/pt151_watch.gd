extends Node

## Read-only observer for the F151 window run (RFC-030 030n-b: Rhinok hrba on the land, rings of spikes; lane C of f125). It never moves, orders
## or damages anything: it reads Health and ManaPool, listens to RangedWeapon.fired and re-frames the screen camera
## (like a player scrolling the view; the bench camera is fixed).
##
##   frame(x, z, ox, oy, oz)    screen camera at ground(x, z) + offset, looking at ground(x, z).
##   frame_on(name, ox, oy, oz) the same, centred on a body.
##   report()                   life of the targets and mana of the shooters.
## Props: tick, rel (ticks since the bench started: Enter).

const TARGETS := ["Druid5", "Druid6", "Druid7", "Druid8", "Druid9", "Druid10", "Druid11"]
const SHOOTERS := ["Rhinok1"]

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
		var carrier := found as UnitBody
		var ranged := carrier.weapons.ranged if carrier != null else null
		if ranged != null:
			ranged.fired.connect(_on_fired.bind(n))
	return found


func _on_fired(_target: Node3D, _damage: float, before: float, after: float, n: String) -> void:
	print("PT151 FIRED %s tick %d rel %d maná %.2f → %.2f" % [n, MatchClock.now(), MatchClock.now() - _start, before, after])


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
	var line := "PT151 tick %d rel %d · %s" % [tick, rel, " · ".join(parts)]
	print(line)
	return line


## The creature shots in flight now (read-only): name and position.
func shots() -> String:
	var parts: PackedStringArray = []
	for shot in get_tree().root.find_children("Shot*", "Node3D", true, false):
		var p := (shot as Node3D).global_transform.origin
		parts.append("%s (%.2f, %.2f, %.2f)" % [shot.name, p.x, p.y, p.z])
	var line := "PT151 SHOTS rel %d · %s" % [rel, " · ".join(parts)]
	print(line)
	return line


func frame(x: float, z: float, ox: float, oy: float, oz: float) -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return "no camera"
	var t := Terrain.of(self)
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


## Frame of the first SpikeWave alive (MatchClock.now() − its birth tick), or −1: the flow waits on it.
var wave_frame := -1


func _process(_delta: float) -> void:
	wave_frame = -1
	for node in get_tree().root.find_children("*", "SpikeWave", true, false):
		var born := int(node.get("_born"))
		if born >= 0:
			wave_frame = MatchClock.now() - born
			break


## The screen pixels of the bands around (cx, cz) for the current camera: `radii` is [r0, r1, r2, r3, …] (pairs, m); every
## 0.25 m and every 1° a point on the land is projected. Written to res://agent/out/pt151/pt/<key>.json as
## {"size": [w, h], "bands": [[[px, py], …], …]}; agent/tools/f151_bands.py counts the dark pixels of the captures there.
func samples(key: String, cx: float, cz: float, radii: Array) -> String:
	var cam := get_viewport().get_camera_3d()
	var size := get_viewport().get_visible_rect().size
	var t := Terrain.of(self)
	var out: Array = []
	var k := 0
	while k + 1 < radii.size():
		var points: Array = []
		var r := float(radii[k])
		while r <= float(radii[k + 1]) + 1e-4:
			for deg in 360:
				var a := deg_to_rad(float(deg))
				var x := cx + cos(a) * r
				var z := cz + sin(a) * r
				var y := float(t.height_at(x, z)) if t != null else 0.0
				if is_nan(y) or cam.is_position_behind(Vector3(x, y, z)):
					continue
				var p := cam.unproject_position(Vector3(x, y, z))
				if p.x >= 0.0 and p.y >= 0.0 and p.x < size.x and p.y < size.y:
					points.append([int(p.x), int(p.y)])
			r += 0.25
		out.append(points)
		k += 2
	var path := ProjectSettings.globalize_path("res://agent/out/pt151/pt/%s.json" % key)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"size": [int(size.x), int(size.y)], "radii": radii, "bands": out}))
	file.close()
	var line := "PT151 MUESTRAS %s · %s" % [key, ", ".join(out.map(func(b): return str(b.size())))]
	print(line)
	return line
