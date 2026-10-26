extends Node

## Read-only observer for the F136 playtest (RFC-030 030h2, Scarab healing web). It never moves, orders, damages,
## heals or spawns anything: it listens to Health.changed/hit of every unit, RangedWeapon.fired, MeleeWeapon.struck,
## shots entering/leaving the tree and HealEffect nodes being added; and it re-frames the screen camera (like a player
## scrolling the view) to save the rendered viewport. Tolerates scene == null.
##
## Lanes (z offset from 1270): A = -80, B = +80, C = +200. Times are physics frames (Engine.get_physics_frames).
##   arm()     connects to units present (group "unit") and to SceneTree.node_added.
##   report()  prints per unit and per lane what happened.
## Captures (agent/out/pt136/): first shot per lane when < 9 m from its target (fly), 2 and 8 frames after it bursts,
## and 12 frames after each lane's wounded ally reaches full (bar_full).
## Props for wait_until: units, bursts, captured, a_full, b_full, c_struck.

const _SHOT := preload("res://scenes/units/attacks/ranged_shot.gd")
const CENTER_Z := 1270.0
const OUT_DIR := "res://agent/out/pt136"
const AFTER := {2: "burst_a", 8: "burst_b"}

var units := 0
var bursts := 0
var captured := 0
var a_full := 0
var b_full := 0
var c_struck := 0

var _info: Dictionary = {}       # body -> {name, tag, slot, lane, hp0, max, last, hits, heals_fx, full_pf, rise}
var _lane_shot: Dictionary = {}  # lane -> {node, tag, last, fly_done, burst_frame, burst_pf, target}
var _shots: Array = []           # [{lane, spawn_pf, target, exit_pf}]
var _fired: Array = []           # [{lane, pf, shooter, target, slot}]
var _struck: Array = []          # [{lane, pf, target, amount}]
var _queue: Array = []
var _frame := 0
var _phase := 0
var _armed := false


func _ready() -> void:
	process_priority = 1000


func _pf() -> int:
	return Engine.get_physics_frames()


func _terrain() -> Terrain:
	if get_tree().current_scene == null:
		return null
	return Terrain.of(self)


func _ground_y(x: float, z: float) -> float:
	var t := _terrain()
	if t == null:
		return 0.0
	var y := t.height_at(x, z)
	return 0.0 if is_nan(y) else y


func _lane_of(z: float) -> int:
	return int(roundf((z - CENTER_Z) / 40.0)) * 40


func _lane_name(lane: int) -> String:
	match lane:
		-80: return "A"
		80: return "B"
		200: return "C"
	return str(lane)


