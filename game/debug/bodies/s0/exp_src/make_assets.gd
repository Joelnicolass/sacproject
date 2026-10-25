extends SceneTree
## 055s s0 (disposable): runs INSIDE the probe export project (tmp_exp). Writes 40 big binary Animation .res files, the
## AnimationLibrary .res that holds them (like scenes/bodies/models/<tag>_clips) and ref.tscn (AudioStreamPlayer on a WAV + an
## AnimationPlayer with the library). Always quits.

const ANIMS := 40
const TRACKS := 60
const KEYS := 120


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("S0 export make_assets TIMEOUT")
		quit(2))
	quit(_main())


func _main() -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://clips"))
	var lib := AnimationLibrary.new()
	for i in range(ANIMS):
		var a := Animation.new()
		a.length = 2.0
		for t in range(TRACKS):
			var tr := a.add_track(Animation.TYPE_ROTATION_3D)
			a.track_set_path(tr, NodePath("Skeleton3D:bone%d" % t))
			for k in range(KEYS):
				var q := Quaternion(Vector3.UP, float(k + t + i) * 0.01)
				a.rotation_track_insert_key(tr, float(k) / float(KEYS - 1) * 2.0, q)
		var p := "res://clips/a%02d.res" % i
		if ResourceSaver.save(a, p) != OK:
			print("S0 export make_assets ERROR saving %s" % p)
			return 1
		lib.add_animation(StringName("role%02d" % i), ResourceLoader.load(p))
	if ResourceSaver.save(lib, "res://clips/lib.res") != OK:
		print("S0 export make_assets ERROR saving lib")
		return 1
	print("S0 export make_assets DONE animations=%d tracks=%d keys=%d" % [ANIMS, TRACKS, KEYS])
	return 0
