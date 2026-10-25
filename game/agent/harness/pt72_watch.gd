extends Node

## Observation only (024b playtest): follows the units of one slot every physics tick and reports how far
## they strayed from where they began, how many times their mode changed and the most they moved in a
## tick. Also aims the camera pointer at a ground point ahead of the local wizard and walks the wizard with
## request_walk (what a right click on the ground does). Moves no unit.

var text := "sin datos"
var _slot := 1
var _on := false
var _anchor := {}
var _last := {}
var _mode := {}
var _stats := {}
var _ticks := 0
var _foe_min := INF
var _trace := true
var _still_move := {}
var _max_still_move := 0
var trace_units := PackedStringArray([])
var _min_fount_units := INF
var _min_fount_wizard := INF
var _fount := Vector3.ZERO


func begin(slot: int = 1) -> void:
	_slot = slot
	_anchor.clear()
	_last.clear()
	_mode.clear()
	_stats.clear()
	_ticks = 0
	_foe_min = INF
	_max_still_move = 0
	_still_move.clear()
	_min_fount_units = INF
	_min_fount_wizard = INF
	_on = true


func stop() -> void:
	_on = false


func _physics_process(_delta: float) -> void:
	if not _on:
		return
	_ticks += 1
	for node in get_tree().get_nodes_in_group("unit"):
		var body := node as Node3D
		if body == null or not is_instance_valid(body):
			continue
		var slot := int(body.get("owner_slot"))
		var id := body.get_instance_id()
		var at := body.global_transform.origin
		if slot != _slot:
			continue
		if not _anchor.has(id):
			_anchor[id] = at
			_last[id] = at
			_mode[id] = int(body.get("mode"))
			_stats[id] = {"name": str(body.name), "max_from": 0.0, "changes": 0, "path": 0.0, "max_step": 0.0}
		var s: Dictionary = _stats[id]
		var a: Vector3 = _anchor[id]
		var from := Vector2(at.x - a.x, at.z - a.z).length()
		s["max_from"] = maxf(s["max_from"], from)
		var l: Vector3 = _last[id]
		var step := Vector2(at.x - l.x, at.z - l.z).length()
		s["path"] += step
		if int(body.get("mode")) == 1 and step < 0.02:
			_still_move[id] = int(_still_move.get(id, 0)) + 1
			_max_still_move = maxi(_max_still_move, _still_move[id])
		else:
			_still_move[id] = 0
		s["max_step"] = maxf(s["max_step"], step)
		_last[id] = at
		for fount in get_tree().get_nodes_in_group("manafount"):
			var fp: Vector3 = (fount as Node3D).global_transform.origin
			_min_fount_units = minf(_min_fount_units, Vector2(at.x - fp.x, at.z - fp.z).length())
		if _ticks % 60 == 1 and _trace and (trace_units.is_empty() or trace_units.has(str(body.name))):
			var ord = body.get_node_or_null("Orders")
			var tgt = body.get("target")
			print("PT72_TRACE t=%d %s x=%.1f z=%.1f mode=%d cmd=%s tgt=%s walk=%s" % [_ticks / 60, body.name, at.x, at.z, int(body.get("mode")), str(ord.command) if ord else "-", str(tgt.name) if tgt else "-", str(ord.point) if ord else "-"])
			var wz = get_tree().get_first_node_in_group("local_wizard") as Node3D
			print("PT72_AUX %s _goal=%s speed_factor=%s move_speed=%s wizard_z=%.1f wiz_mode=%s" % [body.name, str(body.get("_goal")), str(body.get("speed_factor")), str(body.get("move_speed")), wz.global_transform.origin.z if wz else 0.0, str(wz.get("mode")) if wz else "-"])
			var pf = body.get_node_or_null("PathFollower")
			var tp = body.get_node_or_null("TargetPicker")
			if tp:
				tp.set("record_scores", true)
			if pf and pf.active:
				print("PT72_PF %s goal=%s wps=%s" % [body.name, str(pf.goal), str(pf.waypoints)])
			if tp and not tp.last_scores.is_empty():
				var names := PackedStringArray()
				for e in tp.last_scores:
					names.append("%s=%.2f" % [str(e["node"].name), float(e["score"])])
				print("PT72_PICK %s scores=%s" % [body.name, ", ".join(names)])
		var m := int(body.get("mode"))
		if m != _mode[id]:
			s["changes"] += 1
			_mode[id] = m
	for node in get_tree().get_nodes_in_group("unit"):
		if int(node.get("owner_slot")) == _slot or int(node.get("owner_slot")) <= 0:
			continue
		for id in _last:
			var l: Vector3 = _last[id]
			var p := (node as Node3D).global_transform.origin
			_foe_min = minf(_foe_min, Vector2(l.x - p.x, l.z - p.z).length())


