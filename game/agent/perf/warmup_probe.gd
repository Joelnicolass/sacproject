extends Node

## RFC-069 W5: measures the loading screen's warm-up in a real «Contra la IA» match (a window: the GPU has to draw). It starts
## the match from the flow, waits for `SacrificeFlow.world_loaded` and then plays `match_s` seconds, and prints one line
## `WARMUP_PROBE <json>` and a PASS/FAIL per criterion of rfcs/plans/069-loading-warmup-plan.md §4:
##   1. pipeline compilations (DRAW + SPECIALIZATION) after world_loaded = 0, and > 0 while loading (the warm-up compiled);
##   2. no frame over `spike_ms` after world_loaded, and the longest frame <= `max_over_median` x the median;
##   3. the load (play_vs_ai -> world_loaded) within `--load-limit-s=` (agent/runs/run_warmup.sh: 8 s cold, 3 s cached);
##   4. VRAM at the end <= VRAM at world_loaded x (1 + `vram_growth`).
## `--explain=1` also says why, so a failure points at its owner:
##   WARMUP_LOAD    a loading frame where the counters moved or that took over 50 ms (and whether the tree was paused);
##   WARMUP_STALL   a wait over 3 ms between two loading events (a node entered, a node was ready, a draw): what held the frame;
##   WARMUP_EXPLAIN a frame after world_loaded where the counters moved (draw / specialization so far) or that took over
##                  `explain_ms`: the scenes added in it and the kinds of 3D nodes newly visible (what it probably compiled for);
##   WARMUP_FRAME   the waits over 0.4 ms inside such a frame.
## Harness of res://agent/ (never in a product scene). The map and the mode come from `--map=` / `--mode=` (ActiveMatch).
## `-- --map=test_flat4 --mode=2v2 [--load-limit-s=8] [--match-s=60] [--explain=1]`. Prints WARMUP PASS / WARMUP FAIL and quits (0 / 1).

## Seconds of play measured after world_loaded.
@export var match_s := 60.0
## A frame longer than this after world_loaded is a hitch.
@export var spike_ms := 50.0
## 2.5 = at most one missed vsync at 60 Hz (~42 ms): what is left is the CPU of a summon (unit.tscn), not shaders (069 fix).
@export var max_over_median := 2.5
## Allowed VRAM growth after world_loaded (0.15 = 15 %).
@export var vram_growth := 0.15
## Frames skipped right after world_loaded (the frame that reported it, and the one the gate unpauses on).
@export var skip_frames := 2
## Seconds the load may take before the probe gives up.
@export var give_up_s := 90.0
## `--explain`: a frame after world_loaded longer than this is explained (two 60 Hz frames).
@export var explain_ms := 33.4

const RUNNER_META := "warmup_probe_runner"

var _frames_ms := PackedFloat32Array()
var _last_us := 0
var _sampling := false
var _skip := 0
var _fails := 0

var _explain := false
var _t_loaded_ms := 0
var _last_counts := 0
## [usec, what]: a node entered the tree, a node was ready, a draw began or ended, a frame went by.
var _events: Array = []
## Scene files added since the last explained frame.
var _added_scenes: Array[String] = []
var _seen_visible: Dictionary[int, bool] = {}
## Strips the numbers of pooled and spawned names (Manahoar3, abom_drip_24, @Label3D@75): one line per kind.
var _kind_regex := RegEx.create_from_string("_?@?\\d+@?")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	## Loading the world frees the main scene: the probe runs as a twin under the root.
	if not has_meta(RUNNER_META):
		var twin := (get_script() as GDScript).new() as Node
		twin.set_meta(RUNNER_META, true)
		twin.name = "WarmupProbeRunner"
		get_tree().root.add_child.call_deferred(twin)
		return
	_run.call_deferred()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _sampling and _last_us > 0:
		if _skip > 0:
			_skip -= 1
		else:
			var ms := (now - _last_us) / 1000.0
			_frames_ms.append(ms)
			if _explain:
				_explain_frame(ms)
	_last_us = now


