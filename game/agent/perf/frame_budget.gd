extends Node

## RFC-027 027a (F85): where the frame goes, by subsystem. Harness of res://agent/ (never in a product
## scene); it replaces agent/perf/perf_probe and keeps its per-body sweeps.
##
## It runs the scene it sits in (agent/fixtures/perf027_*.tscn) and, per case, measures a window of
## `window_frames` frames after `warmup_frames`:
##   wall frame (mean, p95), physics ticks per frame (Engine.get_physics_frames), the script tick
##   (from SceneTree.physics_frame to this node's _physics_process, which runs last:
##   process_physics_priority is the highest of the tree in the fixtures), the full tick (from one
##   physics_frame to the next inside the same frame, and the TIME_PHYSICS_PROCESS monitor, the
##   longest step of a second), the script process (from SceneTree.process_frame to this node's _process,
##   last too: highest process_priority), the CPU side of the render (RenderingServer frame_pre_draw to
##   frame_post_draw), the counters the game already has (TargetPicker.total_us, AiSide.tick_ms, Orders.last_apply_us), draws,
##   primitives, objects, VRAM and RSS.
## Then the render by subtraction (Metal reports no GPU time): the base with the tree paused, and the
## frame running live without grass, without health bars, without sun shadows and without the bodies'
## meshes (see _subtraction). On this Mac the window presents at most at the display's refresh (120 Hz,
## 8.33 ms) even with --disable-vsync: walls under that are quantized. Last, the per-body sweeps of perf_probe (resolve, obstacles, clip, ground,
## move_and_slide) over every creature, with their positions and velocities put back.
##
## Cases: "still" (as the scene starts), "moving" (waits for the order_units action: the flow presses
## check_tick and order_units, see agent/flows/perf027_many.json) and "match" (the `runner` of
## debug/ai/ai_match.tscn: windows at 25/50/75 % of the match, the subtraction after the middle one, and the
## frame of the whole match at the normal cap). `phase` tells the flow where it is.
##
## Output: one line `PERF_TABLE <json>` per case and agent/out/perf027/<label>_r<run>.md (--perf-run=N).
## It quits the process when RSS + VRAM pass `rss_cap_mb`.

@export var warmup_frames := 60
@export var window_frames := 120
@export var cases: PackedStringArray = ["still", "moving"]
## Name of the scene in the outputs (many0, many50, many150, match).
@export var label := "many150"
@export var out_dir := "res://agent/out/perf027"
@export var rss_cap_mb := 2500.0
## On: no fps cap for the whole run (the selection_many bench). Off: a 60 fps cap, lifted
## only during the windows and the subtraction (the 3 min match).
@export var bench_uncapped := true
@export var subtract := true
## Frames after each change (pause, a layer off) before measuring.
@export var settle_frames := 12
## Frames after the order before the "moving" window (the first order builds the run clip meshes).
@export var order_settle_frames := 20
## Seconds the "moving" case waits for order_units before it measures anyway.
@export var order_wait_s := 120.0
@export var sweep_reps := 5
## Frames of each live layer-off window (and of the live base it is compared with).
@export var subtract_frames := 60
## The ai_match runner (debug/ai/ai_match.tscn) for the "match" case.
@export var runner: Node
@export var match_marks: PackedFloat32Array = [0.25, 0.5, 0.75]
## Which match window (index in match_marks) gets the subtraction.
@export var match_subtract_at := 1

## Read by the flow: warming, still, await_order, moving, match, done, aborted.
var phase := "warming"
var run_index := 1
var rows: Dictionary = {}

var _recorders: Array[Recorder] = []
var _last_us := 0
var _last_phys := 0
var _tick_began := 0
var _prev_tick_began := 0
var _prev_tick_frame := -1
var _frame_serial := 0
var _ordered := false
var _rss_next_ms := 0
var _ai_sides: Array[Node] = []
var _process_began := 0
var _draw_began := 0
var _last_draw_ms := 0.0


