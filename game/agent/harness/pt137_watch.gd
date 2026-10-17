extends Node

## Read-only observer for the F137 playtest (RFC-030 030i-b, Basilisk petrify) on res://debug/f137_petrify.tscn.
## It never moves, orders, damages, petrifies or spawns anything: it polls each unit's Afflictions.shown, listens to
## UnitBody.struck and Health.hit / hurt, and re-frames the screen camera (as a player scrolling the view) to save the
## rendered viewport. Tolerates a null scene.
##
##   arm()     connects to the units present (group "unit").
##   report()  per unit: stone episodes (frames shown, of them unpaused / paused, drift, clip changes, health at start
##             vs the frame before, height over ground), hits taken (ratio to the raw strike, P = while stone),
##             non-melee hits, struck after it got up, and for a flier the height after.
## Lanes: A z > 1270+40, B z < 1270-40, C otherwise.
## Props for wait_until: druid_stone (Druid of lane A is stone now), done (all three lanes ended a stone, the Druid
## struck after it, the Gargoyle had 300 frames after; or LIMIT_FRAMES).

const PETRIFIED_BIT := 2
const CENTER_Z := 1270.0
const OUT_DIR := "res://agent/out/pt137"
const LIMIT_FRAMES := 4200

var done := false
var druid_stone := false
var units := 0
## Prepended to every PNG name (set by arm), so a second flow does not overwrite the first.
var prefix := ""

var _info: Dictionary = {}
var _queue: Array = []
var _phase := 0
var _armed_frame := -1
var _hp_prev: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	process_physics_priority = 1000


func _name(node: Node) -> String:
	if node.has_method("display_name"):
		var dyn: Variant = node
		return str(dyn.display_name())
	return str(node.name)


func _lane(z: float) -> String:
	if z > CENTER_Z + 40.0:
		return "A"
	if z < CENTER_Z - 40.0:
		return "B"
	return "C"


func arm(png_prefix: String = "") -> String:
	prefix = png_prefix
	if get_tree() == null or get_tree().current_scene == null:
		return "armed 0 (no scene)"
	for node in get_tree().get_nodes_in_group("unit"):
		var body := node as Node3D
		if body == null or _info.has(body) or body.get_node_or_null("Afflictions") == null:
			continue
		var o := body.global_transform.origin
		var health := body.get_node_or_null("Health")
		_info[body] = {"name": _name(body), "slot": int(body.get("owner_slot")), "lane": _lane(o.z), "episodes": [],
			"cur": {}, "pending": -1.0, "pending_pf": -1, "ratios": [], "other_hits": [], "hurts": [], "back": "",
			"after_frames": 0, "after_h": NAN, "hp0": float(health.get("current")) if health else NAN}
		if body.has_signal("struck"):
			body.connect("struck", _on_struck.bind(body))
		if health:
			health.connect("hit", _on_hit.bind(body))
			health.connect("hurt", _on_hurt.bind(body))
		units += 1
		print("PT137 UNIT %s slot=%d lane=%s at=(%.2f, %.2f, %.2f) hp=%.1f" % [_info[body]["name"], _info[body]["slot"],
			_info[body]["lane"], o.x, o.y, o.z, _info[body]["hp0"]])
	_armed_frame = Engine.get_physics_frames()
	return "armed %d" % units


func _stone(body: Node3D) -> bool:
	return int(body.get_node("Afflictions").get("shown")) & PETRIFIED_BIT != 0


func _flush_pending(body: Node3D) -> void:
	var i: Dictionary = _info[body]
	if float(i["pending"]) >= 0.0:
		(i["other_hits"] as Array).append("%.2f pf=%d" % [float(i["pending"]), int(i["pending_pf"])])
		i["pending"] = -1.0


func _on_hit(amount: float, from_slot: int, _full: bool, body: Node3D) -> void:
	_flush_pending(body)
	_info[body]["pending"] = amount
	_info[body]["pending_pf"] = Engine.get_physics_frames()
	_info[body]["pending_stone"] = _stone(body)
	_info[body]["pending_slot"] = from_slot


