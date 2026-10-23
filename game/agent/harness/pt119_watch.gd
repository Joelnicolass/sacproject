extends Node

## Read-only observer for the F119 playtest (RFC-030 030h, splash shots). It never moves, orders, damages or spawns
## anything: it listens to Health.hurt of every unit, to shots entering the tree (RangedShot) and re-frames the screen
## camera (like a player scrolling the view) to save the rendered viewport around each lane's first shot.
##
##   arm()     connects to the units present (group "unit") and to SceneTree.node_added. Tolerates scene == null.
##   report()  prints one line per unit: hp at arm, now, every hurt (amount, kind).
## Per lane (z offset from 1270: -30 Mutant babt, 0 Abomination tugt, +30 Flummox crba) the first shot is followed:
## captures when it is < 9 m from its target (fly), and 2, 8 and 20 frames after it bursts (hit_a/b/c).
## One capture every 2 frames (frame camera, then save). Files: agent/out/pt119/<tag>_<label>.png.
## Props for wait_until: units, bursts (lanes whose first shot burst), captured.

const _SHOT := preload("res://scenes/units/attacks/ranged_shot.gd")
const CENTER_Z := 1270.0
const OUT_DIR := "res://agent/out/pt119"
const AFTER := {2: "hit_a", 8: "hit_b", 20: "hit_c"}

var units := 0
var bursts := 0
var captured := 0
var shots_seen := 0

var _info: Dictionary = {}     # unit -> {name, tag, slot, lane, hp0, hurt: Array[String]}
var _lane_shot: Dictionary = {} # lane -> {node, tag, last: Vector3, fly_done, burst_frame}
var _queue: Array = []         # [{lane, label, node (or null), at: Vector3, look: Vector3}]
var _frame := 0
var _phase := 0                # 0 = frame next, 1 = save
var _armed := false


func _ready() -> void:
	process_priority = 1000


func _terrain() -> TerrainShape:
	if get_tree().current_scene == null:
		return null
	return TerrainShape.of(self)


func _ground_y(x: float, z: float) -> float:
	var t := _terrain()
	if t == null:
		return 0.0
	var y := t.height_at(x, z)
	return 0.0 if is_nan(y) else y


func _tag(node: Node) -> String:
	var type: Variant = node.get("type")
	return str(type.get("tag")) if type != null else "?"


func _lane_of(z: float) -> int:
	return int(roundf((z - CENTER_Z) / 30.0)) * 30


func _name(node: Node) -> String:
	if node.has_method("display_name"):
		var dyn: Variant = node
		return str(dyn.display_name())
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
		_info[body] = {"name": _name(body), "tag": _tag(body), "slot": int(body.get("owner_slot")),
			"lane": _lane_of(body.global_transform.origin.z), "hp0": hp, "max": float(health.get("maximum")), "hurt": []}
		health.connect("hurt", _on_hurt.bind(body))
		units += 1
		var o := body.global_transform.origin
		print("PT119 UNIT %s tag=%s slot=%d lane=%+d hp=%.1f/%.1f at=(%.1f, %.1f, %.1f)" % [_info[body]["name"],
			_info[body]["tag"], _info[body]["slot"], _info[body]["lane"], hp, float(health.get("maximum")), o.x, o.y, o.z])
	if not _armed:
		_armed = true
		get_tree().node_added.connect(_on_node_added)
	return "armed %d" % units


func _on_hurt(amount: float, kind: StringName, from_slot: int, body: Node3D) -> void:
	var i: Dictionary = _info[body]
	var h := body.get_node_or_null("Health")
	var line := "%.2f %s s%d f%d" % [amount, kind, from_slot, _frame]
	i["hurt"].append(line)
	print("PT119 HURT %s lane=%+d %s hp_now=%.1f" % [i["name"], i["lane"], line, float(h.get("current")) if h else NAN])


func _on_node_added(node: Node) -> void:
	if node.get_script() != _SHOT:
		return
	var shot := node as Node3D
	shots_seen += 1
	var tag := ""
	var ab: Variant = shot.get("ability")
	if ab != null:
		tag = str(ab.get("tag"))
	var o := shot.global_transform.origin
	var lane := _lane_of(o.z)
	print("PT119 SHOT_SPAWN %s tag=%s lane=%+d at=(%.1f, %.1f, %.1f) f%d" % [shot.name, tag, lane, o.x, o.y, o.z, _frame])
	if _lane_shot.has(lane):
		return
	_lane_shot[lane] = {"node": shot, "tag": tag, "last": o, "fly_done": false, "burst_frame": -1}
	shot.tree_exiting.connect(_on_shot_exit.bind(lane, shot))


func _on_shot_exit(lane: int, shot: Node3D) -> void:
	var s: Dictionary = _lane_shot[lane]
	if s["node"] != shot:
		return
	s["last"] = shot.global_transform.origin
	s["burst_frame"] = _frame
	s["node"] = null
	bursts += 1
	var p: Vector3 = s["last"]
	print("PT119 SHOT_GONE tag=%s lane=%+d at=(%.2f, %.2f, %.2f) f%d" % [s["tag"], lane, p.x, p.y, p.z, _frame])


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
	for lane in _lane_shot:
		var s: Dictionary = _lane_shot[lane]
		var shot: Node3D = s["node"]
		if shot != null and is_instance_valid(shot):
			s["last"] = shot.global_transform.origin
			if not s["fly_done"]:
				var target := shot.get_node_or_null(shot.get("target_path")) as Node3D
				if target != null and target.global_transform.origin.distance_to(s["last"]) < 9.0:
					s["fly_done"] = true
					_queue.append({"lane": lane, "label": "%s_fly" % s["tag"], "node": shot, "at": s["last"]})
		var bf := int(s["burst_frame"])
		if bf >= 0 and AFTER.has(_frame - bf):
			_queue.append({"lane": lane, "label": "%s_%s" % [s["tag"], AFTER[_frame - bf]], "node": null, "at": s["last"]})
	if _queue.is_empty():
		return
	var item: Dictionary = _queue[0]
	if _phase == 0:
		var at: Vector3 = item["at"]
		var n: Variant = item["node"]
		if n != null and is_instance_valid(n):
			at = (n as Node3D).global_transform.origin
			item["at"] = at
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
	print("PT119 PNG %s at=(%.1f, %.1f, %.1f) f%d err=%d" % [path, p.x, p.y, p.z, _frame, err])


func report() -> String:
	for body in _info:
		var i: Dictionary = _info[body]
		var hp := NAN
		if is_instance_valid(body):
			var h: Node = body.get_node_or_null("Health")
			hp = float(h.get("current")) if h else NAN
		print("PT119 STATE %s tag=%s slot=%d lane=%+d hp0=%.1f now=%.1f hurt=%s" % [i["name"], i["tag"], i["slot"],
			i["lane"], float(i["hp0"]), hp, str(i["hurt"])])
	var r := "PT119 REPORT units=%d shots=%d bursts=%d captured=%d" % [units, shots_seen, bursts, captured]
	print(r)
	return r
