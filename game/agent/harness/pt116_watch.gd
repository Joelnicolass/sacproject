extends Node

## Read-only observer for the F116 playtest (RFC-030 030e, hybrid fliers). It never moves, orders, selects or
## spawns anything. It only reads Flight:state, heights and paces, aims the world camera's debug pointer (what
## `select` / `order_units` read, like selection_probe / pt113_watch) and re-frames the camera that renders the
## screen (like a player scrolling the view; the bench camera is fixed).
##
##   arm(slot)           tracks every creature of `slot` (-1 = the local one), on every physics tick: Flight state
##                       changes (t, height over ground, distance to its order point), max height, max pace in the air
##                       and on the ground, clip roles seen. Prints "PT116 <name> <STATE> ..." on each change.
##   reset()             a new phase: clears the per-unit stats (keeps the units).
##   report()            one line per unit, printed; returns the count line.
##   aim_world(x, z)     pointer on the ground at (x, z).
##   aim_unit(i)         pointer on the i-th tracked unit (sorted north to south at arm()).
##   aim_beside(i, dx, dz)  pointer on the ground at the i-th unit's spot + (dx, dz).
##   aim_ahead(m)        pointer on the ground m ahead of the newest tracked unit, along the local wizard's facing.
##   frame(x, z, ox, oy, oz)   screen camera at ground(x, z) + offset, looking at ground(x, z).
##   follow(ox, oy, oz)  every frame, the screen camera looks at the tracked units' centroid from that offset.
##   unfollow()
## Props for wait_until: tracked, flying_now, airborne_seen, takeoff_seen, landed, settled.

const _NAMES := ["GROUND", "TAKEOFF", "FLYING", "LANDING"]

var tracked := 0
var flying_now := 0
var airborne_seen := 0
var takeoff_seen := 0
var landed := 0
var settled := 0

var _slot := -1
var _on := false
var _units: Array[Node3D] = []
var _stats: Dictionary = {}
var _t := 0.0
var _follow := false
var _offset := Vector3.ZERO
var _follow_index := -1


func _ready() -> void:
	process_priority = 1000


func _local_slot() -> int:
	return MpKit.local_slot()


func _terrain() -> TerrainShape:
	return TerrainShape.of(self)


func _ground_y(x: float, z: float) -> float:
	var t := _terrain()
	if t == null:
		return 0.0
	var y := t.height_at(x, z)
	return 0.0 if is_nan(y) else y


func _world_camera() -> Camera3D:
	for cam in get_tree().root.find_children("Camera", "Camera3D", true, false):
		if "debug_pointer" in cam:
			return cam as Camera3D
	return null


func _scan() -> void:
	var slot := _slot if _slot >= 0 else _local_slot()
	var added := false
	for node in get_tree().get_nodes_in_group("unit"):
		if int(node.get("owner_slot")) != slot or not node is Node3D or _units.has(node):
			continue
		if not (node as Node).has_node("Flight"):
			continue
		_units.append(node as Node3D)
		_stats[node] = _fresh(node as Node3D)
		added = true
	if added:
		_units.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_transform.origin.z < b.global_transform.origin.z)
	tracked = _units.size()


func _fresh(u: Node3D) -> Dictionary:
	var at := u.global_transform.origin
	return {"states": [], "max_above": 0.0, "air_pace": 0.0, "ground_pace": 0.0, "roles": {}, "last": int(u.get_node("Flight").get("state")),
		"at": at, "ever_air": false, "ever_takeoff": false, "landed": false, "start": at, "ordered_seen": false}


func arm(slot: int = -1) -> String:
	_slot = slot
	_on = true
	_t = 0.0
	_units.clear()
	_stats.clear()
	_scan()
	var names: Array[String] = []
	for u in _units:
		names.append(str(u.name))
	return "armed slot %d: %d [%s]" % [_slot if _slot >= 0 else _local_slot(), tracked, ",".join(names)]


func reset() -> String:
	_t = 0.0
	for u in _units:
		if is_instance_valid(u):
			_stats[u] = _fresh(u)
	airborne_seen = 0
	takeoff_seen = 0
	landed = 0
	settled = 0
	return "reset %d" % _units.size()


