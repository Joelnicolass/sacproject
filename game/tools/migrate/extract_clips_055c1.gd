extends SceneTree

## 055c1 / c1-c1, step 2 of 2 (once; needs Godot and the imported .glb): writes the clip Animations the libraries point at.
## Reads tools/migrate/clips_plan_055c1.json (extract_clips_055c1.py wrote it, with the 85 <model>_clips.tres and the 74 scenes) and, for
## every animation of the plan, saves scenes/bodies/models/<model>_clips/<file>.res:
##   - the bone tracks of the .glb clip (only the clips a model scene draws; the ones only the rules read have no tracks, just a time),
##   - length = frames / fps and step = 1 / fps, exact, the loop mode of its role (loop / once / hold),
##   - the markers `hit`, `hit2`... and `shoot`, `shoot2`... at the seconds the plan gives,
##   - the method track at "../ClipEvents" with the keys the scene's old `Events` player had.
## It stops by itself before the 120 s watchdog ("EXTRACT PARTIAL ..." and exit 3) and skips the models already done, so
## tools/migrate/run_extract_clips_055c1.sh runs it again until "EXTRACT DONE". Every path ends in quit().
## "$GODOT" --headless --path game --script res://tools/migrate/extract_clips_055c1.gd [-- --force] [-- --only=eorc,jnwr]
## Prints EXTRACT model=..., EXTRACT PARTIAL|DONE ... (exit 3|0) or EXTRACT FAIL <reason> (exit 1).

const PLAN_PATH := "res://tools/migrate/clips_plan_055c1.json"
const MODELS_DIR := "res://scenes/bodies/models/"
const EVENTS_PATH := "../ClipEvents"
const WATCHDOG_S := 120.0
## The script stops starting new models after this, leaving margin for the one in flight to finish.
const BUDGET_MS := 80000

var _started_ms := 0
var _res_bytes := 0
var _anims := 0


func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	create_timer(WATCHDOG_S).timeout.connect(func() -> void:
		print("EXTRACT FAIL watchdog %d s" % int(WATCHDOG_S))
		quit(1))
	var code: Variant = _run()
	if code == null:
		print("EXTRACT FAIL script error (see the log above)")
		quit(1)
		return
	quit(int(code))


func _run() -> int:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLAN_PATH))
	if not parsed is Dictionary:
		print("EXTRACT FAIL no plan at %s (run extract_clips_055c1.py first)" % PLAN_PATH)
		return 1
	var models: Dictionary = (parsed as Dictionary)["models"]
	var force := OS.get_cmdline_user_args().has("--force")
	var only := PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",", false)
	var names: Array = models.keys()
	names.sort()
	var done := 0
	var left := 0
	for model: String in names:
		if not only.is_empty() and not only.has(model):
			continue
		var data: Dictionary = models[model]
		if not force and _is_done(model, data):
			done += 1
			continue
		if Time.get_ticks_msec() - _started_ms > BUDGET_MS:
			left += 1
			continue
		var error := _extract(model, data)
		if not error.is_empty():
			print("EXTRACT FAIL %s: %s" % [model, error])
			return 1
		done += 1
	if left > 0:
		print("EXTRACT PARTIAL done=%d left=%d anims_this_run=%d (run it again)" % [done, left, _anims])
		return 3
	print("EXTRACT DONE models=%d anims_this_run=%d res_bytes_this_run=%d" % [done, _anims, _res_bytes])
	return 0


func _path(model: String, file: String) -> String:
	return "%s%s_clips/%s.res" % [MODELS_DIR, model, file]


func _is_done(model: String, data: Dictionary) -> bool:
	for file: String in data["anims"]:
		if not FileAccess.file_exists(_path(model, file)):
			return false
	return true


## Saves every animation of one model. Returns "" or the reason it failed.
func _extract(model: String, data: Dictionary) -> String:
	var anims: Dictionary = data["anims"]
	var source: AnimationPlayer = null
	var instance: Node = null
	var drawn := false
	for file: String in anims:
		drawn = drawn or bool(anims[file]["tracks"])
	if drawn:
		var glb := load(str(data["glb"])) as PackedScene
		instance = glb.instantiate() if glb != null else null
		if instance != null:
			var found := instance.find_children("*", "AnimationPlayer", true, false)
			source = found[0] as AnimationPlayer if not found.is_empty() else null
		if source == null:
			if instance != null:
				instance.free()
			return "%s is missing, a Git LFS pointer or not imported (git lfs pull, then godot --import)" % data["glb"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s%s_clips" % [MODELS_DIR, model]))
	var bytes := 0
	var worst_ms := 0.0
	for file: String in anims:
		var spec: Dictionary = anims[file]
		var anim := _make(source, spec)
		if anim == null:
			if instance != null:
				instance.free()
			return "the .glb has no clip %s (file %s)" % [spec["tag"], file]
		if spec["tracks"]:
			worst_ms = maxf(worst_ms, absf(source.get_animation(StringName(str(spec["tag"]))).length - anim.length) * 1000.0)
		var path := _path(model, file)
		anim.take_over_path(path)
		if ResourceSaver.save(anim, path) != OK:
			if instance != null:
				instance.free()
			return "cannot save " + path
		bytes += FileAccess.get_file_as_bytes(path).size()
		_anims += 1
	_res_bytes += bytes
	if instance != null:
		instance.free()
	print("EXTRACT model=%s anims=%d res_bytes=%d len_vs_glb_max_ms=%.3f" % [model, anims.size(), bytes, worst_ms])
	return ""


## One Animation from its plan entry; null when it needs tracks and the .glb has no clip with that tag.
func _make(source: AnimationPlayer, spec: Dictionary) -> Animation:
	var anim: Animation
	if spec["tracks"]:
		if source == null or not source.has_animation(StringName(str(spec["tag"]))):
			return null
		anim = source.get_animation(StringName(str(spec["tag"]))).duplicate() as Animation
	else:
		anim = Animation.new()
	var fps := float(spec["fps"])
	anim.resource_name = str(spec["tag"])
	anim.length = float(spec["frames"]) / fps
	anim.step = 1.0 / fps
	anim.loop_mode = Animation.LOOP_LINEAR if spec["loop"] == "loop" else Animation.LOOP_NONE
	var events: Array = spec["events"]
	if not events.is_empty():
		var track := anim.add_track(Animation.TYPE_METHOD)
		anim.track_set_path(track, NodePath(EVENTS_PATH))
		for event: Array in events:
			anim.track_insert_key(track, minf(float(event[0]), anim.length), {"method": &"fire", "args": [str(event[1])]})
	_add_markers(anim, "hit", spec["hit"])
	_add_markers(anim, "shoot", spec["shoot"])
	return anim


## Markers `name`, `name2`... at the given seconds. Two markers at the same instant replace each other (a clip that is both the
## attack and the shot of a creature), so a taken instant moves by NUDGE_S: far less than half a frame, the same frame once rounded.
const NUDGE_S := 0.0001


func _add_markers(anim: Animation, marker: String, seconds: Array) -> void:
	for i in seconds.size():
		var at := minf(float(seconds[i]), anim.length)
		while _marker_at(anim, at):
			at -= NUDGE_S
		anim.add_marker(StringName(marker if i == 0 else "%s%d" % [marker, i + 1]), at)


func _marker_at(anim: Animation, at: float) -> bool:
	for name: StringName in anim.get_marker_names():
		if is_equal_approx(anim.get_marker_time(name), at):
			return true
	return false