func _run() -> void:
	var limit_s := float(MpBoot.user_value("load-limit-s", "8"))
	match_s = float(MpBoot.user_value("match-s", str(match_s)))
	_explain = MpBoot.user_value("explain", "") != ""
	var at_start := _compilations()
	var loaded := [false]
	SacrificeFlow.world_loaded.connect(func() -> void: loaded[0] = true, CONNECT_ONE_SHOT)
	var t0 := Time.get_ticks_msec()
	var load_counts := _sum(at_start)
	var load_frame_us := Time.get_ticks_usec()
	if _explain:
		_listen(true)
	SacrificeFlow.play_vs_ai(null, null)
	while not loaded[0] and Time.get_ticks_msec() - t0 < int(give_up_s * 1000.0):
		await get_tree().process_frame
		if _explain:
			var counts := _sum(_compilations())
			var now_us := Time.get_ticks_usec()
			_events.append([now_us, "frame"])
			if counts != load_counts or now_us - load_frame_us > 50000:
				print("WARMUP_LOAD t=%.2f frame_ms=%.1f paused=%s compilations+%d" % [(Time.get_ticks_msec() - t0) / 1000.0,
						(now_us - load_frame_us) / 1000.0, get_tree().paused, counts - load_counts])
				load_counts = counts
			load_frame_us = now_us
	if not loaded[0]:
		print("WARMUP FAIL: world_loaded never came in %.0f s" % give_up_s)
		get_tree().quit(1)
		return
	var load_s := (Time.get_ticks_msec() - t0) / 1000.0
	var at_loaded := _compilations()
	if _explain:
		_print_waits("WARMUP_STALL", 3000, true)
		_t_loaded_ms = Time.get_ticks_msec()
		_last_counts = _sum(at_loaded)
		_newly_visible()
		_added_scenes.clear()
	var vram_loaded := _vram_mb()
	_skip = skip_frames
	_sampling = true
	await get_tree().create_timer(match_s, true, false, true).timeout
	_sampling = false
	if _explain:
		_listen(false)
	var at_end := _compilations()
	var vram_end := _vram_mb()
	var sorted := _frames_ms.duplicate()
	sorted.sort()
	var median := sorted[int(sorted.size() / 2.0)] if not sorted.is_empty() else 0.0
	var longest := sorted[sorted.size() - 1] if not sorted.is_empty() else 0.0
	var spikes := 0
	for ms in _frames_ms:
		if ms > spike_ms:
			spikes += 1
	var during_load := _sum(at_loaded) - _sum(at_start)
	var after_load := _sum(at_end) - _sum(at_loaded)
	var row := {
		"map": MpBoot.user_value("map", ""), "mode": MpBoot.user_value("mode", ""), "load_s": snappedf(load_s, 0.01),
		"load_limit_s": limit_s, "compilations_start": at_start, "compilations_loaded": at_loaded, "compilations_end": at_end,
		"frames": _frames_ms.size(), "median_ms": snappedf(median, 0.01), "max_ms": snappedf(longest, 0.01), "spikes": spikes,
		"vram_loaded_mb": snappedf(vram_loaded, 0.1), "vram_end_mb": snappedf(vram_end, 0.1), "match_s": match_s,
	}
	print("WARMUP_PROBE " + JSON.stringify(row))
	_check(during_load > 0 and after_load == 0,
		"1 pipelines DRAW+SPECIALIZATION: %d while loading (> 0), %d after world_loaded (= 0)" % [during_load, after_load])
	_check(spikes == 0 and longest <= max_over_median * maxf(median, 0.001),
		"2 frames: %d over %.0f ms, longest %.1f ms <= %.1f x median %.1f ms" % [spikes, spike_ms, longest, max_over_median, median])
	_check(load_s <= limit_s, "3 load %.2f s <= %.1f s" % [load_s, limit_s])
	_check(vram_end <= vram_loaded * (1.0 + vram_growth),
		"4 VRAM %.1f MB at the end <= %.1f MB at world_loaded + %d %%" % [vram_end, vram_loaded, int(vram_growth * 100.0)])
	print("WARMUP PASS" if _fails == 0 else "WARMUP FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _listen(on: bool) -> void:
	var tree := get_tree()
	if on:
		tree.node_added.connect(_on_node_added)
		RenderingServer.frame_pre_draw.connect(_on_pre_draw)
		RenderingServer.frame_post_draw.connect(_on_post_draw)
	else:
		tree.node_added.disconnect(_on_node_added)
		RenderingServer.frame_pre_draw.disconnect(_on_pre_draw)
		RenderingServer.frame_post_draw.disconnect(_on_post_draw)


func _on_pre_draw() -> void:
	_events.append([Time.get_ticks_usec(), "pre_draw"])


func _on_post_draw() -> void:
	_events.append([Time.get_ticks_usec(), "post_draw"])


func _on_node_added(node: Node) -> void:
	_events.append([Time.get_ticks_usec(), "added " + str(node.get_path())])
	node.ready.connect(func() -> void: _events.append([Time.get_ticks_usec(), "ready " + str(node.get_path())]), CONNECT_ONE_SHOT)
	var file := node.scene_file_path.get_file()
	if not file.is_empty() and not file in _added_scenes:
		_added_scenes.append(file)


## One `tag` line per wait between two events longer than `over_us` (with the second since the first event when `timed`); then
## only the last event is kept.
func _print_waits(tag: String, over_us: int, timed: bool) -> void:
	var start_us := int(_events[0][0]) if not _events.is_empty() else 0
	for i in range(1, _events.size()):
		var wait_us := int(_events[i][0]) - int(_events[i - 1][0])
		if wait_us > over_us:
			var at := " t=%.3f" % ((int(_events[i][0]) - start_us) / 1000000.0) if timed else ""
			print("%s%s +%.1f ms [%s] -> [%s]" % [tag, at, wait_us / 1000.0, _events[i - 1][1], _events[i][1]])
	_events = _events.slice(-1)


func _explain_frame(ms: float) -> void:
	_events.append([Time.get_ticks_usec(), "frame"])
	var counts := _sum(_compilations())
	if counts == _last_counts and ms <= explain_ms:
		_added_scenes.clear()
		_events = _events.slice(-1)
		return
	_print_waits("WARMUP_FRAME", 400, false)
	var grew := counts - _last_counts
	_last_counts = counts
	var now := _compilations()
	print("WARMUP_EXPLAIN t=%.2f frame_ms=%.1f compilations+%d (draw %d spec %d) added=%s new_visible=%s" % [
		(Time.get_ticks_msec() - _t_loaded_ms) / 1000.0, ms, grew, now["draw"], now["specialization"],
		JSON.stringify(_added_scenes), JSON.stringify(_newly_visible())])
	_added_scenes.clear()


## The kinds of visible 3D nodes not seen at the last look (the first look, at world_loaded, only remembers them).
func _newly_visible() -> Array[String]:
	var fresh: Array[String] = []
	for node in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var geo := node as GeometryInstance3D
		var id := geo.get_instance_id()
		if not geo.is_visible_in_tree() or _seen_visible.has(id):
			continue
		_seen_visible[id] = true
		var what := "%s %s" % [geo.get_class(), _kind_regex.sub(str(geo.get_path()).trim_prefix("/root/"), "", true)]
		var owner_scene := geo.owner.scene_file_path if geo.owner != null else ""
		if not owner_scene.is_empty():
			what += " <" + owner_scene.get_file() + ">"
		if not what in fresh:
			fresh.append(what)
	return fresh


## The pipeline compilations so far, by kind (the warm-up targets DRAW and SPECIALIZATION; the rest is told).
func _compilations() -> Dictionary:
	return {
		"canvas": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS),
		"mesh": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
		"surface": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
		"draw": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		"specialization": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION),
	}


func _sum(counts: Dictionary) -> int:
	return int(counts["draw"]) + int(counts["specialization"])


func _vram_mb() -> float:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1
