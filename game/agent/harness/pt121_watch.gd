extends Node

## Read-only observer for the F121 playtest (RFC-030 030j: push, vortex, implosion, tumble). It never moves, orders or
## spawns anything; it only reads positions and the Tumbling / Stunned afflictions, and re-frames the screen camera
## (like a player scrolling the view; the bench camera is fixed).
##
##   focus(x, z, r)            the lane: bodies whose position at the first scan was within r m of (x, z).
##   frame(x, z, ox, oy, oz)   screen camera at ground(x, z) + offset, looking at ground(x, z).
##   follow(ox, oy, oz)        every frame, the camera looks at the focused bodies' centroid (+2 m) from that offset.
##   report()                  one line per focused body.
## Props (of the focused lane, sticky): tick, moved_max (m from start, flat), air_now, air_seen, air_h (max m above
## start), landed, risen, spread (max flat distance from the lane centroid).

const _TERRAIN := preload("res://scenes/map/terrain/terrain.gd")

var tick := 0
var moved_max := 0.0
var air_now := 0
var air_seen := 0
var air_h := 0.0
var landed := 0
var risen := 0
var spread := 0.0

var _rec: Dictionary = {}  # body -> {start, air, landed, risen, h}
var _focus: Array[Node3D] = []
var _follow := false
var _offset := Vector3.ZERO


func _ready() -> void:
	process_priority = 1000


func _scan() -> void:
	for node in get_tree().get_nodes_in_group("unit"):
		if node is Node3D and not _rec.has(node) and (node as Node).has_node("Afflictions/Tumbling"):
			_rec[node] = {"start": (node as Node3D).global_transform.origin, "air": -1, "landed": -1, "risen": -1, "h": 0.0}


func _on(body: Node, path: String) -> bool:
	var a := body.get_node_or_null(path) as Affliction
	return a != null and a.is_on()


func _physics_process(_delta: float) -> void:
	tick = MatchClock.now()
	_scan()
	for body in _rec.keys():
		if not is_instance_valid(body) or not (body as Node).is_inside_tree():
			continue  # freed, or out of the tree during a flow scene change
		var r: Dictionary = _rec[body]
		var at := (body as Node3D).global_transform.origin
		var start: Vector3 = r["start"]
		var tumbling := _on(body, "Afflictions/Tumbling")
		if tumbling:
			if int(r["air"]) < 0:
				r["air"] = tick
			r["h"] = maxf(float(r["h"]), at.y - start.y)
		elif int(r["air"]) >= 0 and int(r["landed"]) < 0:
			r["landed"] = tick
		if int(r["landed"]) >= 0 and int(r["risen"]) < 0 and not _on(body, "Afflictions/Stunned"):
			r["risen"] = tick
	_props()


func _props() -> void:
	var moved := 0.0
	var now := 0
	var seen := 0
	var h := 0.0
	var down := 0
	var up := 0
	var c := Vector3.ZERO
	var n := 0
	for body in _focus:
		if not is_instance_valid(body):
			continue
		var r: Dictionary = _rec[body]
		var at := body.global_transform.origin
		var start: Vector3 = r["start"]
		moved = maxf(moved, Vector2(at.x - start.x, at.z - start.z).length())
		if _on(body, "Afflictions/Tumbling"):
			now += 1
		if int(r["air"]) >= 0:
			seen += 1
		h = maxf(h, float(r["h"]))
		if int(r["landed"]) >= 0:
			down += 1
		if int(r["risen"]) >= 0:
			up += 1
		c += at
		n += 1
	c /= maxf(1.0, n)
	var far := 0.0
	for body in _focus:
		if is_instance_valid(body):
			far = maxf(far, Vector2(body.global_transform.origin.x - c.x, body.global_transform.origin.z - c.z).length())
	moved_max = moved
	air_now = now
	air_seen = seen
	air_h = h
	landed = down
	risen = up
	spread = far


func focus(x: float, z: float, radius: float) -> String:
	_scan()
	_focus.clear()
	var names: Array[String] = []
	for body in _rec.keys():
		var start: Vector3 = _rec[body]["start"]
		if is_instance_valid(body) and Vector2(start.x - x, start.z - z).length() <= radius:
			_focus.append(body as Node3D)
			names.append("%s@(%.1f,%.1f,%.1f)" % [body.name, start.x, start.y, start.z])
	_props()
	return "focus %d [%s]" % [_focus.size(), ", ".join(names)]


func report() -> String:
	for body in _focus:
		if not is_instance_valid(body):
			continue
		var r: Dictionary = _rec[body]
		var at := body.global_transform.origin
		var start: Vector3 = r["start"]
		print("PT121 %s inicio (%.2f,%.2f,%.2f) ahora (%.2f,%.2f,%.2f) movido %.2f m aire %d aterriza %d se levanta %d h_max %.2f tumbo %s aturdido %s modo %s" % [
			body.name, start.x, start.y, start.z, at.x, at.y, at.z, Vector2(at.x - start.x, at.z - start.z).length(),
			int(r["air"]), int(r["landed"]), int(r["risen"]), float(r["h"]), _on(body, "Afflictions/Tumbling"),
			_on(body, "Afflictions/Stunned"), str(body.get("mode"))])
	return "tick %d moved_max %.2f air_now %d air_seen %d air_h %.2f landed %d risen %d spread %.2f" % [
		tick, moved_max, air_now, air_seen, air_h, landed, risen, spread]


func frame(x: float, z: float, ox: float, oy: float, oz: float) -> String:
	_follow = false
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return "no camera"
	var t := get_tree().root.find_child("Terrain", true, false) as _TERRAIN
	var y := 0.0
	if t != null:
		var g: float = t.ground_height(x, z)
		y = 0.0 if is_nan(g) else g
	var look := Vector3(x, y, z)
	cam.look_at_from_position(look + Vector3(ox, oy, oz), look, Vector3.UP)
	return "framed (%.0f, %.0f) y %.1f" % [x, z, y]


func follow(ox: float, oy: float, oz: float) -> String:
	_follow = true
	_offset = Vector3(ox, oy, oz)
	return "follow %d" % _focus.size()


func _process(_delta: float) -> void:
	if not _follow or _focus.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var c := Vector3.ZERO
	var n := 0
	for body in _focus:
		if is_instance_valid(body):
			c += body.global_transform.origin
			n += 1
	if n == 0:
		return
	c /= n
	cam.look_at_from_position(c + _offset, c + Vector3.UP * 1.0, Vector3.UP)