func _on_struck(target: Node3D, amount: float, _c: float, _r: float, body: Node3D) -> void:
	var i: Dictionary = _info[body]
	var aff: Variant = body.get_node("Afflictions")
	if (i["episodes"] as Array).size() > 0 and (i["cur"] as Dictionary).is_empty() and str(i["back"]).is_empty() \
			and not bool(aff.holds()):
		i["back"] = "pf=%d -> %s %.1f" % [Engine.get_physics_frames(), _name(target) if target else "?", amount]
		print("PT137 BACK %s %s" % [i["name"], i["back"]])
		if i["lane"] == "A":
			_queue.append({"label": "a_druid_back_fighting", "body": body})
	if target == null or not _info.has(target):
		return
	var t: Dictionary = _info[target]
	if float(t["pending"]) >= 0.0 and amount > 0.0:
		var line := "%.2f/%.2f=%.3f%s" % [float(t["pending"]), amount, float(t["pending"]) / amount,
			"P" if bool(t.get("pending_stone", false)) else ""]
		(t["ratios"] as Array).append(line)
		print("PT137 HIT %s <- %s %s pf=%d" % [t["name"], i["name"], line, Engine.get_physics_frames()])
	t["pending"] = -1.0


func _on_hurt(amount: float, kind: StringName, from_slot: int, body: Node3D) -> void:
	var line := "%.2f %s s%d pf=%d stone=%s" % [amount, kind, from_slot, Engine.get_physics_frames(), _stone(body)]
	(_info[body]["hurts"] as Array).append(line)
	print("PT137 HURT %s %s" % [_info[body]["name"], line])


func _ray_above(body: Node3D) -> float:
	var o := body.global_transform.origin
	var q := PhysicsRayQueryParameters3D.create(o + Vector3.UP * 50.0, o + Vector3.DOWN * 50.0)
	q.collision_mask = 1
	if body is CollisionObject3D:
		q.exclude = [(body as CollisionObject3D).get_rid()]
	var hit := body.get_world_3d().direct_space_state.intersect_ray(q)
	return o.y - float(hit.position.y) if not hit.is_empty() else NAN


func _key(body: Node3D) -> String:
	var clip: Variant = body.get_node_or_null("ClipPose")
	var mesh := body.get_node_or_null("Tilt/Mesh") as MeshInstance3D
	if clip == null or mesh == null:
		return "?"
	return "%s/%d/%s" % [clip.active_role(), int(clip.active_frame()), str(mesh.mesh)]


func _physics_process(_delta: float) -> void:
	if _armed_frame < 0 or get_tree().current_scene == null:
		return
	var now := Engine.get_physics_frames()
	var paused := get_tree().paused
	for key: Variant in _info.keys():
		if not is_instance_valid(key):
			continue
		var body := key as Node3D
		var i: Dictionary = _info[body]
		_flush_pending(body)
		var stone := _stone(body)
		var cur: Dictionary = i["cur"]
		var o := body.global_transform.origin
		var hp := float(body.get_node("Health").get("current"))
		if stone and cur.is_empty():
			cur = {"start": now, "at": o, "drift": 0.0, "key": _key(body), "changes": 0, "unpaused": 1, "paused": 0,
				"hp_before": float(_hp_prev.get(body, hp)), "hp_start": hp, "min_ray": _ray_above(body),
				"max_ray": _ray_above(body), "ray_start": _ray_above(body), "grey": 0}
			i["cur"] = cur
			print("PT137 STONE_ON %s lane=%s pf=%d hp_before=%.2f hp_now=%.2f ray=%.3f key=%s" % [i["name"], i["lane"],
				now, cur["hp_before"], hp, cur["ray_start"], cur["key"]])
			var lbl: String = {"A": "a_druid", "B": "b_flummox", "C": "c_gargoyle"}[i["lane"]] if i["slot"] == 2 else "x_%s" % i["name"]
			cur["label"] = lbl
			if i["lane"] == "A" and i["slot"] == 2:
				druid_stone = true
		elif stone:
			if paused:
				cur["paused"] = int(cur["paused"]) + 1
			else:
				cur["unpaused"] = int(cur["unpaused"]) + 1
			cur["drift"] = maxf(float(cur["drift"]), Vector2(o.x - cur["at"].x, o.z - cur["at"].z).length())
			var k := _key(body)
			if k != str(cur["key"]):
				cur["changes"] = int(cur["changes"]) + 1
				print("PT137 CLIP_CHANGE %s %s -> %s pf=%d" % [i["name"], cur["key"], k, now])
				cur["key"] = k
			var mesh := body.get_node_or_null("Tilt/Mesh") as MeshInstance3D
			if mesh and mesh.get_surface_override_material_count() > 0 and mesh.get_surface_override_material(0) is ShaderMaterial:
				cur["grey"] = int(cur["grey"]) + 1
			var r := _ray_above(body)
			if not paused and int(cur["unpaused"]) > 60:
				cur["min_ray"] = minf(float(cur["min_ray"]), r)
				cur["max_ray"] = maxf(float(cur["max_ray"]), r)
			var e := int(cur["unpaused"])
			if not paused and (e == 90 or e == 240):
				_queue.append({"label": "%s_stone_%d" % [cur["label"], e], "body": body, "near": i["lane"] == "A"})
		elif not cur.is_empty():
			cur["end"] = now
			cur["hp_end"] = hp
			(i["episodes"] as Array).append(cur)
			i["cur"] = {}
			i["after_frames"] = 0
			print("PT137 STONE_OFF %s lane=%s pf=%d frames=%d unpaused=%d paused=%d drift=%.4f clip_changes=%d grey=%d min_ray=%.3f max_ray=%.3f" % [
				i["name"], i["lane"], now, now - int(cur["start"]), cur["unpaused"], cur["paused"], cur["drift"], cur["changes"],
				cur["grey"], cur["min_ray"], cur["max_ray"]])
			_queue.append({"label": "%s_rocks_a" % cur["label"], "body": body, "delay": 4})
			_queue.append({"label": "%s_rocks_b" % cur["label"], "body": body, "delay": 14})
		if not stone and (i["episodes"] as Array).size() > 0 and not paused:
			i["after_frames"] = int(i["after_frames"]) + 1
			if int(i["after_frames"]) <= 900:
				var r2 := _ray_above(body)
				i["after_h"] = r2 if is_nan(float(i["after_h"])) else maxf(float(i["after_h"]), r2)
			if i["lane"] == "C" and int(i["after_frames"]) == 400:
				_queue.append({"label": "c_gargoyle_after_400", "body": body})
		_hp_prev[body] = hp
		if i["lane"] == "A" and i["slot"] == 2 and not stone:
			druid_stone = false
	if not done and not paused:
		var ok := 0
		for key: Variant in _info.keys():
			var i: Dictionary = _info[key]
			if i["slot"] != 2 or (i["episodes"] as Array).is_empty():
				continue
			if i["lane"] == "A" and not str(i["back"]).is_empty():
				ok += 1
			elif i["lane"] == "B" and int(i["after_frames"]) > 200:
				ok += 1
			elif i["lane"] == "C" and int(i["after_frames"]) > 420:
				ok += 1
		if ok >= 3 or now - _armed_frame > LIMIT_FRAMES:
			done = true
			print("PT137 DONE ok=%d pf=%d" % [ok, now])