func _name(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return "null"
	if node.has_method("display_name"):
		var dyn: Variant = node
		return "%s#s%d" % [str(dyn.display_name()), int(node.get("owner_slot"))]
	return str(node.name)


func arm() -> String:
	if get_tree().current_scene == null:
		return "armed 0 (no scene)"
	for node in get_tree().get_nodes_in_group("unit"):
		var body := node as Node3D
		if body == null or _info.has(body):
			continue
		var health := body.get_node_or_null("Health")
		if health == null:
			continue
		var hp := float(health.get("current"))
		var o := body.global_transform.origin
		_info[body] = {"name": _name(body), "tag": str(body.get("creature_tag")), "slot": int(body.get("owner_slot")),
			"lane": _lane_of(o.z), "hp0": hp, "max": float(health.get("maximum")), "last": hp, "hits": [],
			"heals_fx": [], "full_pf": -1, "rise": 0.0, "rise_max_step": 0.0}
		health.connect("changed", _on_changed.bind(body))
		health.connect("hit", _on_hit.bind(body))
		var carrier := body as UnitBody
		var ranged := carrier.weapons.ranged if carrier != null else null
		if ranged != null:
			ranged.fired.connect(_on_fired.bind(body))
		var melee := carrier.weapons.melee if carrier != null else null
		if melee != null:
			melee.struck.connect(_on_struck.bind(body))
		units += 1
		print("PT136 UNIT %s tag=%s lane=%s hp=%.1f/%.1f at=(%.1f, %.1f, %.1f) pf%d" % [_info[body]["name"],
			_info[body]["tag"], _lane_name(_info[body]["lane"]), hp, float(health.get("maximum")), o.x, o.y, o.z, _pf()])
	if not _armed:
		_armed = true
		get_tree().node_added.connect(_on_node_added)
	return "armed %d" % units


func _on_changed(current: float, maximum: float, body: Node3D) -> void:
	var i: Dictionary = _info[body]
	var step := current - float(i["last"])
	if step > 0.0:
		i["rise"] = float(i["rise"]) + step
		i["rise_max_step"] = maxf(float(i["rise_max_step"]), step)
	i["last"] = current
	if int(i["full_pf"]) < 0 and maximum > 0.0 and current >= maximum and float(i["hp0"]) < maximum:
		i["full_pf"] = _pf()
		print("PT136 FULL %s lane=%s hp=%.1f/%.1f pf%d" % [i["name"], _lane_name(i["lane"]), current, maximum, _pf()])
		var lane := int(i["lane"])
		if lane == -80 and int(i["slot"]) == 1:
			a_full += 1
		elif lane == 80 and int(i["slot"]) == 1:
			b_full += 1
		_queue.append({"label": "%s_bar_full" % _lane_name(lane), "node": body, "at": body.global_transform.origin,
			"delay": 12, "close": true})


func _on_hit(amount: float, from_slot: int, _was_full: bool, body: Node3D) -> void:
	var i: Dictionary = _info[body]
	var line := "%.2f s%d pf%d" % [amount, from_slot, _pf()]
	i["hits"].append(line)
	print("PT136 HIT %s lane=%s %s" % [i["name"], _lane_name(i["lane"]), line])


func _on_fired(target: Node3D, damage: float, _mb: float, _ma: float, body: Node3D) -> void:
	var i: Dictionary = _info[body]
	var tname := _name(target)
	_fired.append({"lane": i["lane"], "pf": _pf(), "shooter": i["name"], "target": tname})
	print("PT136 FIRED %s lane=%s -> %s dmg=%.1f pf%d" % [i["name"], _lane_name(i["lane"]), tname, damage, _pf()])


func _on_struck(target: Node3D, amount: float, _c: float, _r: float, body: Node3D) -> void:
	var i: Dictionary = _info[body]
	var tname := _name(target)
	_struck.append({"lane": i["lane"], "pf": _pf(), "shooter": i["name"], "target": tname, "amount": amount})
	if int(i["lane"]) == 200 and int(i["slot"]) == 1:
		c_struck += 1
	print("PT136 STRUCK %s lane=%s -> %s amount=%.2f pf%d" % [i["name"], _lane_name(i["lane"]), tname, amount, _pf()])


func _on_node_added(node: Node) -> void:
	if str(node.name).begins_with("HealEffect"):
		var parent := node.get_parent() as Node3D
		if parent != null and _info.has(parent):
			var i: Dictionary = _info[parent]
			i["heals_fx"].append("pf%d hp=%.1f" % [_pf(), float(i["last"])])
			print("PT136 HEALFX %s lane=%s hp=%.1f pf%d" % [i["name"], _lane_name(i["lane"]), float(i["last"]), _pf()])
		return
	if node.get_script() != _SHOT:
		return
	var shot := node as Node3D
	var o := shot.global_transform.origin
	var lane := _lane_of(o.z)
	var rec := {"lane": lane, "spawn_pf": _pf(), "target": "", "exit_pf": -1, "node": shot}
	_shots.append(rec)
	shot.tree_exiting.connect(_on_shot_exit.bind(rec))
	print("PT136 SHOT_SPAWN lane=%s at=(%.1f, %.1f, %.1f) pf%d" % [_lane_name(lane), o.x, o.y, o.z, _pf()])
	if not _lane_shot.has(lane):
		_lane_shot[lane] = {"node": shot, "last": o, "fly_done": false, "burst_frame": -1}


func _on_shot_exit(rec: Dictionary) -> void:
	var shot: Node3D = rec["node"]
	var p := shot.global_transform.origin
	rec["exit_pf"] = _pf()
	rec["node"] = null
	print("PT136 SHOT_GONE lane=%s target=%s at=(%.2f, %.2f, %.2f) pf%d" % [_lane_name(rec["lane"]), rec["target"],
		p.x, p.y, p.z, _pf()])
	var lane := int(rec["lane"])
	if _lane_shot.has(lane) and _lane_shot[lane]["node"] == shot:
		var s: Dictionary = _lane_shot[lane]
		s["node"] = null
		s["last"] = p
		s["burst_frame"] = _frame
		bursts += 1


func frame(x: float, z: float, ox: float, oy: float, oz: float) -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return "no camera"
	var look := Vector3(x, _ground_y(x, z), z)
	cam.look_at_from_position(look + Vector3(ox, oy, oz), look, Vector3.UP)
	return "framed (%.0f, %.0f)" % [x, z]


func _process(_delta: float) -> void:
	_frame += 1
	if get_tree().current_scene == null:
		return
	for rec in _shots:
		var n: Variant = rec["node"]
		if rec["target"] == "" and n != null and is_instance_valid(n):
			var tp: NodePath = (n as Node).get("target_path")
			if not tp.is_empty():
				rec["target"] = _name((n as Node).get_node_or_null(tp))
	for lane in _lane_shot:
		var s: Dictionary = _lane_shot[lane]
		var shot: Variant = s["node"]
		if shot != null and is_instance_valid(shot):
			var sh := shot as Node3D
			s["last"] = sh.global_transform.origin
			if not s["fly_done"]:
				var target := sh.get_node_or_null(sh.get("target_path")) as Node3D
				if target != null and target.global_transform.origin.distance_to(s["last"]) < 9.0:
					s["fly_done"] = true
					_queue.append({"label": "%s_fly" % _lane_name(lane), "node": sh, "at": s["last"], "delay": 0})
		var bf := int(s["burst_frame"])
		if bf >= 0 and AFTER.has(_frame - bf):
			_queue.append({"label": "%s_%s" % [_lane_name(lane), AFTER[_frame - bf]], "node": null, "at": s["last"],
				"delay": 0})
	if _queue.is_empty():
		return
	var item: Dictionary = _queue[0]
	if int(item["delay"]) > 0:
		item["delay"] = int(item["delay"]) - 1
		return
	if _phase == 0:
		var at: Vector3 = item["at"]
		var n2: Variant = item["node"]
		if n2 != null and is_instance_valid(n2):
			at = (n2 as Node3D).global_transform.origin
			item["at"] = at
		if item.get("close", false):
			frame(at.x, at.z, 0.0, 4.0, 7.0)
		else:
			frame(at.x, at.z, 0.0, 5.0, 8.0)
		_phase = 1
		return
	_phase = 0
	_queue.pop_front()
	var path := "%s/%s.png" % [OUT_DIR, item["label"]]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(ProjectSettings.globalize_path(path))
	var p: Vector3 = item["at"]
	captured += 1
	print("PT136 PNG %s at=(%.1f, %.1f, %.1f) pf%d err=%d" % [path, p.x, p.y, p.z, _pf(), err])


func report() -> String:
	for body in _info:
		var i: Dictionary = _info[body]
		var hp := NAN
		if is_instance_valid(body):
			var h: Node = body.get_node_or_null("Health")
			hp = float(h.get("current")) if h else NAN
		print("PT136 STATE %s lane=%s hp0=%.1f now=%.1f/%.1f rise=%.1f max_step=%.2f full_pf=%d healfx=%s hits=%s" % [
			i["name"], _lane_name(i["lane"]), float(i["hp0"]), hp, float(i["max"]), float(i["rise"]),
			float(i["rise_max_step"]), int(i["full_pf"]), str(i["heals_fx"]), str(i["hits"])])
	for lane in [-80, 80, 200]:
		var fired: Array = _fired.filter(func(f): return int(f["lane"]) == lane)
		var struck: Array = _struck.filter(func(f): return int(f["lane"]) == lane)
		var shots: Array = _shots.filter(func(f): return int(f["lane"]) == lane)
		var first := "none"
		if not fired.is_empty():
			first = "%s pf%d" % [fired[0]["target"], int(fired[0]["pf"])]
		var shot_lines: Array = shots.map(func(s): return "%s spawn%d exit%d" % [s["target"], int(s["spawn_pf"]), int(s["exit_pf"])])
		print("PT136 LANE %s fired=%d first=%s struck=%d shots=%s" % [_lane_name(lane), fired.size(), first,
			struck.size(), str(shot_lines)])
	var r := "PT136 REPORT units=%d shots=%d fired=%d bursts=%d captured=%d a_full=%d b_full=%d c_struck=%d pf%d" % [
		units, _shots.size(), _fired.size(), bursts, captured, a_full, b_full, c_struck, _pf()]
	print(r)
	return r
