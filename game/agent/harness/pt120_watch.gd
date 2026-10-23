extends Node

## Read-only observer for the F120 playtest (RFC-030 030i-a, Flummox stun) on res://debug/units/f118_stun.tscn. It never
## moves, orders, damages or spawns anything: it polls each unit's Afflictions (holds / shown), listens to UnitBody.struck
## and Health.hurt, and re-frames the screen camera (like a player scrolling the view) to save the rendered viewport.
##
##   arm()     connects to the units present (group "unit"). Tolerates a null scene.
##   report()  one line per stun episode (frames held, max drift while held, struck while held) and per unit the first
##             struck after it got up.
## Lane A is z ≈ 1270+80, lane B z ≈ 1270−80. Captures of the first stunned Druid of lane A: down (end of the knock),
## rising (half of the get-up) and up (20 frames after); lane B: the cluster 40 frames after the first stun there.
## Props for wait_until: done (true once lane A has 3 Druids back in the fight and lane B 3 stuns, or 2400 frames).

const CENTER_Z := 1270.0
const OUT_DIR := "res://agent/out/pt120"
const LIMIT_FRAMES := 2400

var done := false
var units := 0

var _info: Dictionary = {}   # body -> {name, tag, slot, lane, episodes: Array, cur, back_struck}
var _queue: Array = []       # [{label, body}]
var _phase := 0
var _frame := 0
var _armed_frame := -1
var _a_watch: Node3D = null  # the Druid of lane A whose look is captured
var _b_shot := false
var _b_first := -1


func _ready() -> void:
	process_priority = 1000
	process_physics_priority = 1000


func _terrain() -> TerrainShape:
	if get_tree().current_scene == null:
		return null
	return TerrainShape.of(self)


func _name(node: Node) -> String:
	if node.has_method("display_name"):
		var dyn: Variant = node
		return str(dyn.display_name())
	return str(node.name)


func _tag(node: Node) -> String:
	var t: Variant = node.get("creature_tag")
	return str(t) if t != null else "?"


func _lane(z: float) -> String:
	if z > CENTER_Z + 40.0:
		return "A"
	if z < CENTER_Z - 40.0:
		return "B"
	return "-"


func arm() -> String:
	if get_tree().current_scene == null:
		return "armed 0 (no scene)"
	for node in get_tree().get_nodes_in_group("unit"):
		var body := node as Node3D
		if body == null or _info.has(body) or body.get_node_or_null("Afflictions") == null:
			continue
		var o := body.global_transform.origin
		_info[body] = {"name": _name(body), "tag": _tag(body), "slot": int(body.get("owner_slot")), "lane": _lane(o.z),
			"episodes": [], "cur": {}, "back_struck": "", "hurts": []}
		if body.has_signal("struck"):
			body.connect("struck", _on_struck.bind(body))
		var health := body.get_node_or_null("Health")
		if health and health.has_signal("hurt"):
			health.connect("hurt", _on_hurt.bind(body))
		units += 1
		print("PT120 UNIT %s tag=%s slot=%d lane=%s at=(%.2f, %.2f, %.2f)" % [_info[body]["name"], _info[body]["tag"],
			_info[body]["slot"], _info[body]["lane"], o.x, o.y, o.z])
	_armed_frame = Engine.get_physics_frames()
	return "armed %d" % units


func _held(body: Node3D) -> bool:
	var aff: Variant = body.get_node_or_null("Afflictions")
	return aff != null and bool(aff.holds())


func _on_struck(foe: Node3D, amount: float, _chance: float, _roll: float, body: Node3D) -> void:
	var i: Dictionary = _info[body]
	var held := _held(body)
	var fname := _name(foe) if foe != null and is_instance_valid(foe) else "?"
	var ftag := _tag(foe) if foe != null and is_instance_valid(foe) else "?"
	print("PT120 STRUCK %s lane=%s -> %s(%s) %.1f held=%s pf=%d" % [i["name"], i["lane"], fname, ftag, amount, held,
		Engine.get_physics_frames()])
	var cur: Dictionary = i["cur"]
	if held and not cur.is_empty():
		cur["struck_held"] = int(cur.get("struck_held", 0)) + 1
	if not held and (i["episodes"] as Array).size() > 0 and str(i["back_struck"]).is_empty():
		i["back_struck"] = "%s(%s) pf=%d" % [fname, ftag, Engine.get_physics_frames()]


