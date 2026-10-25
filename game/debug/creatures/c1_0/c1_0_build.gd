extends SceneTree

## c1-0 probe, step 1 (disposable): builds the AnimationLibrary of a few models from today's data and measures what it weighs.
## For each model: one Animation per clip tag the roles use (the .glb's bone tracks, length = frames / framerate, step = 1 / framerate,
## markers hit / shoot from the dictionaries' ticks, the method track of the model's Events at the path "../ClipEvents"), saved as
## user://c1_0/<model>_clips/<tag>.res, and <model>_clips.tres with role -> Animation. Writes only under user://c1_0.
## Answers question 2 (weight in git) and prepares c1_0_load.gd (cost of loading) and c1_0_tree.gd (method tracks).
## "$GODOT" --headless --path game --script res://debug/creatures/c1_0/c1_0_build.gd [-- --models=auto|all|eorc,jnwr,...]
## Prints C1_0 model=..., C1_0 res_bytes=..., C1_0 VERDICT git=OK|LFS, C1_0 BUILD DONE (exit 0) or C1_0 FAIL <reason> (exit 1).

const Common := preload("res://debug/creatures/c1_0/c1_0_common.gd")
## The limit the user approved: git as long as the ~900 .res weigh at most this.
const GIT_LIMIT_MB := 40.0


func _initialize() -> void:
	Common.arm_watchdog(self)
	_main()


func _main() -> void:
	DirAccess.make_dir_recursive_absolute(Common.OUT_DIR)
	var scan := Common.scan_all()
	var wizards := Common.wizard_models()
	var chosen := Common.pick_models(Common.user_arg("models", "auto"), scan, wizards)
	if chosen.is_empty() or scan["models"] == 0:
		Common.fail(self, "no models: is %s there?" % Common.MODELS_DIR)
		return
	print("C1_0 scan models=%d clips=%d frames=%d" % [scan["models"], scan["clips"], scan["frames"]])
	var ticks := Common.creature_ticks()
	var libs: Array = []
	var bytes := 0
	var deflated := 0
	var clips := 0
	var scene_frames := 0
	for model: String in chosen:
		if not (scan["per"] as Dictionary).has(model):
			Common.fail(self, "%s has no scene in %s" % [model, Common.MODELS_DIR])
			return
		var row := _build_model(model, ticks.get(model, {}))
		if row.has("error"):
			Common.fail(self, "%s: %s" % [model, row["error"]])
			return
		print("C1_0 model=%s roles=%d clips=%d tracks=%d keys=%d frames=%d res_bytes=%d deflate_bytes=%d markers=%d methods=%d hit_vs_event=%d/%d len_diff_max_ms=%.3f"
			% [model, row["roles"], row["clips"], row["tracks"], row["keys"], row["frames"], row["bytes"], row["deflate"], row["markers"],
			row["methods"], row["hit_ok"], row["hit_total"], row["max_len_diff_ms"]])
		libs.append(row["lib"])
		bytes += int(row["bytes"]) + int(row["lib_bytes"])
		deflated += int(row["deflate"])
		clips += int(row["clips"])
		scene_frames += int(scan["per"][model]["frames"])
	_report(scan, bytes, deflated, clips, scene_frames)
	var manifest := {"libs": libs, "built_clips": clips, "built_scene_frames": scene_frames, "all_models": scan["models"],
		"all_clips": scan["clips"], "all_frames": scan["frames"]}
	var file := FileAccess.open(Common.MANIFEST, FileAccess.WRITE)
	if file == null:
		Common.fail(self, "cannot write " + Common.MANIFEST)
		return
	file.store_string(JSON.stringify(manifest))
	file.close()
	print("C1_0 BUILD DONE libs=%d dir=%s" % [libs.size(), ProjectSettings.globalize_path(Common.OUT_DIR)])
	quit(0)


func _report(scan: Dictionary, bytes: int, deflated: int, clips: int, scene_frames: int) -> void:
	var by_frames := float(bytes) * float(scan["frames"]) / maxf(float(scene_frames), 1.0) / 1048576.0
	var by_clips := float(bytes) * float(scan["clips"]) / maxf(float(clips), 1.0) / 1048576.0
	var zip_frames := float(deflated) * float(scan["frames"]) / maxf(float(scene_frames), 1.0) / 1048576.0
	var worst := maxf(by_frames, by_clips)
	print("C1_0 res_bytes=%d deflate_bytes=%d built_clips=%d" % [bytes, deflated, clips])
	print("C1_0 est_all%d res_mb_by_frames=%.1f res_mb_by_clips=%.1f deflate_mb_by_frames=%.1f (11 models without scene add almost nothing)"
		% [scan["models"], by_frames, by_clips, zip_frames])
	print("C1_0 VERDICT git=%s (raw estimate %.1f MB, limit %.0f MB)" % ["OK" if worst <= GIT_LIMIT_MB else "LFS", worst, GIT_LIMIT_MB])


