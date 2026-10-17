extends Node3D

## RFC-023 (023b): the baked clip (left, one mesh per frame from cache/look/anim_f37) next to the skeletal BodyRig
## (right), same model and role, fixed orthographic camera, neutral light, no shadows.
## Keys: ui_right / ui_left change the model, ui_up / ui_down the role, ui_accept toggles `stepped`.
## `-- --setup=res://debug/skeletal_compare_jnwr.tres` opens on another model and role.
## `-- --capture=/abs/dir` runs the acceptance measurement without input and quits: for every role with baked frames
## it poses both sides at frames 0 / middle / last, renders each alone from the same fixed camera (both at the origin),
## saves a side by side PNG (the center 640 px of each) and a difference PNG, and prints the numeric difference of the two
## full images. Run it with a window: --resolution 1280x720 --max-fps 60. It also checks that a role change leaves no
## pose of the previous clip.
## The baked side is cache/, debug only: it goes away with RFC-023h.

const _OBJ := preload("res://scenes/world/obj_mesh.gd")
const BAKED_DIR := "res://cache/look/anim_f37"
const CLIPS_DIR := "res://data/bodies/clips/"
const RIG_SCENE := preload("res://scenes/world/body/body_rig.tscn")
## The capture models; the interactive view cycles every model of index.json that has a BodyClips file.
const CAPTURE_MODELS: PackedStringArray = ["eorc", "jnwr"]
## A pixel counts as body when it is further than this (sum of channels, 0-765) from the background.
const BODY_THRESHOLD := 12
## A pixel counts as different when a channel differs by more than this (0-255).
const PIXEL_TOLERANCE := 16
## Verdict limits: pixels only one side draws (% of the body pixels) and mean channel difference (0-255) over the body.
## Identical geometry still measures ~0.1 % and ~3 (normals), so these are the "same pose" bar.
const MAX_SILHOUETTE_PCT := 0.5
const MAX_MEAN_DIFF := 6.0
const SETTLE_FRAMES := 3

@export var setup: SkeletalCompareSetup

var _models: PackedStringArray = []
var _model_at := 0
var _role_at := 0
var _clock := 0.0
var _capturing := false
var _baked_cache: Dictionary = {}

@onready var _baked: MeshInstance3D = %BakedMesh
@onready var _rig: BodyRig = %Rig
@onready var _label: Label = %Info


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var capture_dir := ""
	for arg in args:
		if arg.begins_with("--setup="):
			setup = load(arg.trim_prefix("--setup=")) as SkeletalCompareSetup
		elif arg.begins_with("--capture="):
			capture_dir = arg.trim_prefix("--capture=")
	_models = _available_models()
	if setup == null:
		setup = SkeletalCompareSetup.new()
	if _models.is_empty():
		_label.text = "Missing assets: run tools/export_skeletal.py (assets/original/models/index.json)."
		return
	_model_at = maxi(_models.find(setup.model), 0)
	_rig.stepped = setup.stepped
	_show_model(_models[_model_at])
	_role_at = maxi(_roles().find(setup.role), 0)
	_play_role()
	if not capture_dir.is_empty():
		_capturing = true
		_label.visible = false
		_run_capture.call_deferred(capture_dir)


func _unhandled_input(event: InputEvent) -> void:
	if _models.is_empty() or _capturing:
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_left"):
		var step := 1 if event.is_action_pressed("ui_right") else -1
		_model_at = posmod(_model_at + step, _models.size())
		_show_model(_models[_model_at])
		_role_at = 0
		_play_role()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		var step := 1 if event.is_action_pressed("ui_down") else -1
		_role_at = posmod(_role_at + step, maxi(_roles().size(), 1))
		_play_role()
	elif event.is_action_pressed("ui_accept"):
		_rig.stepped = not _rig.stepped
		_play_role()
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _capturing or _models.is_empty() or not _rig.is_loaded():
		return
	var role := _role()
	var frames := _rig.role_frames(role)
	var fps := _rig.role_framerate(role)
	if frames <= 1:
		return
	_clock = fposmod(_clock + delta, frames / fps)
	_show_baked(role, int(_clock * fps) % frames)
	_label.text = "%s  %s (%s)  baked frame %d / %d  %s\n[ui_left/right] model  [ui_up/down] role  [ui_accept] stepped" % [
		_models[_model_at], role, _rig.role_tag(role), int(_clock * fps) % frames, frames,
		"stepped (original)" if _rig.stepped else "smooth"]


## Models of index.json that have a BodyClips file under data/bodies/clips/.
func _available_models() -> PackedStringArray:
	var out := PackedStringArray()
	var index := FileAccess.get_file_as_string(OriginalAssets.models_index())
	var parsed: Variant = JSON.parse_string(index) if not index.is_empty() else null
	if parsed is Dictionary:
		for model: String in (parsed as Dictionary).keys():
			if ResourceLoader.exists(CLIPS_DIR + model + ".tres"):
				out.append(model)
	out.sort()
	return out