func _on_hurt(amount: float, kind: StringName, from_slot: int, body: Node3D) -> void:
	var i: Dictionary = _info[body]
	var line := "%.1f %s s%d pf=%d held=%s" % [amount, kind, from_slot, Engine.get_physics_frames(), _held(body)]
	(i["hurts"] as Array).append(line)
	print("PT120 HURT %s lane=%s %s" % [i["name"], i["lane"], line])


func _physics_process(_delta: float) -> void:
	_track_dead()
	if _armed_frame < 0 or get_tree().current_scene == null:
		return
	var now := Engine.get_physics_frames()
	for body: Node3D in _info:
		if not is_instance_valid(body):
			continue
		var i: Dictionary = _info[body]
		var held := _held(body)
		var cur: Dictionary = i["cur"]
		var o := body.global_transform.origin
		if held and cur.is_empty():
			var st := body.get_node_or_null("Afflictions/Stunned")
			cur = {"start": now, "at": o, "drift": 0.0, "struck_held": 0,
				"knock": int(st.get("_knock_ticks")) if st else -1, "total": int(st.get("_total")) if st else -1}
			i["cur"] = cur
			print("PT120 HOLD_ON %s lane=%s pf=%d knock=%d total=%d" % [i["name"], i["lane"], now, cur["knock"], cur["total"]])
			if i["lane"] == "A" and i["tag"] == "nmuh" and _a_watch == null:
				_a_watch = body
			if i["lane"] == "B" and _b_first < 0:
				_b_first = now
		elif held:
			cur["drift"] = maxf(float(cur["drift"]), o.distance_to(cur["at"]))
		elif not cur.is_empty():
			cur["end"] = now
			(i["episodes"] as Array).append(cur)
			print("PT120 HOLD_OFF %s lane=%s pf=%d held_frames=%d drift=%.4f struck_held=%d" % [i["name"], i["lane"], now,
				now - int(cur["start"]), float(cur["drift"]), int(cur["struck_held"])])
			i["cur"] = {}
		if body == _a_watch and not cur.is_empty():
			var e := now - int(cur["start"])
			var knock := int(cur["knock"])
			var total := int(cur["total"])
			if e == maxi(knock - 6, 25):
				_queue.append({"label": "a_druid_down", "body": body})
			elif e == knock + (total - knock) / 2:
				_queue.append({"label": "a_druid_rising", "body": body})
		if body == _a_watch and cur.is_empty() and (i["episodes"] as Array).size() == 1:
			var ep: Dictionary = (i["episodes"] as Array)[0]
			if now - int(ep["end"]) == 20:
				_queue.append({"label": "a_druid_up", "body": body})
	if _b_first >= 0 and not _b_shot and now - _b_first == 40:
		_b_shot = true
		for body: Node3D in _info:
			if is_instance_valid(body) and _info[body]["lane"] == "B" and _info[body]["tag"] == "wlce":
				_queue.append({"label": "b_cluster", "body": body})
	if not done:
		var back := 0
		var b_stuns := 0
		for body: Node3D in _info:
			var i: Dictionary = _info[body]
			if i["lane"] == "A" and i["tag"] == "nmuh" and not str(i["back_struck"]).is_empty():
				back += 1
			if i["lane"] == "B" and ((i["episodes"] as Array).size() > 0 or not (i["cur"] as Dictionary).is_empty()):
				b_stuns += 1
		var a_start := -1
		if _a_watch != null and _info.has(_a_watch) and (_info[_a_watch]["episodes"] as Array).size() > 0:
			a_start = int((_info[_a_watch]["episodes"] as Array)[0]["start"])
		if (back >= 3 and b_stuns >= 3 and a_start >= 0 and now - a_start >= 600) or now - _armed_frame > LIMIT_FRAMES:
			done = true
			print("PT120 DONE back=%d b_stuns=%d pf=%d" % [back, b_stuns, now])


