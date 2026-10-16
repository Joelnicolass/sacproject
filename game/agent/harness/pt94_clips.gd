extends Node

## Observation only (F94, RFC-028c): reads which clip the villagers play. Moves nothing and sets nothing.
##   clips("Farmer6,Taurock1")  one line per body: mode, clip role, SXSK tag, frame, Tilt scale y
##   summary()                   how many NPC play each mode/tag pair
##   watch("Farmer6")            records the clip role of every loop of that body; sequence() returns it
##   frame_ms(seconds)           starts a mean of the process + physics time; frame_report() prints it

var _seq: PackedStringArray = []
var _watched := ""
var _sample_left := 0.0
var _samples := 0
var _process_sum := 0.0
var _physics_sum := 0.0
var _frame_sum := 0.0
var _frame_max := 0.0


func _root() -> Node:
	return get_tree().current_scene


func _find(node_name: String) -> UnitBody:
	var root := _root()
	return root.find_child(node_name, true, false) as UnitBody if root else null


func clips(names_csv: String) -> String:
	var out: PackedStringArray = []
	for node_name in names_csv.split(","):
		var body := _find(node_name.strip_edges())
		if body == null:
			out.append("sin %s" % node_name)
			continue
		out.append(_line(body))
	return " | ".join(out)


func _line(body: UnitBody) -> String:
	var info := body.debug_clip_info()
	var tilt := body.get_node_or_null("Tilt") as Node3D
	return "%s mode=%s role=%s tag=%s frame=%d tilt_y=%.2f" % [
		body.name, UnitBody.Mode.keys()[int(body.mode)], info.get("role", ""), info.get("tag", ""),
		int(info.get("frame", 0)), tilt.scale.y if tilt else -1.0,
	]


func summary() -> String:
	var counts := {}
	for npc in get_tree().get_nodes_in_group("npc"):
		var body := npc as UnitBody
		if body == null:
			continue
		var key := "%s/%s" % [UnitBody.Mode.keys()[int(body.mode)], body.debug_clip_info().get("tag", "")]
		counts[key] = int(counts.get(key, 0)) + 1
	var keys := counts.keys()
	keys.sort()
	var out: PackedStringArray = []
	for key: String in keys:
		out.append("%s=%d" % [key, counts[key]])
	return " ".join(out)


func watch(node_name: String) -> String:
	var body := _find(node_name)
	if body == null:
		return "sin %s" % node_name
	var player := body.get_node_or_null("ClipPose") as ClipPosePlayer
	if player == null:
		return "sin ClipPose"
	_watched = node_name
	_seq.clear()
	player.clip_looped.connect(func(role: String) -> void: _seq.append(role))
	return "mirando %s" % node_name


func sequence() -> String:
	return "%s loops=%d %s" % [_watched, _seq.size(), ",".join(_seq)]


func frame_ms(seconds: float) -> String:
	_sample_left = seconds
	_samples = 0
	_process_sum = 0.0
	_physics_sum = 0.0
	_frame_sum = 0.0
	_frame_max = 0.0
	return "midiendo %.1f s" % seconds


func frame_report() -> String:
	if _samples == 0:
		return "sin muestras"
	return "frames=%d process_ms=%.3f physics_ms=%.3f frame_ms=%.3f max_ms=%.2f" % [
		_samples, _process_sum / _samples, _physics_sum / _samples, _frame_sum / _samples, _frame_max,
	]


func _process(delta: float) -> void:
	if _sample_left <= 0.0:
		return
	_sample_left -= delta
	_samples += 1
	_process_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_physics_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_frame_sum += delta * 1000.0
	_frame_max = maxf(_frame_max, delta * 1000.0)
