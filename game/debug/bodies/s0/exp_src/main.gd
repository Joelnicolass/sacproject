extends Node
## 055s s0 (disposable): runs from an exported .pck and reports what the pack really holds. Prints `S0 pack ...`, always quits.

const WAVS: PackedStringArray = ["res://audio/tone0.wav", "res://audio/tone1.wav", "res://audio/tone2.wav", "res://audio/tone3.wav"]


func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func() -> void:
		print("S0 pack TIMEOUT")
		get_tree().quit(2))
	var t0 := Time.get_ticks_usec()
	var m0 := OS.get_static_memory_usage()
	var empty_audio := 0
	var audio_bytes := 0
	var missing := 0
	for w in WAVS:
		var s := load(w) as AudioStreamWAV
		if s == null:
			missing += 1
			print("S0 pack audio %s MISSING (null)" % w)
			continue
		audio_bytes += s.data.size()
		if s.data.size() == 0:
			empty_audio += 1
	var lib := load("res://clips/lib.res") as AnimationLibrary
	var tracks := 0
	var anims := 0
	if lib != null:
		for n in lib.get_animation_list():
			tracks += lib.get_animation(n).get_track_count()
			anims += 1
	else:
		print("S0 pack library MISSING (null)")
	var ref := load("res://ref.tscn") as PackedScene
	var ref_ok := false
	if ref != null:
		var inst := ref.instantiate()
		var pl := inst.get_node_or_null("Audio") as AudioStreamPlayer
		ref_ok = pl != null and pl.stream != null
		print("S0 pack ref.tscn instantiated, Audio stream=%s data=%d" % [pl.stream.get_class() if ref_ok else "<null>", (pl.stream as AudioStreamWAV).data.size() if ref_ok and pl.stream is AudioStreamWAV else -1])
		inst.free()
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	print("S0 pack audio files=%d missing=%d empty=%d data_bytes=%d | library animations=%d tracks=%d | ref.tscn ok=%s | load=%.0f ms static_mem=+%.1f MB" % [WAVS.size(), missing, empty_audio, audio_bytes, anims, tracks, ref_ok, ms, float(OS.get_static_memory_usage() - m0) / 1048576.0])
	get_tree().quit(0)