func _process(_delta: float) -> void:
	if _queue.is_empty() or get_tree().current_scene == null:
		return
	var item: Dictionary = _queue[0]
	var body: Node3D = item["body"]
	if body == null or not is_instance_valid(body):
		_queue.pop_front()
		return
	if _phase == 0:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var at := body.global_transform.origin
			var off := Vector3(1.5, 4.5, 5.0) if str(item["label"]).begins_with("a_") else Vector3(4.0, 7.0, 12.0)
			cam.look_at_from_position(at + off, at + Vector3.UP * 0.5, Vector3.UP)
		_phase = 1
		return
	_phase = 0
	_queue.pop_front()
	var path := "%s/%s.png" % [OUT_DIR, item["label"]]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var err := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	var tilt := body.get_node_or_null("Tilt") as Node3D
	var vis := body.get_node_or_null("Afflictions/Stunned")
	var radius := NAN
	var visual: Variant = vis.get("visual") if vis else null
	if visual != null and (visual as Node).has_method("body_radius"):
		radius = float(visual.body_radius())
	var o := body.global_transform.origin
	var t := _terrain()
	var ground := t.height_at(o.x, o.z) if t else NAN
	print("PT120 PNG %s %s tilt_z=%.1fdeg tilt_y=%.3f radius=%.3f body_y-ground=%.3f err=%d pf=%d" % [path,
		_info[body]["name"], rad_to_deg(tilt.rotation.z) if tilt else NAN, tilt.position.y if tilt else NAN, radius,
		o.y - ground, err, Engine.get_physics_frames()])


func report() -> String:
	for body: Node3D in _info:
		var i: Dictionary = _info[body]
		var eps := []
		for ep: Dictionary in i["episodes"]:
			eps.append("[pf %d..%d = %d, drift %.4f, struck_held %d]" % [ep["start"], ep["end"], int(ep["end"]) - int(ep["start"]),
				ep["drift"], ep["struck_held"]])
		print("PT120 STATE %s tag=%s slot=%d lane=%s alive=%s episodes=%s back_struck=%s hurts=%s" % [i["name"], i["tag"],
			i["slot"], i["lane"], is_instance_valid(body), " ".join(eps), i["back_struck"], str(i["hurts"])])
	return "PT120 REPORT units=%d done=%s" % [units, done]


# --- Play Dead regression (Fallen, dplk), read-only ---------------------------------------------------------------
var dead_frames := 0
var dead_drift := 0.0
var _dead: Node3D = null
var _dead_at := Vector3.ZERO


## Picks the player's own Fallen (slot 1, dplk) and starts tracking its drift while it plays dead.
func arm_dead() -> String:
	if get_tree().current_scene == null:
		return "arm_dead: no scene"
	for node in get_tree().get_nodes_in_group("unit"):
		var body := node as Node3D
		if body and _tag(body) == "dplk":
			_dead = body
			set_physics_process(true)
			return "arm_dead %s slot=%d" % [_name(body), int(body.get("owner_slot"))]
	return "arm_dead: no Fallen"


func dead_report() -> String:
	if _dead == null or not is_instance_valid(_dead):
		return "PT120 DEAD none"
	var aff: Variant = _dead.get_node_or_null("Afflictions")
	var dv: Variant = _dead
	var r := "PT120 DEAD %s playing=%s frames=%d drift=%.4f targetable=%s holds=%s shown=%d" % [_name(_dead),
		_dead.get("_playing_dead"), dead_frames, dead_drift, bool(dv.is_targetable()),
		bool(aff.holds()) if aff != null else false, int(aff.get("shown")) if aff != null else -1]
	print(r)
	return r


func _track_dead() -> void:
	if _dead == null or not is_instance_valid(_dead):
		return
	var o := _dead.global_transform.origin
	if bool(_dead.get("_playing_dead")):
		if dead_frames == 0:
			_dead_at = o
		dead_frames += 1
		dead_drift = maxf(dead_drift, o.distance_to(_dead_at))
