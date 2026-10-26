extends Node

## Agent-only (063D F4): fixed-camera shots of the deformed ground, the same on every run, to compare the deformation
## texture before and after a change. It loads cast_terrain.tscn, presses Erupt's three stamps (Mound, Rebound, Wave) by
## hand at fixed seconds of their timelines (no clock, no caster), then keeps a Volcano crater, cuts a hole and plays Erupt
## again over both. Every shot waits `settle_frames` and saves <out>/<nn>_<label>.png. It moves no actor.
## Run (window): godot --path game res://agent/perf/deform_shot.tscn -- --out=<dir>

@export var world_scene: PackedScene
@export var erupt_zone: PackedScene
@export var volcano_zone: PackedScene
@export var camera: Camera3D
@export_range(1.0, 30.0, 0.5, "suffix:s") var warmup_s := 8.0
@export_range(1, 240) var settle_frames := 45
@export_range(20.0, 400.0, 1.0, "suffix:m") var ahead_m := 120.0
@export_range(20.0, 400.0, 1.0, "suffix:m") var side_m := 60.0
@export_range(20.0, 400.0, 1.0, "suffix:m") var up_m := 220.0

var _out := "res://agent/out/deform_shot"
var _shot := 0
var _terrain: Terrain
var _center := Vector2.ZERO


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	add_child(world_scene.instantiate())
	_run.call_deferred()


func _run() -> void:
	await _wait_s(warmup_s)
	for layer: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	_terrain = Terrain.of(self)
	var wizard := get_tree().get_first_node_in_group(&"wizard") as WizardBody
	if _terrain == null or wizard == null:
		printerr("deform_shot: no terrain or wizard")
		get_tree().quit(1)
		return
	var facing := wizard.facing_flat()
	var at := wizard.global_position + facing * ahead_m
	_center = Vector2(at.x, at.z)
	var ground := Vector3(at.x, _terrain.height_at(at.x, at.z), at.z)
	var side := facing.cross(Vector3.UP).normalized()
	camera.global_position = ground + side * side_m + Vector3(0.0, up_m, 0.0)
	camera.look_at(ground)
	camera.current = true
	print("deform_shot: center %s camera %s" % [_center, camera.global_position])
	var erupt := erupt_zone.instantiate()
	var stamps: Array[TerrainStamp] = []
	for stamp_name: String in ["Mound", "Rebound", "Wave"]:
		stamps.append(erupt.get_node(stamp_name) as TerrainStamp)
	await _capture("control")
	for t: float in [2.0, 4.0, 4.4, 4.7, 5.0]:
		_play(stamps, t)
		await _capture("erupt_%04d" % int(t * 1000.0))
	_play(stamps, 99.0)
	await _capture("erupt_over")
	var volcano := volcano_zone.instantiate()
	var crater := volcano.get_node("Crater") as TerrainStamp
	_terrain.keep_stamp(&"shot_crater", crater.profile, _center + Vector2(40.0, 0.0), _radius(crater), _peak(crater))
	_terrain.cut_hole(_center + Vector2(-40.0, 20.0))
	await _capture("crater_hole")
	_play(stamps, 4.4)
	await _capture("crater_hole_erupt_4400")
	_play(stamps, 99.0)
	await _capture("crater_hole_over")
	await _capture("crater_hole_over_again")
	erupt.free()
	volcano.free()
	print("deform_shot: %d shots in %s" % [_shot, _out])
	get_tree().quit()


## Shows each stamp as it is `t` seconds after the zone started (or takes it away outside its timeline).
func _play(stamps: Array[TerrainStamp], t: float) -> void:
	for stamp in stamps:
		var key := StringName("shot_" + String(stamp.name))
		var local := t - stamp.start_s
		if local >= 0.0 and local < stamp.profile.duration_s():
			_terrain.stamp(key, stamp.profile, _center, _radius(stamp), _peak(stamp), local)
		else:
			_terrain.unstamp(key)


func _radius(stamp: TerrainStamp) -> float:
	return (stamp.reach.shape as CylinderShape3D).radius


func _peak(stamp: TerrainStamp) -> float:
	return (stamp.reach.shape as CylinderShape3D).height


func _capture(label: String) -> void:
	for i in settle_frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%02d_%s.png" % [_out, _shot, label]
	get_viewport().get_texture().get_image().save_png(path)
	_shot += 1


func _wait_s(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