func _show_model(model: String) -> void:
	_rig.set_body(model, load(CLIPS_DIR + model + ".tres") as BodyClips)
	_clock = 0.0


func _roles() -> PackedStringArray:
	var out := PackedStringArray()
	for role in BodyClips.ROLES:
		if _rig.has_role(role):
			out.append(role)
	return out


func _role() -> String:
	var roles := _roles()
	return roles[clampi(_role_at, 0, roles.size() - 1)] if not roles.is_empty() else "idle"


func _play_role() -> void:
	_clock = 0.0
	_rig.play(_role(), true)


## Baked frame `frame` of `role`'s clip on the left column; no mesh when cache/ has no such frame.
func _show_baked(role: String, frame: int) -> void:
	var path := "%s/%s/%s/%d.obj" % [BAKED_DIR, _models[_model_at] if not _capturing else _rig.model, _rig.role_tag(role), frame]
	if not _baked_cache.has(path):
		_baked_cache[path] = _OBJ.build(path, {_OBJ.MIRROR_Z: true}) if FileAccess.file_exists(path) else null
	_baked.mesh = _baked_cache[path]


func _has_baked(model: String, tag: String) -> bool:
	return FileAccess.file_exists("%s/%s/%s/0.obj" % [BAKED_DIR, model, tag])


# ---------------------------------------------------------------------------------------------------------
# Capture and measurement
# ---------------------------------------------------------------------------------------------------------

func _run_capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	(_baked.get_parent() as Node3D).position.x = 0.0
	_rig.position.x = 0.0
	var lines := PackedStringArray()
	var failed := false
	lines.append("model\trole\ttag\tmode\tframe\tbody_px\tsilhouette_mismatch_pct\tmean_abs_diff\tpx_over_tol_pct\tresult")
	for stepped in [false, true]:
		_rig.stepped = stepped
		for model in CAPTURE_MODELS:
			_show_model(model)
			await _settle()
			for role in _roles():
				var tag := _rig.role_tag(role)
				if not _has_baked(model, tag):
					continue
				var frames := _rig.role_frames(role)
				var fps := _rig.role_framerate(role)
				for frame in [0, frames / 2, frames - 1]:
					var name := "%s_%s_f%02d_%s" % [model, role, frame, "stepped" if stepped else "smooth"]
					var result := await _compare_at(role, frame, frame / fps, dir, name, not stepped)
					lines.append("%s\t%s\t%s\t%s\t%d\t%d\t%.3f\t%.3f\t%.3f\t%s" % [model, role, tag,
						"stepped" if stepped else "smooth", frame, result["body"], result["silhouette"], result["mean"], result["over"], result["verdict"]])
					failed = failed or result["verdict"] != "ok"
	lines.append("# 0.4 of a frame past the middle frame: the rig is posed between two keys, the baked side shows the middle frame")
	for model in CAPTURE_MODELS:
		_show_model(model)
		for stepped in [true, false]:
			_rig.stepped = stepped
			await _settle()
			for role in _roles():
				var tag := _rig.role_tag(role)
				if not _has_baked(model, tag) or _rig.role_frames(role) < 4:
					continue
				var frame := _rig.role_frames(role) / 2
				var name := "%s_%s_f%02d_plus0.4_%s" % [model, role, frame, "stepped" if stepped else "smooth"]
				var result := await _compare_at(role, frame, (frame + 0.4) / _rig.role_framerate(role), "", name, false)
				lines.append("%s\t%s\t%s\t%s\t%d+0.4\t%d\t%.3f\t%.3f\t%.3f\t(informative)" % [model, role, tag,
					"stepped" if stepped else "smooth", frame, result["body"], result["silhouette"], result["mean"], result["over"]])
	var role_lines := await _check_role_changes()
	lines.append_array(role_lines)
	failed = failed or "\n".join(role_lines).contains("FAIL")
	var report := "\n".join(lines)
	print(report)
	var file := FileAccess.open(dir.path_join("report.txt"), FileAccess.WRITE)
	if file:
		file.store_string(report + "\n")
	print("SKELETAL COMPARE %s" % ("FAIL" if failed else "PASS"))
	get_tree().quit(1 if failed else 0)


func _settle() -> void:
	for i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw


## Renders the baked `frame` and the rig at `seconds` of the same role, one at a time from the same camera, and compares
## them. `dir` empty: nothing is saved.
func _compare_at(role: String, frame: int, seconds: float, dir: String, name: String, with_diff: bool) -> Dictionary:
	_rig.pose_at(role, seconds)
	_show_baked(role, frame)
	_baked.visible = true
	_rig.visible = false
	await _settle()
	var baked_image := get_viewport().get_texture().get_image()
	_baked.visible = false
	_rig.visible = true
	await _settle()
	var rig_image := get_viewport().get_texture().get_image()
	_baked.visible = true
	return _measure(baked_image, rig_image, dir, name, with_diff)