## One line: units tracked, worst straying, worst mode-change count, total path walked, closest foe.
func report() -> String:
	var worst_from := 0.0
	var worst_changes := 0
	var path := 0.0
	var step := 0.0
	var modes := PackedStringArray()
	for id in _stats:
		var s: Dictionary = _stats[id]
		worst_from = maxf(worst_from, s["max_from"])
		worst_changes = maxi(worst_changes, s["changes"])
		path += s["path"]
		step = maxf(step, s["max_step"])
	text = "units=%d ticks=%d max_from_anchor=%.2f max_mode_changes=%d total_path=%.1f max_step=%.3f foe_min=%.1f" % [
		_stats.size(), _ticks, worst_from, worst_changes, path, step, _foe_min]
	return text


func sight_of_first() -> String:
	for node in get_tree().get_nodes_in_group("unit"):
		if int(node.get("owner_slot")) == _slot and node.get("type") != null:
			return "sight_range slot%d=%s" % [_slot, str(node.get("type").vision_m)]
	return "sin unidad"


func foe_distance() -> String:
	var wiz = get_tree().get_first_node_in_group("local_wizard") as Node3D
	var out := PackedStringArray()
	for node in get_tree().get_nodes_in_group("unit"):
		var slot := int(node.get("owner_slot"))
		if slot != _slot and slot > 0:
			var p := (node as Node3D).global_transform.origin
			var line := "foe %s a %.1f m del mago" % [node.name, Vector2(p.x - wiz.global_transform.origin.x, p.z - wiz.global_transform.origin.z).length()] if wiz else ""
			out.append(line)
	text = "; ".join(out)
	return text


func aim_ahead(meters: float) -> Variant:
	var wiz = get_tree().get_first_node_in_group("local_wizard") as Node3D
	var cam := get_tree().get_current_scene().get_node_or_null("HighNoon/Camera")
	if wiz == null or cam == null:
		return null
	var spot: Vector3 = wiz.global_transform.origin + wiz.facing_flat() * meters
	var screen: Vector2 = cam.unproject_position(spot)
	cam.set("debug_pointer", screen)
	return screen


func walk_ahead(meters: float, side: float = 0.0) -> bool:
	var wiz = get_tree().get_first_node_in_group("local_wizard") as Node3D
	if wiz == null or not wiz.has_method("request_walk"):
		return false
	var ahead: Vector3 = wiz.facing_flat()
	wiz.request_walk(wiz.global_transform.origin + ahead * meters + ahead.cross(Vector3.UP) * side)
	return true


func wizard_info() -> String:
	var wiz = get_tree().get_first_node_in_group("local_wizard") as Node3D
	if wiz == null:
		return "sin mago"
	var o: Vector3 = wiz.global_transform.origin
	text = "mago (%.1f, %.1f, %.1f)" % [o.x, o.y, o.z]
	return text


## Whether the side of `_slot` has the foes in sight right now (VisionSides.sees), and the foes' health.
func seen_report() -> String:
	var out := PackedStringArray()
	for node in get_tree().get_nodes_in_group("unit"):
		var slot := int(node.get("owner_slot"))
		if slot == _slot or slot <= 0:
			continue
		var hp = node.get_node_or_null("Health")
		out.append("%s visto_por_bando=%s vida=%s" % [node.name, str(VisionSides.sees(_slot, node)), str(hp.get("current")) if hp else "-"])
	text = "; ".join(out)
	return text


