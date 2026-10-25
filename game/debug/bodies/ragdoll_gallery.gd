extends Node3D

## RFC-055 055a-5, debug only: every body type that has a ragdoll, in a grid, each one in a RagdollCell with the real RagdollDriver.
## F6 runs --mode=hang and stays open. Flags (after `--`): --mode=hang|fall (hang: every Hook moves at 11 m/s for `move_s`, then stops;
## fall: every body dies on the floor), --metrics (headless: one line per model and `RAGDOLL HANG|FALL PASS|FAIL <n>/<total>`, exit 0 or 1),
## --only=<stem>, --out=<dir> (ragdoll_<mode>.png at the end, needs a window). A model without a hang bone keeps its clips in the game: it
## is listed as skipped, not counted. Thresholds: ragdoll_metrics.gd. What it does not do: edit a model (that is done in its scene).

const CELL := preload("res://debug/bodies/ragdoll_cell.tscn")
const METRICS := preload("res://debug/bodies/ragdoll_metrics.gd")
const HOOK_SPEED_M_S := 11.0

@export_range(2, 20) var columns := 10
@export_range(2.0, 10.0, 0.5, "suffix:m") var spacing_m := 5.0
@export_range(0.5, 5.0, 0.1, "suffix:s") var move_s := 2.0  ## how long the Hook moves
@export_range(0.5, 5.0, 0.1, "suffix:s") var rest_s := 3.0  ## how long the body rests before it is measured

var _mode := "hang"
var _only := ""
var _out := ""
var _metrics := false
var _cells: Array[RagdollCell] = []
var _results: Dictionary[RagdollCell, Dictionary] = {}

@onready var _camera: Camera3D = %Camera


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--metrics":
			_metrics = true
		elif arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_build()
	_run.call_deferred()


## One cell per distinct model that has a ragdoll, in the order of the body scenes.
func _build() -> void:
	var seen := {}
	for look: PackedScene in RagdollCell.all_looks():
		var cell := CELL.instantiate() as RagdollCell
		var index := _cells.size()
		cell.position = Vector3((index % columns) * spacing_m, 0.0, (index / columns) * spacing_m)
		add_child(cell)
		var stem := ""
		if cell.load_look(look):
			stem = cell.model.scene_file_path.get_file().get_basename()
		if stem.is_empty() or seen.has(stem) or (not _only.is_empty() and stem != _only):
			cell.free()
			continue
		seen[stem] = true
		cell.name = stem
		_cells.append(cell)
	var rows := ceili(_cells.size() / float(columns))
	var center := Vector3((mini(columns, _cells.size()) - 1) * spacing_m * 0.5, 1.0, (rows - 1) * spacing_m * 0.5)
	var span := maxf(columns * spacing_m + HOOK_SPEED_M_S * move_s, rows * spacing_m)
	_camera.position = center + Vector3(0.0, span * 0.5, span * 0.8)
	_camera.look_at(center)


func _run() -> void:
	await _ticks(2)
	if _mode == "fall":
		await _fall()
	else:
		await _hang()
	var failed := _report()
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out.path_join("ragdoll_%s.png" % _mode))
	if _metrics or not _out.is_empty():
		get_tree().quit(1 if failed > 0 else 0)


## Hang from a Hook that moves at 11 m/s and stops: the anchor must follow, nothing stretches, and the body hangs still at the end.
func _hang() -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	var hangers: Array[RagdollCell] = []
	for cell in _cells:
		_results[cell] = {}
		if cell.driver.can_hang():
			hangers.append(cell)
			cell.hook.position = Vector3(-HOOK_SPEED_M_S * move_s * 0.5, cell.ref_m * 1.5, 0.0)
		else:
			_results[cell]["skip"] = true
	await _ticks(2)
	for cell in hangers:
		cell.driver.set_pose(RagdollDriver.Pose.HANG)
	await _ticks(ceili(0.5 / dt))
	for _tick in ceili(move_s / dt):
		for cell in hangers:
			cell.hook.position.x += HOOK_SPEED_M_S * dt
		await _ticks(1)
		for cell in hangers:
			cell.track_hang(_results[cell])
	await _ticks(ceili(rest_s / dt) - 1)
	var before := {}
	for cell in hangers:
		before[cell] = cell.points()
	await _ticks(1)
	for cell in hangers:
		cell.end_hang(_results[cell], before[cell], dt)


## Every body dies on the floor: it must lie low, stay near where it fell and freeze when `settle_s` is over.
func _fall() -> void:
	var settle := 0.0
	var starts := {}
	for cell in _cells:
		starts[cell] = cell.points()[0]
		settle = maxf(settle, cell.driver.settle_s)
	await _ticks(5)
	for cell in _cells:
		cell.driver.set_pose(RagdollDriver.Pose.FALL, Vector3.BACK)
	await _ticks(ceili((settle + 1.0) * Engine.physics_ticks_per_second))
	for cell in _cells:
		_results[cell] = {}
		cell.end_fall(_results[cell], starts[cell])


## Prints one line per model and the verdict. Returns how many failed.
func _report() -> int:
	var total := 0
	var passed := 0
	var skipped := PackedStringArray()
	for cell in _cells:
		var m := _results[cell]
		if m.get("skip", false):
			skipped.append(cell.name)
			continue
		var fails := METRICS.fall_failures(m, cell.driver.max_drift_m) if _mode == "fall" else METRICS.hang_failures(m)
		total += 1
		passed += 1 if fails.is_empty() else 0
		print("  %s %s %s%s" % [cell.name, "PASS" if fails.is_empty() else "FAIL", METRICS.summary(m), "" if fails.is_empty() else " <- " + ", ".join(fails)])
	if not skipped.is_empty():
		print("  skipped, no hang bone (%d): %s" % [skipped.size(), ", ".join(skipped)])
	print("RAGDOLL %s %s %d/%d" % [_mode.to_upper(), "PASS" if total > 0 and passed == total else "FAIL", passed, total])
	return maxi(total - passed, 1 if total == 0 else 0)


func _ticks(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame
