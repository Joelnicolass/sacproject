extends Node

## RFC-069 W5: measures the loading screen's warm-up in a real «Contra la IA» match (a window: the GPU has to draw). It starts
## the match from the flow, waits for `SacrificeFlow.world_loaded` and then plays `match_s` seconds, and prints one line
## `WARMUP_PROBE <json>` and a PASS/FAIL per criterion of rfcs/plans/069-loading-warmup-plan.md §4:
##   1. pipeline compilations (DRAW + SPECIALIZATION) after world_loaded = 0, and > 0 while loading (the warm-up compiled);
##   2. no frame over `spike_ms` after world_loaded, and the longest frame <= `max_over_median` x the median;
##   3. the load (play_vs_ai -> world_loaded) within `--load-limit-s=` (agent/runs/run_warmup.sh: 8 s cold, 3 s cached);
##   4. VRAM at the end <= VRAM at world_loaded x (1 + `vram_growth`).
## Harness of res://agent/ (never in a product scene). The map and the mode come from `--map=` / `--mode=` (ActiveMatch).
## `-- --map=test_flat4 --mode=2v2 [--load-limit-s=8] [--match-s=60]`. Prints WARMUP PASS / WARMUP FAIL and quits (0 / 1).

## Seconds of play measured after world_loaded.
@export var match_s := 60.0
## A frame longer than this after world_loaded is a hitch.
@export var spike_ms := 50.0
@export var max_over_median := 2.0
## Allowed VRAM growth after world_loaded (0.15 = 15 %).
@export var vram_growth := 0.15
## Frames skipped right after world_loaded (the frame that reported it, and the one the gate unpauses on).
@export var skip_frames := 2
## Seconds the load may take before the probe gives up.
@export var give_up_s := 90.0

const RUNNER_META := "warmup_probe_runner"

var _frames_ms := PackedFloat32Array()
var _last_us := 0
var _sampling := false
var _skip := 0
var _fails := 0


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
			_frames_ms.append((now - _last_us) / 1000.0)
	_last_us = now


func _run() -> void:
	var limit_s := float(MpBoot.user_value("load-limit-s", "8"))
	match_s = float(MpBoot.user_value("match-s", str(match_s)))
	var at_start := _compilations()
	var loaded := [false]
	SacrificeFlow.world_loaded.connect(func() -> void: loaded[0] = true, CONNECT_ONE_SHOT)
	var t0 := Time.get_ticks_msec()
	SacrificeFlow.play_vs_ai(null, null)
	while not loaded[0] and Time.get_ticks_msec() - t0 < int(give_up_s * 1000.0):
		await get_tree().process_frame
	if not loaded[0]:
		print("WARMUP FAIL: world_loaded never came in %.0f s" % give_up_s)
		get_tree().quit(1)
		return
	var load_s := (Time.get_ticks_msec() - t0) / 1000.0
	var at_loaded := _compilations()
	var vram_loaded := _vram_mb()
	_skip = skip_frames
	_sampling = true
	await get_tree().create_timer(match_s, true, false, true).timeout
	_sampling = false
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