func _physics_process(delta: float) -> void:
	if not _on:
		return
	_t += delta
	_scan()
	var flying := 0
	var air := 0
	var took := 0
	var down := 0
	var calm := 0
	for u in _units:
		if not is_instance_valid(u):
			continue
		var s: Dictionary = _stats[u]
		var state := int(u.get_node("Flight").get("state"))
		var at := u.global_transform.origin
		var above := at.y - _ground_y(at.x, at.z)
		var was: Vector3 = s["at"]
		var pace := Vector2(at.x - was.x, at.z - was.z).length() / maxf(delta, 0.0001)
		s["at"] = at
		if state == Flight.State.FLYING:
			s["max_above"] = maxf(float(s["max_above"]), above)
			s["air_pace"] = maxf(float(s["air_pace"]), pace)
			s["ever_air"] = true
			flying += 1
		elif state == Flight.State.GROUND:
			s["ground_pace"] = maxf(float(s["ground_pace"]), pace)
		if state == Flight.State.TAKEOFF:
			s["ever_takeoff"] = true
		var pose := u.get_node_or_null("ClipPose") as ClipPlayback
		if pose != null:
			(s["roles"] as Dictionary)[pose.active_role()] = true
		if bool(u.get("ordered")):
			s["ordered_seen"] = true
		if state != int(s["last"]):
			var gap := _gap(u)
			(s["states"] as Array).append("%s@%.2fs(h=%.2f,d=%.1f)" % [_NAMES[state], _t, above, gap])
			print("PT116 %s %s t=%.2f h=%.2f d=%.1f pace=%.1f" % [u.name, _NAMES[state], _t, above, gap, pace])
			if state == Flight.State.GROUND and bool(s["ever_air"]):
				s["landed"] = true
			s["last"] = state
		if bool(s["ever_air"]):
			air += 1
		if bool(s["ever_takeoff"]):
			took += 1
		if bool(s["landed"]):
			down += 1
		if bool(s["ordered_seen"]) and state == Flight.State.GROUND and not bool(u.get("ordered")) and int(u.get("mode")) == UnitBody.Mode.IDLE:
			calm += 1
	flying_now = flying
	airborne_seen = air
	takeoff_seen = took
	landed = down
	settled = calm


func _gap(u: Node3D) -> float:
	var orders := u.get_node_or_null("Orders")
	if orders == null:
		return -1.0
	var p: Vector3 = orders.get("point")
	var at := u.global_transform.origin
	return Vector2(p.x - at.x, p.z - at.z).length()


func report() -> String:
	for u in _units:
		if not is_instance_valid(u):
			continue
		var s: Dictionary = _stats[u]
		var type: CreatureType = u.get("type")
		var at := u.global_transform.origin
		var start: Vector3 = s["start"]
		var feet := at.y - _ground_y(at.x, at.z)
		var state := int(u.get_node("Flight").get("state"))
		print("PT116 R %-12s run %.1f fly %.1f to %.2fs | %s | ahora %s h %.2f | h_max %.2f aire %.2f tierra %.2f | recorrido %.1f m | ordenada %s modo %d | clips %s" % [
			u.name, type.running_speed, type.flying_speed, type.takeoff_time_s(),
			" ".join(s["states"]), _NAMES[state], feet, s["max_above"], s["air_pace"], s["ground_pace"],
			Vector2(at.x - start.x, at.z - start.z).length(), u.get("ordered"), int(u.get("mode")),
			",".join((s["roles"] as Dictionary).keys())])
	return "tracked %d flying_now %d airborne_seen %d takeoff_seen %d landed %d settled %d t=%.1f" % [tracked, flying_now, airborne_seen, takeoff_seen, landed, settled, _t]


func _set_pointer(spot: Vector3) -> String:
	var cam := get_viewport().get_camera_3d()
	var world_cam := _world_camera()
	if cam == null or world_cam == null:
		return "no camera"
	if cam.is_position_behind(spot):
		return "behind"
	var screen := cam.unproject_position(spot)
	var view := get_viewport().get_visible_rect().size
	world_cam.set("debug_pointer", screen)
	var inside := Rect2(Vector2.ZERO, view).has_point(screen)
	return "%d,%d at=(%.1f, %.1f) %s" % [screen.x, screen.y, spot.x, spot.z, "on" if inside else "OFFSCREEN"]


func aim_world(x: float, z: float) -> String:
	return _set_pointer(Vector3(x, _ground_y(x, z), z))


func aim_unit(i: int) -> String:
	if i < 0 or i >= _units.size():
		return "no unit %d" % i
	var u := _units[i]
	return "%s %s" % [u.name, _set_pointer(u.global_transform.origin + Vector3.UP * 1.0)]


func aim_beside(i: int, dx: float, dz: float) -> String:
	if i < 0 or i >= _units.size():
		return "no unit %d" % i
	var at := _units[i].global_transform.origin
	return "%s -> %s" % [_units[i].name, aim_world(at.x + dx, at.z + dz)]


