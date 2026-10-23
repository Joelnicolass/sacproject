extends Node

## Read-only observer for the F118 playtest (RFC-030 030g, death clouds). It never moves, orders, damages or spawns
## anything. It listens to Health.hurt / changed / died of every unit, re-frames the screen camera (like a player
## scrolling the view) and saves the rendered viewport right after each cloud creature dies.
##
##   arm()       connects to the units present (group "unit"). Returns the count. Tolerates scene == null.
##   report()    prints one line per unit: hp at arm, at the lane's death, now; damage by kind; healed.
## When a cloud creature (zidf / glsd / cbab) dies: snapshot of its lane, then the camera is framed on that lane and
## the viewport is saved to agent/out/pt118/cloud_<tag>_r<round>.png. Rounds start 3, 12 and 24 frames after the
## first death; in each round every dead creature spot gets 2 frames of camera (framed on the 1st, saved on the 2nd).
## Lanes are z offsets from the center (1270, 1270): -45 Cog, 0 Necryl, +45 Mutant. Timed snapshots +1..+6 s.
## Props for wait_until: units, deaths, captured.

const CENTER := Vector2(1270.0, 1270.0)
const CLOUD_TAGS := {"zidf": "goc@", "glsd": "cen@", "cbab": "tum@"}
const OUT_DIR := "res://agent/out/pt118"
const ROUND_AT := [3, 12, 24]

var units := 0
var deaths := 0
var captured := 0

var _info: Dictionary = {}       # unit -> {name, tag, slot, lane, hp0, last, hurt:{kind:sum}, healed, max_seen}
var _lane_death: Dictionary = {} # lane -> {t, tag, snap:{name:hp}}
var _queue: Array = []           # [{lane, tag}]
var _cur_frames := 0
var _cur_shot := 0
var _t := 0.0
var _timed: Array = []           # [{lane, at, label}]


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


func _lane(node: Node3D) -> int:
	var dz := node.global_transform.origin.z - CENTER.y
	return int(roundf(dz / 45.0)) * 45


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
		_info[body] = {"name": _name(body), "tag": _tag(body), "slot": int(body.get("owner_slot")), "lane": _lane(body),
			"hp0": hp, "last": hp, "max": float(health.get("maximum")), "hurt": {}, "healed": 0.0, "max_seen": hp}
		health.connect("hurt", _on_hurt.bind(body))
		health.connect("changed", _on_changed.bind(body))
		health.connect("died", _on_died.bind(body))
		units += 1
		print("PT118 UNIT %s tag=%s slot=%d lane=%+d hp=%.1f/%.1f" % [_info[body]["name"], _info[body]["tag"],
			_info[body]["slot"], _info[body]["lane"], hp, float(health.get("maximum"))])
	return "armed %d" % units


func _on_hurt(amount: float, kind: StringName, from_slot: int, body: Node3D) -> void:
	var i: Dictionary = _info[body]
	var key := "%s/s%d" % [kind, from_slot]
	i["hurt"][key] = float(i["hurt"].get(key, 0.0)) + amount


func _on_changed(current: float, _maximum: float, body: Node3D) -> void:
	var i: Dictionary = _info[body]
	if current > float(i["last"]):
		i["healed"] = float(i["healed"]) + current - float(i["last"])
	i["last"] = current
	i["max_seen"] = maxf(float(i["max_seen"]), current)


func _on_died(_from_slot: int, body: Node3D) -> void:
	var i: Dictionary = _info[body]
	var tag: String = i["tag"]
	print("PT118 DIED %s tag=%s lane=%+d t=%.2f" % [i["name"], tag, i["lane"], _t])
	if not CLOUD_TAGS.has(tag):
		return
	var lane: int = i["lane"]
	_lane_death[lane] = {"t": _t, "tag": tag, "snap": _snap(lane)}
	print("PT118 BEFORE lane=%+d %s" % [lane, _snap_text(lane)])
	deaths += 1
	_queue.append({"lane": lane, "tag": tag, "at": body.global_transform.origin})
	for s in [1, 2, 3, 4, 5, 6]:
		_timed.append({"lane": lane, "at": _t + float(s), "label": "+%ds" % s})


func _snap(lane: int) -> Dictionary:
	var out := {}
	for body in _info:
		if _info[body]["lane"] == lane:
			out[_info[body]["name"] + "#s%d" % _info[body]["slot"]] = _hp(body)
	return out


func _hp(body: Variant) -> float:
	if not is_instance_valid(body):
		return 0.0
	var h: Node = body.get_node_or_null("Health")
	return float(h.get("current")) if h != null else 0.0


func _snap_text(lane: int) -> String:
	var parts: Array[String] = []
	var snap := _snap(lane)
	for k in snap:
		parts.append("%s=%.1f" % [k, float(snap[k])])
	return " ".join(parts)


func frame(x: float, z: float, ox: float, oy: float, oz: float) -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return "no camera"
	var look := Vector3(x, _ground_y(x, z), z)
	cam.look_at_from_position(look + Vector3(ox, oy, oz), look, Vector3.UP)
	return "framed (%.0f, %.0f)" % [x, z]


func _process(delta: float) -> void:
	_t += delta
	for e in _timed.duplicate():
		if _t >= float(e["at"]):
			_timed.erase(e)
			print("PT118 T lane=%+d %s %s" % [e["lane"], e["label"], _snap_text(int(e["lane"]))])
	if _queue.is_empty():
		return
	_cur_frames += 1
	if _cur_shot >= ROUND_AT.size():
		return
	var since := _cur_frames - int(ROUND_AT[_cur_shot])
	if since < 0:
		return
	var idx := int(since / 2.0)
	if idx >= _queue.size():
		_cur_shot += 1
		if _cur_shot == ROUND_AT.size():
			captured = _queue.size()
		return
	var item: Dictionary = _queue[idx]
	var at: Vector3 = item["at"]
	if since % 2 == 0:
		frame(at.x, at.z, 0.0, 5.0, 6.5)
		return
	var path := "%s/cloud_%s_r%d.png" % [OUT_DIR, item["tag"], _cur_shot]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(ProjectSettings.globalize_path(path))
	var dt := _t - float(_lane_death[int(item["lane"])]["t"])
	print("PT118 SHOT %s dt=%.2f err=%d" % [path, dt, err])


func report() -> String:
	for body in _info:
		var i: Dictionary = _info[body]
		var lane: int = i["lane"]
		var at_death := "-"
		if _lane_death.has(lane):
			var key: String = i["name"] + "#s%d" % i["slot"]
			at_death = "%.1f" % float(_lane_death[lane]["snap"].get(key, NAN))
		print("PT118 STATE %s tag=%s slot=%d lane=%+d hp0=%.1f at_death=%s now=%.1f/%.1f max_seen=%.1f healed=%.1f hurt=%s" % [
			i["name"], i["tag"], i["slot"], lane, float(i["hp0"]), at_death, _hp(body), float(i["max"]),
			float(i["max_seen"]), float(i["healed"]), str(i["hurt"])])
	var r := "PT118 REPORT units=%d deaths=%d captured=%d" % [units, deaths, captured]
	print(r)
	return r
