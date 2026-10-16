extends Node

## Agent only (022e4): average GPU / CPU frame time and memory over a short window of the match
## world, printed as `RFC022E4_PERF ...`, then quits. Not a benchmark: a cheap A/B of two biomes.

@export var start_after := 12.0
@export var window_s := 6.0

var _gpu := 0.0
var _cpu := 0.0
var _frames := 0
var _sum_delta := 0.0
var _t := 0.0
var _on := false


func _process(delta: float) -> void:
	_t += delta
	if not _on and _t >= start_after:
		_on = true
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
		_t = 0.0
		return
	if not _on:
		return
	var rid := get_viewport().get_viewport_rid()
	_gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	_cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	_frames += 1
	_sum_delta += delta
	if _t >= window_s:
		print("RFC022E4_PERF frames=%d frame_ms=%.3f gpu_ms=%.3f cpu_ms=%.3f static_mb=%.0f vram_mb=%.0f tex_mb=%.0f prims=%d draws=%d" % [
			_frames, _sum_delta / _frames * 1000.0, _gpu / _frames, _cpu / _frames,
			OS.get_static_memory_usage() / 1048576.0,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		get_tree().quit()