## Builds and saves the library of one model. Returns the row of numbers, or {error} when something is missing.
func _build_model(model: String, model_ticks: Dictionary) -> Dictionary:
	var packed := load(Common.MODELS_DIR + model + ".tscn") as PackedScene
	if packed == null:
		return {"error": "no model scene"}
	var inst := packed.instantiate()
	var glb := Common.glb_player(inst)
	if glb == null:
		inst.free()
		return {"error": "no AnimationPlayer in the .glb (an LFS pointer, or not imported yet?)"}
	var events := inst.get_node_or_null("Events") as AnimationPlayer
	var clip_table: Dictionary = inst.get("clips")
	var roles := Common.roles_of(inst)
	var dir := "%s/%s_clips" % [Common.OUT_DIR, model]
	DirAccess.make_dir_recursive_absolute(dir)
	var row := {"roles": roles.size(), "clips": 0, "tracks": 0, "keys": 0, "frames": 0, "bytes": 0, "deflate": 0, "markers": 0, "methods": 0,
		"hit_ok": 0, "hit_total": 0, "max_len_diff_ms": 0.0}
	var library := AnimationLibrary.new()
	var by_tag: Dictionary = {}
	for role: String in roles:
		var tag: String = roles[role]["tag"]
		if not by_tag.has(tag):
			var loops := false
			for other: String in roles:
				if roles[other]["tag"] == tag and not Common.HOLD_ROLES.has(other):
					loops = true
			var made := _make_clip(dir, tag, clip_table.get(tag, {}), glb, events, model_ticks.get(tag, {}), loops, row)
			if made == null:
				inst.free()
				return {"error": "clip %s missing in the .glb or not saved" % tag}
			by_tag[tag] = made
		library.add_animation(StringName(role), by_tag[tag])
	for tag: String in by_tag:
		var anim: Animation = by_tag[tag]
		var path := "%s/%s.res" % [dir, tag]
		var stats := Common.track_stats(anim)
		row["clips"] += 1
		row["tracks"] += stats.x
		row["keys"] += stats.y
		row["frames"] += roundi(anim.length / anim.step)
		row["bytes"] += Common.file_len(path)
		row["deflate"] += Common.deflate_len(path)
	row["lib"] = "%s/%s_clips.tres" % [Common.OUT_DIR, model]
	if ResourceSaver.save(library, row["lib"]) != OK:
		inst.free()
		return {"error": "cannot save the library"}
	row["lib_bytes"] = Common.file_len(row["lib"])
	inst.free()
	return row


## One Animation: the .glb's clip with the exact length, the method track of Events and the markers. Saved as <dir>/<tag>.res.
func _make_clip(dir: String, tag: String, clip: Dictionary, glb: AnimationPlayer, events: AnimationPlayer, tick_info: Dictionary,
		loops: bool, row: Dictionary) -> Animation:
	if not glb.has_animation(StringName(tag)):
		return null
	var source := glb.get_animation(StringName(tag))
	var anim := source.duplicate() as Animation
	var fps := maxf(float(clip.get("framerate", 30)), 1.0)
	var length := float(int(clip.get("frames", roundi(source.length * fps)))) / fps
	row["max_len_diff_ms"] = maxf(float(row["max_len_diff_ms"]), absf(source.length - length) * 1000.0)
	anim.length = length
	anim.step = 1.0 / fps
	anim.loop_mode = Animation.LOOP_LINEAR if loops else Animation.LOOP_NONE
	var event_times: Array[float] = []
	var attack_times: Array[float] = []
	if events != null and events.has_animation(StringName(tag)):
		var source_events := events.get_animation(StringName(tag))
		for track in source_events.get_track_count():
			if source_events.track_get_type(track) != Animation.TYPE_METHOD:
				continue
			var out_track := anim.add_track(Animation.TYPE_METHOD)
			anim.track_set_path(out_track, NodePath("../ClipEvents"))
			for key in source_events.track_get_key_count(track):
				var at := source_events.track_get_key_time(track, key)
				var value: Dictionary = source_events.track_get_key_value(track, key)
				anim.track_insert_key(out_track, at, value)
				row["methods"] += 1
				event_times.append(at)
				if (value.get("args", []) as Array).has("attack"):
					attack_times.append(at)
	var hits: Array = tick_info.get("hits", [])
	var shoots: Array = tick_info.get("shoots", [])
	_add_markers(anim, "hit", hits, fps, length, event_times, row)
	_add_markers(anim, "shoot", shoots, fps, length, event_times, row)
	if hits.is_empty() and shoots.is_empty() and not attack_times.is_empty():
		anim.add_marker(&"hit", attack_times[0])
	row["markers"] += anim.get_marker_names().size()
	var path := "%s/%s.res" % [dir, tag]
	anim.take_over_path(path)
	return anim if ResourceSaver.save(anim, path) == OK else null


## Markers `name`, `name2`... at tick / fps; counts how many coincide with a method key of the Events (the dictionary vs the Events).
func _add_markers(anim: Animation, marker: String, frames: Array, fps: float, length: float, event_times: Array[float], row: Dictionary) -> void:
	for i in frames.size():
		var at := minf(float(frames[i]) / fps, length)
		anim.add_marker(StringName(marker if i == 0 else "%s%d" % [marker, i + 1]), at)
		row["hit_total"] += 1
		for t in event_times:
			if absf(t - at) < 0.0001:
				row["hit_ok"] += 1
				break