func _nearest_fount(from: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var bd := INF
	for fount in get_tree().get_nodes_in_group("manafount"):
		var fp: Vector3 = (fount as Node3D).global_transform.origin
		var d := Vector2(fp.x - from.x, fp.z - from.z).length()
		if d < bd:
			bd = d
			best = fp
	return best


## The wizard clicks the ground `beyond` m past the nearest manafount, on the line from him through it.
func walk_past_fount(beyond: float) -> String:
	var wiz = get_tree().get_first_node_in_group("local_wizard") as Node3D
	if wiz == null:
		return "sin mago"
	var from: Vector3 = wiz.global_transform.origin
	_fount = _nearest_fount(from)
	var dir := Vector3(_fount.x - from.x, 0.0, _fount.z - from.z)
	var dist := dir.length()
	dir = dir.normalized()
	var goal := _fount + dir * beyond
	wiz.request_walk(Vector3(goal.x, from.y, goal.z))
	text = "fount (%.1f, %.1f) a %.1f m del mago; destino (%.1f, %.1f)" % [_fount.x, _fount.z, dist, goal.x, goal.z]
	return text


func escort_report() -> String:
	var wiz = get_tree().get_first_node_in_group("local_wizard") as Node3D
	var wp: Vector3 = wiz.global_transform.origin
	var far := 0.0
	var near := INF
	for id in _last:
		var l: Vector3 = _last[id]
		var d := Vector2(l.x - wp.x, l.z - wp.z).length()
		far = maxf(far, d)
		near = minf(near, d)
	for fount in get_tree().get_nodes_in_group("manafount"):
		var fp: Vector3 = (fount as Node3D).global_transform.origin
		_min_fount_wizard = minf(_min_fount_wizard, Vector2(wp.x - fp.x, wp.z - fp.z).length())
	text = "mago a %.1f m del manantial dest; unidades: a %.1f..%.1f m del mago; min a un manantial: unidades %.1f" % [Vector2(wp.x - _fount.x, wp.z - _fount.z).length(), near, far, _min_fount_units]
	return text


func set_trace(names: PackedStringArray) -> void:
	trace_units = names


## How many units of the slot walk right now, how many already stand, and the longest a walking unit stood still.
func move_report() -> String:
	var walking := 0
	var idle := 0
	for node in get_tree().get_nodes_in_group("unit"):
		if int(node.get("owner_slot")) != _slot:
			continue
		if int(node.get("mode")) == 1:
			walking += 1
		else:
			idle += 1
	text = "caminando=%d quietas=%d max_quieta_en_marcha_s=%.2f %s" % [walking, idle, float(_max_still_move) / 60.0, report()]
	return text


## The units that walk but stand still for over 2 s: how far each is from its goal and from its formation slot.
func stuck_report() -> String:
	var lines := PackedStringArray()
	var count := 0
	var worst_goal := 0.0
	var best_goal := INF
	for node in get_tree().get_nodes_in_group("unit"):
		if int(node.get("owner_slot")) != _slot or int(node.get("mode")) != 1:
			continue
		var id := node.get_instance_id()
		if int(_still_move.get(id, 0)) < 120:
			continue
		count += 1
		var at: Vector3 = (node as Node3D).global_transform.origin
		var goal: Vector3 = node.get("_goal")
		var d := Vector2(at.x - goal.x, at.z - goal.z).length()
		worst_goal = maxf(worst_goal, d)
		best_goal = minf(best_goal, d)
		var pf = node.get_node_or_null("PathFollower")
		if lines.size() < 6:
			lines.append("%s d_goal=%.1f pf_active=%s wps=%d" % [node.name, d, str(pf.active) if pf else "-", pf.waypoints.size() if pf else -1])
	text = "atascadas=%d d_meta min=%.1f max=%.1f | %s" % [count, best_goal if count > 0 else 0.0, worst_goal, " ; ".join(lines)]
	return text


## Diagnostic control: the old walk (straight, no waypoints). Frees the PathFollower of every unit of the slot.
func drop_followers() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("unit"):
		if int(node.get("owner_slot")) != _slot:
			continue
		var pf = node.get_node_or_null("PathFollower")
		if pf:
			pf.free()
			n += 1
	return n