## One measuring window: per-frame and per-tick samples.
class Recorder:
	var wall := PackedFloat32Array()
	var ticks := PackedInt32Array()
	var phys := PackedFloat32Array()
	var proc := PackedFloat32Array()
	var draws := PackedFloat32Array()
	var prims := PackedFloat32Array()
	var objs := PackedFloat32Array()
	var script_tick := PackedFloat32Array()
	var script_proc := PackedFloat32Array()
	var render_cpu := PackedFloat32Array()
	var full_tick := PackedFloat32Array()
	var tick_count := 0
	var limit := 0

	func full() -> bool:
		return limit > 0 and wall.size() >= limit


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-run="):
			run_index = int(arg.get_slice("=", 1))
	_uncap(bench_uncapped)
	get_tree().physics_frame.connect(_on_tick_began)
	get_tree().process_frame.connect(func() -> void: _process_began = Time.get_ticks_usec())
	RenderingServer.frame_pre_draw.connect(func() -> void: _draw_began = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func() -> void: _last_draw_ms = (Time.get_ticks_usec() - _draw_began) / 1000.0)
	_run.call_deferred()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("order_units"):
		_ordered = true


## Only the fps cap: Metal ignores a vsync change at run time, so agent/runs/run_perf027.sh starts Godot with
## --disable-vsync (window.vsync in the output says what the run had).
func _uncap(on: bool) -> void:
	Engine.max_fps = 0 if on else 60


func _mon(m: Performance.Monitor) -> float:
	return float(Performance.get_monitor(m))


func _on_tick_began() -> void:
	var now := Time.get_ticks_usec()
	if _prev_tick_frame == _frame_serial and not get_tree().paused:
		for r in _recorders:
			r.full_tick.append((now - _prev_tick_began) / 1000.0)
	_prev_tick_began = now
	_prev_tick_frame = _frame_serial
	_tick_began = now


