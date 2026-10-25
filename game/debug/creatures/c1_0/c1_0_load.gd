extends SceneTree

## c1-0 probe, step 2 (disposable): the cost of loading the clip libraries that c1_0_build.gd wrote, in a FRESH process so nothing
## is cached. Loads every library (and, through it, every Animation .res), measures the time and the memory it added, and
## extrapolates to all the models by the frames and by the clips of their scenes. Question 1: budget +1 s and +100 MB.
## Run it plain headless (never with --dedicated: that argument makes the project's autoloads start a server). The project's
## autoloads still load; the measure is the difference around the loads, so their own cost does not count.
## "$GODOT" --headless --path game --script res://debug/creatures/c1_0/c1_0_load.gd
## Prints C1_0 load_ms=... mem_mb=..., C1_0 est_all..., C1_0 VERDICT load=... mem=... (exit 0) or C1_0 FAIL <reason> (exit 1).

const Common := preload("res://debug/creatures/c1_0/c1_0_common.gd")
const BUDGET_MS := 1000.0
const BUDGET_MB := 100.0


func _initialize() -> void:
	Common.arm_watchdog(self)
	_main()


func _main() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Common.MANIFEST))
	if not parsed is Dictionary:
		Common.fail(self, "no manifest: run c1_0_build.gd first")
		return
	var manifest: Dictionary = parsed
	var libs: Array = manifest["libs"]
	var mem_before := Common.static_mb()
	var rss_before := Common.rss_kb()
	var started := Time.get_ticks_usec()
	var held: Array[AnimationLibrary] = []
	var animations := 0
	for path: String in libs:
		var library := ResourceLoader.load(path) as AnimationLibrary
		if library == null:
			Common.fail(self, "cannot load " + path)
			return
		held.append(library)
		animations += library.get_animation_list().size()
	var load_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var mem_mb := Common.static_mb() - mem_before
	var rss_after := Common.rss_kb()
	var rss_mb := float(rss_after - rss_before) / 1024.0 if rss_before >= 0 and rss_after >= 0 else -1.0
	# Second pass ignoring the cache: the parse time alone, with the files already in the OS cache.
	var warm_started := Time.get_ticks_usec()
	for path: String in libs:
		ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var warm_ms := float(Time.get_ticks_usec() - warm_started) / 1000.0
	print("C1_0 load_ms=%.1f mem_mb=%.1f rss_mb=%.1f libs=%d roles=%d warm_ms=%.1f" % [load_ms, mem_mb, rss_mb, libs.size(), animations, warm_ms])
	if mem_mb <= 0.0 and rss_mb < 0.0:
		print("C1_0 note memory unavailable: MEMORY_STATIC is 0 in this build and ps failed")
	var use_rss := mem_mb <= 0.05 and rss_mb >= 0.0
	var measured_mb := rss_mb if use_rss else mem_mb
	var by_frames := float(manifest["all_frames"]) / maxf(float(manifest["built_scene_frames"]), 1.0)
	var by_clips := float(manifest["all_clips"]) / maxf(float(manifest["built_clips"]), 1.0)
	print("C1_0 est_all%d load_ms=%.0f(by_frames) %.0f(by_clips) mem_mb=%.0f(by_frames) %.0f(by_clips) source=%s"
		% [manifest["all_models"], load_ms * by_frames, load_ms * by_clips, measured_mb * by_frames, measured_mb * by_clips,
		"rss" if use_rss else "static"])
	var worst_ms := load_ms * maxf(by_frames, by_clips)
	var worst_mb := measured_mb * maxf(by_frames, by_clips)
	var mem_verdict := "UNKNOWN" if measured_mb <= 0.0 else ("OK" if worst_mb <= BUDGET_MB else "OVER")
	print("C1_0 VERDICT load=%s mem=%s (est %.0f ms / %.0f MB, budget %.0f ms / %.0f MB; this machine, not the server)"
		% ["OK" if worst_ms <= BUDGET_MS else "OVER", mem_verdict, worst_ms, worst_mb, BUDGET_MS, BUDGET_MB])
	quit(0)
