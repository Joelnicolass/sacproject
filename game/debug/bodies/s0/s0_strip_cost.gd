extends SceneTree
## 055s s0 (disposable), question 5: how much does the DedicatedStrip take out of the dedicated? Measures, in this project, what the
## strip would replace by empty resources: the 85 clip libraries (scenes/bodies/models/*_clips.tres) and the audio the creature and
## wizard SoundSets point at. Loads them in a fresh process and prints time, static memory and bytes on disk.
## It is the REMOVABLE part: the estimate of the stripped dedicated is (baseline of `main`) - (these numbers). Give the baseline
## of the exported dedicated in S0_BASE_MS / S0_BASE_MB (environment) to get the subtraction printed.
## Prints `S0 5 ...` and `S0 VERDICT strip_cost ...`. Always ends in quit().

const MODELS := "res://scenes/bodies/models/"
const SOUND_DIRS: PackedStringArray = ["res://data/audio/creatures/", "res://data/audio/wizards/"]


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("S0 VERDICT strip_cost TIMEOUT")
		quit(2))
	quit(_main())


func _mb() -> float:
	return float(OS.get_static_memory_usage()) / 1048576.0


func _file_len(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f != null else 0


func _main() -> int:
	# 1. Clip libraries: one .tres per model, each pointing at one .res per role.
	var libs := PackedStringArray()
	var dir := DirAccess.open(MODELS)
	if dir == null:
		print("S0 VERDICT strip_cost ERROR cannot open %s" % MODELS)
		return 1
	for f in dir.get_files():
		if f.ends_with("_clips.tres"):
			libs.append(MODELS + f)
	var anim_bytes := 0
	var anim_files := 0
	for lib_path in libs:
		anim_bytes += _file_len(lib_path)
		for dep in ResourceLoader.get_dependencies(lib_path):
			var p := dep.get_slice("::", dep.count("::"))
			if p.ends_with(".res"):
				anim_bytes += _file_len(p)
				anim_files += 1
	var m0 := _mb()
	var t0 := Time.get_ticks_usec()
	var anims := 0
	for lib_path in libs:
		var lib := ResourceLoader.load(lib_path) as AnimationLibrary
		if lib != null:
			anims += lib.get_animation_list().size()
	var clips_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var clips_mb := _mb() - m0
	print("S0 5 clips libraries=%d animations=%d res_files=%d disk=%.1f MB load=%.0f ms static_mem=+%.1f MB" % [libs.size(), anims, anim_files, float(anim_bytes) / 1048576.0, clips_ms, clips_mb])
	# 2. Audio: every stream the creature and wizard SoundSets reference (source file size is the disk figure).
	var sets := PackedStringArray()
	for d in SOUND_DIRS:
		var sd := DirAccess.open(d)
		if sd == null:
			continue
		for f in sd.get_files():
			if f.ends_with(".tres"):
				sets.append(d + f)
	var streams := {}
	for sp in sets:
		for dep in ResourceLoader.get_dependencies(sp):
			var p := dep.get_slice("::", dep.count("::"))
			if p.get_extension() in ["ogg", "wav", "mp3"]:
				streams[p] = true
	var audio_bytes := 0
	for p: String in streams.keys():
		audio_bytes += _file_len(p)
	var m1 := _mb()
	var t1 := Time.get_ticks_usec()
	for sp in sets:
		ResourceLoader.load(sp)
	var audio_ms := float(Time.get_ticks_usec() - t1) / 1000.0
	var audio_mb := _mb() - m1
	print("S0 5 audio soundsets=%d streams=%d disk=%.1f MB load=%.0f ms static_mem=+%.1f MB" % [sets.size(), streams.size(), float(audio_bytes) / 1048576.0, audio_ms, audio_mb])
	var rm_ms := clips_ms + audio_ms
	var rm_mb := clips_mb + audio_mb
	print("S0 5 removable total load=%.0f ms static_mem=+%.1f MB (plan estimate: ~770 ms and ~46 MB of clips, ~30 MB of audio)" % [rm_ms, rm_mb])
	var base_ms := OS.get_environment("S0_BASE_MS")
	var base_mb := OS.get_environment("S0_BASE_MB")
	if base_ms != "" and base_mb != "":
		print("S0 5 estimate stripped dedicated = %.0f ms, %.0f MB (baseline %s ms %s MB minus removable; the strip leaves the files empty, so real saving is a bit lower)" % [float(base_ms) - rm_ms, float(base_mb) - rm_mb, base_ms, base_mb])
	else:
		print("S0 5 estimate needs S0_BASE_MS and S0_BASE_MB (time to `dedicado listo puerto` and RSS 5 s later of the exported dedicated on main); not given")
	print("S0 VERDICT strip_cost removable=%.0f ms and %.1f MB in this process (a static upper bound; the exported-pack measure is s4's run_055s_dedicated_cost.sh)" % [rm_ms, rm_mb])
	return 0