## Compares the baked image with the rig image pixel by pixel. Verdict "ok" when the silhouettes and the colours agree.
## The colours differ a little even with identical geometry: the baked frames carry sacengine's per-frame normals, the
## skinned mesh the transformed rest normals.
func _measure(baked_image: Image, rig_image: Image, dir: String, name: String, with_diff: bool) -> Dictionary:
	baked_image.convert(Image.FORMAT_RGB8)
	rig_image.convert(Image.FORMAT_RGB8)
	var width := baked_image.get_width()
	var height := baked_image.get_height()
	var a := baked_image.get_data()
	var b := rig_image.get_data()
	var background := [a[0], a[1], a[2]]
	var diff_bytes := PackedByteArray()
	if with_diff:
		diff_bytes.resize(width * height * 3)
	var body := 0
	var only_one := 0
	var over := 0
	var sum_abs := 0
	for i in range(0, width * height * 3, 3):
		var dr: int = absi(a[i] - b[i])
		var dg: int = absi(a[i + 1] - b[i + 1])
		var db: int = absi(a[i + 2] - b[i + 2])
		if with_diff:
			diff_bytes[i] = mini(dr * 4, 255)
			diff_bytes[i + 1] = mini(dg * 4, 255)
			diff_bytes[i + 2] = mini(db * 4, 255)
		var in_a: bool = absi(a[i] - background[0]) + absi(a[i + 1] - background[1]) + absi(a[i + 2] - background[2]) > BODY_THRESHOLD
		var in_b: bool = absi(b[i] - background[0]) + absi(b[i + 1] - background[1]) + absi(b[i + 2] - background[2]) > BODY_THRESHOLD
		if not (in_a or in_b):
			continue
		body += 1
		if in_a != in_b:
			only_one += 1
		sum_abs += dr + dg + db
		if maxi(dr, maxi(dg, db)) > PIXEL_TOLERANCE:
			over += 1
	if not dir.is_empty():
		# Left: baked, right: rig, the center 640 px of each (the figures fit; a long staff may be cut).
		var side := Image.create(width, height, false, Image.FORMAT_RGB8)
		var center := Rect2i(width / 4, 0, width / 2, height)
		side.blit_rect(baked_image, center, Vector2i(0, 0))
		side.blit_rect(rig_image, center, Vector2i(width / 2, 0))
		side.save_png(dir.path_join(name + "_side.png"))
		if with_diff:
			Image.create_from_data(width, height, false, Image.FORMAT_RGB8, diff_bytes).save_png(dir.path_join(name + "_diff.png"))
	var result := {"body": body, "silhouette": 0.0, "mean": 0.0, "over": 0.0, "verdict": "ok"}
	if body == 0:
		result["verdict"] = "FAIL (nothing drawn)"
		return result
	result["silhouette"] = 100.0 * only_one / body
	result["mean"] = float(sum_abs) / (body * 3.0)
	result["over"] = 100.0 * over / body
	if result["silhouette"] > MAX_SILHOUETTE_PCT or result["mean"] > MAX_MEAN_DIFF:
		result["verdict"] = "FAIL"
	return result


## Poses two rigs through the state machine: A plays role a, advances, then switches to role b; B plays b from the start.
## After the same time in b every bone must be where B has it (no pose of the previous clip left on a bone the new clip
## does not animate). Returns report lines.
func _check_role_changes() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("# role change: max bone pose difference between 'a then b' and 'b alone' (translation m, rotation rad)")
	var worst_all := 0.0
	var other: BodyRig = RIG_SCENE.instantiate()
	other.position = Vector3(0.0, 0.0, -10.0)
	add_child(other)
	for model in CAPTURE_MODELS:
		_show_model(model)
		_rig.stepped = false
		other.set_body(model, _rig.clips)
		await _settle()
		var roles := _roles()
		var worst := 0.0
		for a in roles:
			for b in roles:
				if a == b:
					continue
				_rig.play(a, true)
				_rig.advance(0.4)
				_rig.play(b, true)
				_rig.advance(0.37)
				other.play(b, true)
				other.advance(0.37)
				worst = maxf(worst, _pose_distance(_rig.skeleton(), other.skeleton()))
		lines.append("%s\tbones %d\troles %d\tmax_pose_diff %.6f\t%s" % [model, _rig.skeleton().get_bone_count(), roles.size(), worst, "ok" if worst < 0.0001 else "FAIL"])
		worst_all = maxf(worst_all, worst)
	other.queue_free()
	if worst_all >= 0.0001:
		lines.append("# role change FAIL")
	return lines


func _pose_distance(a: Skeleton3D, b: Skeleton3D) -> float:
	var worst := 0.0
	for bone in a.get_bone_count():
		worst = maxf(worst, a.get_bone_pose_position(bone).distance_to(b.get_bone_pose_position(bone)))
		worst = maxf(worst, a.get_bone_pose_rotation(bone).angle_to(b.get_bone_pose_rotation(bone)))
	return worst
