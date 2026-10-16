extends Node

## Observation helper (F114 playtest, RFC-030 030c). Read-only: never moves, casts or changes a rule.
##   start()   begins polling every wizard's Caster.is_casting() once per physics frame (solo / bench / host only:
##             on a pure client the cast lives on the server). Each cast prints
##             «CASTW inicio slot S frame F ms M» and «CASTW fin slot S frames N (X s) ms M (Y s)».
##             It also watches the frame times around every cast start and end and prints the longest one
##             of the next 60 frames («CASTW cuadros …»), to spot visible hitches when a creature appears.
##   frame(side_deg, dist_m, height_m)  re-frames the screen camera on the newest creature of slot 1, from its side
##             (like a player scrolling the view); frame(-1) hands the camera back. Nothing else moves.
##   report()  read-only summary line.
## Props for wait_until: casts_done (finished casts), last_frames (physics frames of the last cast).

var casts_done := 0
var last_frames := 0
var last_seconds := 0.0
var worst_ms := 0.0

var _started := false
var _state: Dictionary = {}
var _windows: Array = []
var _last_us := 0
var _summary: PackedStringArray = []
var _frame_args := Vector3.ZERO
var _framing := false


func _ready() -> void:
	process_priority = 1000
	process_physics_priority = 1000


func start() -> String:
	_started = true
	return "wizards %d" % get_tree().get_nodes_in_group("wizard").size()


func _physics_process(_delta: float) -> void:
	if not _started:
		return
	for wizard in get_tree().get_nodes_in_group("wizard"):
		var caster = wizard.get_node_or_null("Caster")
		if caster == null:
			continue
		var slot := int(wizard.get("owner_slot"))
		var casting: bool = caster.is_casting()
		var was: Dictionary = _state.get(slot, {})
		if casting and was.is_empty():
			_state[slot] = {"frame": Engine.get_physics_frames(), "ms": Time.get_ticks_msec()}
			print("CASTW inicio slot %d frame %d ms %d" % [slot, Engine.get_physics_frames(), Time.get_ticks_msec()])
			_windows.append({"what": "inicio slot %d" % slot, "left": 60, "max": 0.0})
		elif not casting and not was.is_empty():
			_state.erase(slot)
			var frames := Engine.get_physics_frames() - int(was["frame"])
			var ms := Time.get_ticks_msec() - int(was["ms"])
			last_frames = frames
			last_seconds = frames / float(Engine.physics_ticks_per_second)
			casts_done += 1
			var line := "slot %d frames %d (%.3f s) ms %d (%.3f s)" % [slot, frames, last_seconds, ms, ms / 1000.0]
			_summary.append(line)
			print("CASTW fin " + line)
			_windows.append({"what": "fin slot %d" % slot, "left": 60, "max": 0.0})


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := (now - _last_us) / 1000.0 if _last_us > 0 else 0.0
	_last_us = now
	for window in _windows:
		window["max"] = maxf(float(window["max"]), dt)
		window["left"] = int(window["left"]) - 1
		if int(window["left"]) == 0:
			worst_ms = maxf(worst_ms, float(window["max"]))
			print("CASTW cuadros tras %s: más largo %.1f ms" % [window["what"], window["max"]])
	_late_frame()
	_windows = _windows.filter(func(w: Dictionary) -> bool: return int(w["left"]) > 0)


func report() -> String:
	return "lanzamientos %d · peor cuadro %.1f ms · %s" % [casts_done, worst_ms, " | ".join(_summary)]


func _newest_own() -> Node3D:
	var scene := get_tree().current_scene
	var units := scene.find_child("Units", true, false) if scene else null
	if units == null:
		return null
	var best: Node3D = null
	for unit in units.get_children():
		if unit is Node3D and int(unit.get("owner_slot")) == 1:
			best = unit
	return best


func frame(side_deg: float, dist_m: float = 12.0, height_m: float = 4.0) -> String:
	_framing = side_deg >= 0.0
	_frame_args = Vector3(side_deg, dist_m, height_m)
	var unit = _newest_own()
	return unit.display_name() if unit != null and unit.has_method("display_name") else "sin criatura"


func _late_frame() -> void:
	if not _framing:
		return
	var unit := _newest_own()
	var cam := get_viewport().get_camera_3d()
	if unit == null or cam == null:
		return
	var at := unit.global_transform.origin
	var dir := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(_frame_args.x))
	cam.look_at_from_position(at + dir * _frame_args.y + Vector3.UP * _frame_args.z, at + Vector3.UP * (_frame_args.z * 0.4), Vector3.UP)