func _process(_delta: float) -> void:
	if _queue.is_empty() or get_tree() == null or get_tree().current_scene == null:
		return
	var item: Dictionary = _queue[0]
	var raw: Variant = item["body"]
	if raw == null or not is_instance_valid(raw):
		_queue.pop_front()
		return
	var body := raw as Node3D
	if int(item.get("delay", 0)) > 0:
		item["delay"] = int(item["delay"]) - 1
		return
	var cam := get_viewport().get_camera_3d()
	if _phase == 0:
		if cam:
			var at := body.global_transform.origin
			var off: Vector3 = Vector3(1.2, 2.2, 3.2) if bool(item.get("near", false)) else Vector3(5.0, 6.0, 11.0)
			if str(item["label"]).begins_with("c_gargoyle_after"):
				off = Vector3(0.0, 2.0, -14.0)
			cam.look_at_from_position(at + off, at + Vector3.UP * 0.8, Vector3.UP)
		_phase = 1
		return
	_phase = 0
	_queue.pop_front()
	var path := "%s/%s%s.png" % [OUT_DIR, prefix, item["label"]]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var err := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("PT137 PNG %s %s stone=%s ray=%.3f key=%s err=%d pf=%d" % [path, _info[body]["name"], _stone(body),
		_ray_above(body), _key(body), err, Engine.get_physics_frames()])


func report() -> String:
	for key: Variant in _info.keys():
		var i: Dictionary = _info[key]
		var alive := is_instance_valid(key)
		var eps := []
		for ep: Dictionary in i["episodes"]:
			eps.append("[pf %d..%d=%d unpaused %d paused %d drift %.4f clip_changes %d grey %d hp_before %.2f hp_start %.2f hp_end %.2f ray_start %.3f min_ray %.3f max_ray %.3f]" % [
				ep["start"], ep["end"], int(ep["end"]) - int(ep["start"]), ep["unpaused"], ep["paused"], ep["drift"],
				ep["changes"], ep["grey"], ep["hp_before"], ep["hp_start"], ep["hp_end"], ep["ray_start"], ep["min_ray"],
				ep["max_ray"]])
		print("PT137 STATE %s slot=%d lane=%s alive=%s eps=%s ratios=%s other_hits=%s hurts=%s back=%s after_h=%.3f" % [
			i["name"], i["slot"], i["lane"], alive, " ".join(eps), str(i["ratios"]), str(i["other_hits"]),
			str(i["hurts"]), i["back"], float(i["after_h"])])
	return "PT137 REPORT units=%d done=%s" % [units, done]