## Runs after every other _physics_process (highest process_physics_priority in the fixture).
func _physics_process(_delta: float) -> void:
	if get_tree().paused or _recorders.is_empty():
		return
	var spent := (Time.get_ticks_usec() - _tick_began) / 1000.0
	for r in _recorders:
		r.script_tick.append(spent)
		r.tick_count += 1


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var phys_frames := Engine.get_physics_frames()
	if _last_us > 0:
		var wall := (now - _last_us) / 1000.0
		var ticks := phys_frames - _last_phys
		for r in _recorders:
			if r.full():
				continue
			r.wall.append(wall)
			r.ticks.append(ticks)
			r.phys.append(_mon(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			r.proc.append(_mon(Performance.TIME_PROCESS) * 1000.0)
			r.script_proc.append((now - _process_began) / 1000.0 if _process_began > 0 else 0.0)
			r.render_cpu.append(_last_draw_ms)
			r.draws.append(_mon(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			r.prims.append(_mon(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			r.objs.append(_mon(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	_last_us = now
	_last_phys = phys_frames
	_frame_serial += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _run() -> void:
	await _frames(warmup_frames)
	for case in cases:
		if case == "match":
			await _match()
			continue
		if case == "moving":
			phase = "await_order"
			var deadline := Time.get_ticks_msec() + int(order_wait_s * 1000.0)
			while not _ordered and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
			await _frames(order_settle_frames)
		phase = case
		if not _memory_ok():
			return
		var row := await _case_row(case)
		_emit(case, row)
	_finish()


## One case: the window, the moving bodies at its ends, the subtraction and the sweeps.
func _case_row(case: String) -> Dictionary:
	var moving_before := _moving_count()
	_ai_sides = _find_ai_sides()
	var counters := _counters_now()
	var rec := await _window(window_frames)
	var row := _stats(rec)
	row["subsystems_ms_per_tick"] = _counters_delta(counters, rec)
	row["moving_bodies"] = [moving_before, _moving_count()]
	row["bodies"] = get_tree().get_node_count_in_group("unit")
	if subtract:
		row["render"] = await _subtraction()
	row["sweeps_ms_per_tick"] = _sweeps()
	row["memory"] = _memory()
	return row


func _window(frames: int) -> Recorder:
	var rec := Recorder.new()
	rec.limit = frames
	_recorders.append(rec)
	while not rec.full():
		await get_tree().process_frame
	_recorders.erase(rec)
	return rec


## The match: a capped record of the whole run plus uncapped windows at match_marks.
func _match() -> void:
	phase = "await_match"
	if runner == null:
		push_error("FrameBudget: the match case needs the runner")
		return
	while not bool(runner.get("_running")) and not bool(runner.get("_finished")):
		await get_tree().process_frame
	phase = "match"
	var whole := Recorder.new()
	var whole_tick_from := _match_tick()
	_recorders.append(whole)
	var max_ticks := int(runner.get("_max_ticks"))
	var windows: Array = []
	var row_render: Dictionary = {}
	_ai_sides = _find_ai_sides()
	var counters := _counters_now()
	for k in match_marks.size():
		var at := int(max_ticks * match_marks[k])
		while _match_tick() < at and not bool(runner.get("_finished")):
			await get_tree().process_frame
			if not _memory_ok():
				return
		if bool(runner.get("_finished")):
			break
		_recorders.erase(whole)
		if not bench_uncapped:
			_uncap(true)
		await _frames(settle_frames)
		_ai_sides = _find_ai_sides()
		var window_counters := _counters_now()
		var rec := await _window(window_frames)
		var stats := _stats(rec)
		stats["subsystems_ms_per_tick"] = _counters_delta(window_counters, rec)
		stats["match_tick"] = _match_tick()
		stats["bodies"] = get_tree().get_node_count_in_group("unit")
		stats["moving_bodies"] = _moving_count()
		var measured := float(stats["ticks_x_tick_ms"]) + float(stats["process_ms"]) + float(stats["render_cpu_ms"])
		stats["explained_measured_pct"] = _r(100.0 * measured / maxf(0.001, float(stats["wall_ms"]["mean"])))
		if subtract and k == match_subtract_at:
			row_render = await _subtraction()
			stats["sweeps_ms_per_tick"] = _sweeps()
			var explained := float(stats["ticks_x_tick_ms"]) + float(stats["process_ms"]) + float(row_render["base_ms"])
			stats["explained_ms"] = _r(explained)
			stats["explained_pct"] = _r(100.0 * explained / maxf(0.001, float(stats["wall_ms"]["mean"])))
		windows.append(stats)
		if not bench_uncapped:
			_uncap(false)
		await _frames(settle_frames)
		_recorders.append(whole)
	while not bool(runner.get("_finished")):
		await get_tree().process_frame
		if not _memory_ok():
			return
	_recorders.erase(whole)
	## Per-tick counters of the whole match are over every tick, the windows' ones included.
	var whole_frames_ticks := whole.tick_count
	whole.tick_count = _match_tick() - whole_tick_from
	var row := {"windows": windows, "render": row_render, "memory": _memory()}
	var whole_stats := _stats(whole)
	whole_stats["capped"] = not bench_uncapped
	whole_stats["ticks_recorded"] = whole_frames_ticks
	row["whole_match"] = whole_stats
	row["whole_subsystems_ms_per_tick"] = _counters_delta(counters, whole)
	var report: Variant = runner.get("_report")
	if report is Dictionary:
		row["digest"] = (report as Dictionary).get("digest", "")
		row["end_tick"] = (report as Dictionary).get("end_tick", 0)
		row["runner_tick_ms"] = (report as Dictionary).get("tick_ms", {})
	_emit("match", row)


func _match_tick() -> int:
	var audit: Variant = runner.get("audit")
	return int((audit as Object).get("tick")) if audit is Object else 0


func _stats(rec: Recorder) -> Dictionary:
	var with_ticks := PackedFloat32Array()
	var histogram := {}
	for i in rec.ticks.size():
		histogram[rec.ticks[i]] = int(histogram.get(rec.ticks[i], 0)) + 1
		if rec.ticks[i] > 0:
			with_ticks.append(rec.phys[i])
	var ticks_mean := _mean_i(rec.ticks)
	var tick_full := _mean(rec.full_tick) if rec.full_tick.size() >= 10 else _mean(rec.script_tick)
	var row := {
		"frames": rec.wall.size(),
		"wall_ms": {"mean": _r(_mean(rec.wall)), "p95": _r(_pct(rec.wall, 0.95)), "max": _r(_pct(rec.wall, 1.0))},
		"ticks_per_frame": {"mean": _r(ticks_mean), "max": _max_i(rec.ticks), "histogram": histogram,
			"cap": Engine.max_physics_steps_per_frame},
		"script_tick_ms": {"mean": _r(_mean(rec.script_tick)), "p99": _r(_pct(rec.script_tick, 0.99)), "n": rec.script_tick.size()},
		"full_tick_ms": {"mean": _r(tick_full), "between_ticks_n": rec.full_tick.size(),
			"monitor_mean": _r(_mean(with_ticks)), "monitor_p95": _r(_pct(with_ticks, 0.95))},
		"process_ms": _r(_mean(rec.script_proc)),
		"render_cpu_ms": _r(_mean(rec.render_cpu)),
		"monitor_process_max_per_s_ms": _r(_mean(rec.proc)),
		"draws": _r(_mean(rec.draws)),
		"prims": roundi(_mean(rec.prims)),
		"objects": roundi(_mean(rec.objs)),
	}
	## Wall time the ticks and the process take per frame; the render base is added by _emit.
	row["ticks_x_tick_ms"] = _r(ticks_mean * tick_full)
	## What is left of the wall frame after ticks, script process and the CPU side of the render (sync, swap, GPU wait).
	row["rest_ms"] = _r(_mean(rec.wall) - ticks_mean * tick_full - _mean(rec.script_proc) - _mean(rec.render_cpu))
	return row


## Totals that grow over time, read before a window (TargetPicker per node, AiSide samples; Vision is timed by debug/units/vision_perf.tscn).
func _counters_now() -> Dictionary:
	var pickers := {}
	for node in get_tree().get_nodes_in_group("unit") + get_tree().get_nodes_in_group("wizard"):
		var picker := node.get_node_or_null("TargetPicker")
		if picker:
			pickers[picker.get_instance_id()] = int(picker.get("total_us"))
	var ai := {}
	for side in _ai_sides:
		ai[side.get_instance_id()] = (side.get("tick_ms") as PackedFloat32Array).size()
	return {"pickers": pickers, "ai": ai}


func _counters_delta(before: Dictionary, rec: Recorder) -> Dictionary:
	var ticks := maxi(1, rec.tick_count)
	var picker_us := 0
	for node in get_tree().get_nodes_in_group("unit") + get_tree().get_nodes_in_group("wizard"):
		var picker := node.get_node_or_null("TargetPicker")
		if picker:
			picker_us += int(picker.get("total_us")) - int(before["pickers"].get(picker.get_instance_id(), 0))
	var ai_ms := 0.0
	for side in _ai_sides:
		if not is_instance_valid(side):
			continue
		var samples := side.get("tick_ms") as PackedFloat32Array
		for i in range(int(before["ai"].get(side.get_instance_id(), 0)), samples.size()):
			ai_ms += samples[i]
	var world := get_tree().root.find_child("HighNoon", true, false)
	var orders := world.get_node_or_null("%Orders") if world else null
	return {
		"ticks": rec.tick_count,
		"target_picker": _r(picker_us / 1000.0 / ticks),
		"vision": 0.0,
		"ai_sides": _r(ai_ms / ticks),
		"orders_last_apply_ms": _r(int(orders.get("last_apply_us")) / 1000.0) if orders and orders.get("last_apply_us") != null else 0.0,
	}


func _find_ai_sides() -> Array[Node]:
	return _find_class(get_tree().root, "AiSide")


func _find_class(from: Node, class_label: String) -> Array[Node]:
	var found: Array[Node] = []
	var script := from.get_script() as Script
	if script and script.get_global_name() == class_label:
		found.append(from)
	for child in from.get_children():
		found.append_array(_find_class(child, class_label))
	return found


func _moving_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("unit"):
		if node is CharacterBody3D and Vector2((node as CharacterBody3D).velocity.x, (node as CharacterBody3D).velocity.z).length() > 0.5:
			count += 1
	return count


## Render by subtraction. "paused": the tree paused (only the renderer and this node run), two windows
## (the first one runs slower and is kept as base_first_ms): the render base of RFC-027 §1. The layers are
## taken off LIVE (the scene running): paused, the grass draws a fraction of its primitives and the frame
## sits on the display's refresh, so a paused layer-off says nothing. Each live layer-off window
## (`subtract_frames`) is compared with a live base window of the same length taken right before.
func _subtraction() -> Dictionary:
	var was_capped := not bench_uncapped
	if was_capped:
		_uncap(true)
	get_tree().paused = true
	await _frames(settle_frames * 3)
	var first := _stats(await _window(window_frames))
	var paused := _stats(await _window(window_frames))
	get_tree().paused = false
	await _frames(settle_frames)
	var out := {
		"base_ms": paused["wall_ms"]["mean"], "base_p95_ms": paused["wall_ms"]["p95"], "base_first_ms": first["wall_ms"]["mean"],
		"base_render_cpu_ms": paused["render_cpu_ms"], "base_process_ms": paused["process_ms"],
		"draws": paused["draws"], "prims": paused["prims"], "objects": paused["objects"],
	}
	## Each layer-off window right after a live base window of the same length (the scene changes over time).
	for variant in ["no_grass", "no_bars", "no_sun_shadows", "no_body_meshes"]:
		var live := _stats(await _window(subtract_frames))
		var touched := _apply(variant)
		await _frames(settle_frames)
		var stats := _stats(await _window(subtract_frames))
		_restore(touched)
		await _frames(settle_frames)
		out[variant] = {
			"base_wall_ms": live["wall_ms"]["mean"], "wall_ms": stats["wall_ms"]["mean"],
			"saves_ms": _r(float(live["wall_ms"]["mean"]) - float(stats["wall_ms"]["mean"])),
			"render_cpu_ms": stats["render_cpu_ms"], "saves_render_cpu_ms": _r(float(live["render_cpu_ms"]) - float(stats["render_cpu_ms"])),
			"draws": stats["draws"], "saves_draws": _r(float(live["draws"]) - float(stats["draws"])),
			"prims": stats["prims"], "saves_prims": float(live["prims"]) - float(stats["prims"]),
			"ticks_per_frame": [live["ticks_per_frame"]["mean"], stats["ticks_per_frame"]["mean"]], "changed": touched.size(),
		}
	if was_capped:
		_uncap(false)
	return out


## Turns a layer off; returns what it touched as [object, property, old value] for _restore.
func _apply(variant: String) -> Array:
	var touched: Array = []
	match variant:
		"no_grass":
			for node in _find_class(get_tree().root, "GrassField"):
				touched.append([node, "visible", (node as Node3D).visible])
				(node as Node3D).visible = false
		"no_bars":
			for node in get_tree().get_nodes_in_group("unit") + get_tree().get_nodes_in_group("wizard"):
				var bar := node.get_node_or_null("HealthBar") as Node3D
				if bar and bar.visible:
					touched.append([bar, "visible", true])
					bar.visible = false
		"no_sun_shadows":
			for node in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
				var light := node as DirectionalLight3D
				if light.shadow_enabled:
					touched.append([light, "shadow_enabled", true])
					light.shadow_enabled = false
		"no_body_meshes":
			for node in get_tree().get_nodes_in_group("unit") + get_tree().get_nodes_in_group("wizard"):
				var tilt := node.get_node_or_null("Tilt") as Node3D
				if tilt and tilt.visible:
					touched.append([tilt, "visible", true])
					tilt.visible = false
	return touched


func _restore(touched: Array) -> void:
	for entry in touched:
		if is_instance_valid(entry[0]):
			(entry[0] as Object).set(entry[1], entry[2])


## perf_probe's sweeps: one pass over every creature = what one tick spends there (mean of sweep_reps).
## Positions and velocities are put back after each pass.
func _sweeps() -> Dictionary:
	var bodies: Array[CharacterBody3D] = []
	for node in get_tree().get_nodes_in_group("unit"):
		if node is CharacterBody3D and node.is_inside_tree():
			bodies.append(node)
	if bodies.is_empty():
		return {"bodies": 0}
	var out := {"bodies": bodies.size()}
	for part in ["clip", "edge_clamp", "move_and_slide"]:
		out[part] = _sweep(bodies, part)
	return out


func _sweep(bodies: Array[CharacterBody3D], part: String) -> float:
	var delta := 1.0 / float(Engine.physics_ticks_per_second)
	var saved: Array = []
	for b in bodies:
		saved.append([b.global_transform, b.velocity])
	var started := Time.get_ticks_usec()
	for k in sweep_reps:
		for b in bodies:
			match part:
				"clip":
					b.call("_update_clip_state")
					var clip := b.get_node_or_null("ClipPose")
					if clip:
						clip.call("advance", delta)
				"edge_clamp":
					EdgeClamp.clamp_velocity(b, Vector3(1, 0, 0), delta)
					FallCheck.has_fallen(b)
				"move_and_slide":
					b.move_and_slide()
	var spent := (Time.get_ticks_usec() - started) / 1000.0 / sweep_reps
	for i in bodies.size():
		bodies[i].global_transform = saved[i][0]
		bodies[i].velocity = saved[i][1]
	return _r(spent)


func _memory() -> Dictionary:
	return {"rss_mb": _r(_rss_mb()), "vram_mb": _r(_mon(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
		"static_mb": _r(_mon(Performance.MEMORY_STATIC) / 1048576.0)}


func _rss_mb() -> float:
	var out: Array = []
	OS.execute("ps", ["-o", "rss=", "-p", str(OS.get_process_id())], out)
	return float(str(out[0]).strip_edges()) / 1024.0 if not out.is_empty() else 0.0


## False (and quits) when RSS + VRAM pass the cap. Checked at most every 2 s outside the windows.
func _memory_ok() -> bool:
	if Time.get_ticks_msec() < _rss_next_ms:
		return true
	_rss_next_ms = Time.get_ticks_msec() + 2000
	var used := _rss_mb() + _mon(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	if used <= rss_cap_mb:
		return true
	phase = "aborted"
	print("PERF_ABORT rss+vram %.0f MB > %.0f" % [used, rss_cap_mb])
	_write("PERF_ABORT rss+vram %.0f MB\n" % used)
	get_tree().quit(3)
	return false


func _emit(case: String, row: Dictionary) -> void:
	row["case"] = case
	row["label"] = label
	row["run"] = run_index
	row["window"] = {"viewport": str(get_viewport().get_visible_rect().size), "window": str(DisplayServer.window_get_size()),
		"vsync": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps}
	var render: Dictionary = row.get("render", {})
	if not render.is_empty() and row.has("wall_ms"):
		var explained := float(row["ticks_x_tick_ms"]) + float(row["process_ms"]) + float(render["base_ms"])
		row["explained_ms"] = _r(explained)
		row["explained_pct"] = _r(100.0 * explained / maxf(0.001, float(row["wall_ms"]["mean"])))
	if row.has("wall_ms"):
		## With the measured CPU side of the render (it includes waiting for the GPU and the drawable).
		var measured := float(row["ticks_x_tick_ms"]) + float(row["process_ms"]) + float(row["render_cpu_ms"])
		row["explained_measured_pct"] = _r(100.0 * measured / maxf(0.001, float(row["wall_ms"]["mean"])))
	rows[case] = row
	print("PERF_TABLE " + JSON.stringify(row))


func _finish() -> void:
	var text := "# FrameBudget %s · corrida %d\n\n" % [label, run_index]
	for case in rows:
		text += "## %s\n\n```json\n%s\n```\n\nPERF_TABLE %s\n\n" % [case, JSON.stringify(rows[case], "  "), JSON.stringify(rows[case])]
	_write(text)
	phase = "done"
	if cases.has("match"):
		get_tree().quit()


func _write(text: String) -> void:
	var dir := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(dir.path_join("%s_r%d.md" % [label, run_index]), FileAccess.WRITE)
	if file:
		file.store_string(text)


func _mean(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += v
	return total / values.size()


func _mean_i(values: PackedInt32Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0
	for v in values:
		total += v
	return float(total) / values.size()


func _max_i(values: PackedInt32Array) -> int:
	var top := 0
	for v in values:
		top = maxi(top, v)
	return top


func _pct(values: PackedFloat32Array, q: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(ceil(q * sorted.size())) - 1, 0, sorted.size() - 1)]


func _r(value: float) -> float:
	return snappedf(value, 0.01)
