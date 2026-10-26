extends Node

## Bench of what deforming the ground costs on the main thread (063D perf diagnosis, 2026-10-26). Loads cast_terrain.tscn (High Noon),
## turns the high preset on so the flora listens, and plays three phases of `phase_s` seconds each:
## - baseline: nothing moves;
## - live: a Volcano-sized live stamp (r = 160 m, 34x34 vertices) changes every physics tick, as a rising mound does;
## - holes: a vertex is taken away and given back every `hole_every_s` (Bore), so the navmesh re-bakes and swaps.
## Per phase it prints the script time of each physics tick (from the first to the last _physics_process of the tick, the
## physics server step not included), the frame time and its worst frame, and the wall time of every Terrain call
## (call_ms: it runs on `physics_frame`, just before the tick window, so the cost of a tick is tick_ms + call_ms).
## Measured on an M4 before the fixes: baseline tick 0.42 ms; live tick 1.14 (p95 2.80) + call 0.74; holes worst frame 70 ms.
## Run: Godot --path game res://debug/perf/terrain_deform_bench.tscn (window: the look layers only live with one).
## Target after the 063D fixes: live adds <= 1 ms per tick and the worst frame of every phase stays under 20 ms.

const TAIL_PRIORITY := 100000

@export var world_scene: PackedScene
@export var quality: LookQuality
@export_range(1.0, 30.0, 0.5, "suffix:s") var warmup_s := 8.0
@export_range(1.0, 30.0, 0.5, "suffix:s") var phase_s := 6.0
@export_range(0.1, 5.0, 0.1, "suffix:s") var hole_every_s := 1.0
@export_range(10.0, 300.0, 1.0, "suffix:m") var stamp_radius_m := 160.0
@export_range(10.0, 300.0, 1.0, "suffix:m") var stamp_ahead_m := 120.0

var _tick_start := 0
var _ticks := PackedFloat32Array()
var _frames := PackedFloat32Array()
var _calls := PackedFloat32Array()
var _tail: Node


func _ready() -> void:
	process_physics_priority = -TAIL_PRIORITY
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	add_child(world_scene.instantiate())
	_tail = Node.new()
	_tail.name = "TickTail"
	_tail.process_physics_priority = TAIL_PRIORITY
	_tail.set_script(_tail_script())
	_tail.set_meta("bench", self)
	add_child(_tail)
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	_tick_start = Time.get_ticks_usec()


func _process(delta: float) -> void:
	_frames.append(delta * 1000.0)


## Called by the tail node, the last _physics_process of the tick.
func tick_ended() -> void:
	_ticks.append(float(Time.get_ticks_usec() - _tick_start) / 1000.0)


func _tail_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends Node\nfunc _physics_process(_d: float) -> void:\n\tget_meta(\"bench\").tick_ended()\n"
	script.reload()
	return script


func _run() -> void:
	await _wait(2.0)
	var rig := get_tree().get_first_node_in_group(FloraField.GROUP).get("rig") as LookRig if get_tree().get_first_node_in_group(FloraField.GROUP) else null
	if rig != null and quality != null:
		rig.apply_quality(quality)
	await _wait(warmup_s)
	var terrain := Terrain.of(self)
	var wizard := get_tree().get_first_node_in_group(&"wizard") as WizardBody
	if terrain == null or wizard == null:
		printerr("terrain_deform_bench: no terrain or wizard")
		get_tree().quit(1)
		return
	_begin()
	await _wait(phase_s)
	_end("baseline")
	var at := wizard.global_position + wizard.facing_flat() * stamp_ahead_m
	var center := Vector2(at.x, at.z)
	var profile := _flat_profile()
	_begin()
	var until := Time.get_ticks_msec() + int(phase_s * 1000.0)
	var step := 0
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		step += 1
		var started := Time.get_ticks_usec()
		terrain.stamp(&"bench", profile, center, stamp_radius_m, 10.0 * sin(step * 0.05), 0.0)
		_calls.append(float(Time.get_ticks_usec() - started) / 1000.0)
	_end("live r=%.0f m every tick" % stamp_radius_m)
	terrain.unstamp(&"bench")
	await _wait(2.0)
	_begin()
	until = Time.get_ticks_msec() + int(phase_s * 1000.0)
	var removed := false
	while Time.get_ticks_msec() < until:
		removed = not removed
		var started := Time.get_ticks_usec()
		if removed:
			terrain.cut_hole(center)
		else:
			terrain.fill_hole(center)
		_calls.append(float(Time.get_ticks_usec() - started) / 1000.0)
		await _wait(hole_every_s)
	if removed:
		terrain.fill_hole(center)
	await _wait(4.0)
	_end("holes every %.1f s" % hole_every_s)
	get_tree().quit()


## A disc that lifts every vertex within the reach by the whole peak, for as long as the bench plays it.
func _flat_profile() -> StampProfile:
	var profile := StampProfile.new()
	profile.radial = Curve.new()
	profile.radial.add_point(Vector2(0.0, 1.0))
	profile.radial.add_point(Vector2(1.0, 1.0))
	profile.timeline = Curve.new()
	profile.timeline.max_domain = 1000.0
	profile.timeline.add_point(Vector2(0.0, 1.0))
	profile.timeline.add_point(Vector2(1000.0, 1.0))
	return profile


func _begin() -> void:
	_ticks.clear()
	_frames.clear()
	_calls.clear()


func _end(label: String) -> void:
	print("terrain_deform_bench %-24s tick_ms %s | frame_ms %s | call_ms %s" % [label, _stats(_ticks), _stats(_frames), _stats(_calls)])


func _stats(values: PackedFloat32Array) -> String:
	if values.is_empty():
		return "-"
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for v in values:
		total += v
	return "avg %.2f p95 %.2f max %.2f" % [total / values.size(), sorted[int(sorted.size() * 0.95)], sorted[sorted.size() - 1]]


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