func aim_ahead(meters: float) -> String:
	if _units.is_empty():
		return "no unit"
	var wiz: Node3D = null
	for w in get_tree().get_nodes_in_group("wizard"):
		if int(w.get("owner_slot")) == _local_slot():
			wiz = w as Node3D
	var newest := _units[0]
	for c in _units:
		if c.get_instance_id() > newest.get_instance_id():
			newest = c
	var dir := Vector3(0, 0, -1)
	if wiz != null and wiz.has_method("facing_flat"):
		dir = (wiz as WizardBody).facing_flat()
	var at := newest.global_transform.origin
	var found := _free_spot(Vector3(at.x + dir.x * meters, 0.0, at.z + dir.z * meters), [0.0, 4.0, 8.0, 12.0], 4.0)
	if found.is_empty():
		return "%s no free spot ahead" % newest.name
	var spot: Vector3 = found[0]
	return "%s d=%.1f -> %s" % [newest.name, Vector2(spot.x - at.x, spot.z - at.z).length(), _set_pointer(spot)]


func frame(x: float, z: float, ox: float, oy: float, oz: float) -> String:
	_follow = false
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return "no camera"
	var look := Vector3(x, _ground_y(x, z), z)
	cam.look_at_from_position(look + Vector3(ox, oy, oz), look, Vector3.UP)
	return "framed (%.0f, %.0f)" % [x, z]


func follow(ox: float, oy: float, oz: float) -> String:
	_follow = true
	_follow_index = -1
	_offset = Vector3(ox, oy, oz)
	return "follow"


func unfollow() -> String:
	_follow = false
	return "unfollow"


func _process(_delta: float) -> void:
	if not _follow or _units.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var c := _centroid()
	if _follow_index >= 0 and _follow_index < _units.size() and is_instance_valid(_units[_follow_index]):
		c = _units[_follow_index].global_transform.origin
	cam.look_at_from_position(c + _offset, c + Vector3.UP * 2.0, Vector3.UP)


## Pointer on the ground `meters` from the i-th unit, in the first of 16 directions (from east, turning) whose spot has
## no body within `clear_m` and whose screen ray lands on the ground within 1.5 m of it.
func aim_free(i: int, meters: float, clear_m: float = 2.5) -> String:
	if i < 0 or i >= _units.size():
		return "no unit %d" % i
	var u := _units[i]
	var at := u.global_transform.origin
	var found := _free_spot(at, [meters], clear_m)
	if found.is_empty():
		return "%s no free spot" % u.name
	return "%s d=%.1f -> %s" % [u.name, meters, _set_pointer(found[0])]


## Pointer on a free ground spot (no body within clear_m, screen ray lands on it) at (x, z) or on rings of 4, 8, 12 m.
func aim_clear(x: float, z: float, clear_m: float = 8.0) -> String:
	var found := _free_spot(Vector3(x, 0.0, z), [0.0, 4.0, 8.0, 12.0, 16.0], clear_m)
	if found.is_empty():
		return "no free spot near (%.0f, %.0f)" % [x, z]
	return _set_pointer(found[0])


func _free_spot(center: Vector3, rings: Array, clear_m: float) -> Array:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return []
	var bodies: Array = []
	for group in ["unit", "wizard", "structure", "corpse", "soul_target", "doctor", "npc", "manafount", "mana_source"]:
		bodies.append_array(get_tree().get_nodes_in_group(group))
	for ring: float in rings:
		var steps := 1 if ring <= 0.0 else 16
		for step in steps:
			var angle := TAU * step / 16.0
			var x := center.x + cos(angle) * ring
			var z := center.z + sin(angle) * ring
			var spot := Vector3(x, _ground_y(x, z), z)
			var crowded := false
			for b in bodies:
				if not b is Node3D:
					continue
				var o := (b as Node3D).global_transform.origin
				if Vector2(o.x - x, o.z - z).length() < clear_m:
					crowded = true
					break
			if crowded or cam.is_position_behind(spot):
				continue
			var screen := cam.unproject_position(spot)
			var origin := cam.project_ray_origin(screen)
			var far := origin + cam.project_ray_normal(screen) * 10000.0
			var space := cam.get_world_3d().direct_space_state
			## What the right click sees first (match_command._body_under: mask 3, Attackable bodies).
			var first := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, far, 3))
			var ground := not first.is_empty()
			if ground and first["collider"] is Node and Attackable.is_body(first["collider"] as Node):
				ground = false
			if ground and (first["position"] as Vector3).distance_to(spot) > 1.5:
				ground = false
			if ground:
				return [spot]
	return []


## One-shot: the screen camera looks at the tracked units' centroid from that offset.
func frame_all(ox: float, oy: float, oz: float) -> String:
	var c := _centroid()
	return frame(c.x, c.z, ox, oy, oz)


func follow_unit(i: int, ox: float, oy: float, oz: float) -> String:
	_follow = true
	_follow_index = i
	_offset = Vector3(ox, oy, oz)
	return "follow %s" % (_units[i].name if i >= 0 and i < _units.size() else "?")


func _centroid() -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for u in _units:
		if is_instance_valid(u):
			c += u.global_transform.origin
			n += 1
	return c / maxf(1.0, n)
