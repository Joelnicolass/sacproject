extends Node3D

## RFC-023 023c capture: six creatures in a row, the fixed camera, one PNG per role. Run it twice, with and without
## `--baked-bodies`, into two folders, then compare them with agent/tools/rig023c_diff.py:
##   godot --path game --max-fps 60 --resolution 1280x720 res://debug/rig023c/rig023c_shots.tscn -- --out=/abs/dir [--baked-bodies]
## --empty leaves the units out (the background the diff subtracts). Each role is played for the same number of physics ticks, then the clocks are frozen; the skeleton is put on the very
## frame the clock stopped on (BodyRig.pose_at), so what differs is the look of the two bodies and not their timing.

const UNIT := preload("res://scenes/world/units/unit.tscn")
const TAGS: Array[String] = ["ycro", "amuh", "raeb", "grdg", "mtsl", "saep"]
## "idle0" is the old rest of the level-1 creatures (the baked bodies' idle) against the skeleton's gesture role (idle0).
const ROLES: Array[String] = ["idle", "run", "attack", "idle0"]
## Where each one stands (x, m): the dragon and the ent are big and need room.
const X: Array[float] = [-18.0, -12.0, -6.0, 6.0, 20.0, 27.0]
const TICKS := 24

var _out := ""
var _empty := false
var _effects := false
var _units: Array[UnitBody] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--empty":
			_empty = true
		elif arg == "--effects":
			_effects = true
	DirAccess.make_dir_recursive_absolute(_out)
	for i in 0 if _empty else TAGS.size():
		var unit := UNIT.instantiate() as UnitBody
		unit.creature_tag = TAGS[i]
		unit.set("owner_slot", 1)
		unit.set("idle_aggro", false)
		add_child(unit)
		unit.set_physics_process(false)
		unit.position = Vector3(X[i], 0.0, 0.0)
		_units.append(unit)
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	var report: PackedStringArray = []
	for role in ROLES:
		for unit in _units:
			(unit.get_node("ClipPose") as ClipPlayback).frozen = false
			unit.debug_set_clip_state(("idle" if BodyCatalog.baked_bodies_forced() else "gesture") if role == "idle0" else role)
		for i in TICKS:
			await get_tree().physics_frame
		for unit in _units:
			var animator := unit.get_node("ClipPose") as BodyAnimator
			animator.frozen = true
			var rig := unit.get_node("Tilt/Mesh/Rig") as BodyRig
			if animator.is_skeletal() and rig.is_loaded():
				rig.pose_at(animator.active_role(), float(animator.active_frame()) / maxf(float(animator.active_framerate()), 1.0))
			var screen_x := get_viewport().get_camera_3d().unproject_position(unit.global_transform.origin + Vector3.UP).x
			report.append("%s\t%s\tframe=%d\tskeletal=%s\tscreen_x=%.0f" % [unit.creature_tag, role, animator.active_frame(), animator.is_skeletal(), screen_x])
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out.path_join("%s.png" % role))
	if _effects:
		await _effect_shots()
	var file := FileAccess.open(_out.path_join("report.txt"), FileAccess.WRITE)
	file.store_string("\n".join(report) + "\n")
	file.close()
	print("RIG023C_SHOTS done %s baked=%s" % [_out, BodyCatalog.baked_bodies_forced()])
	get_tree().quit()


## --effects: stone (units 0 and 3), fade (units 1 and 4) and then both off, to see that the skeleton takes them like the
## baked mesh did and that taking them off puts the textures back.
func _effect_shots() -> void:
	for unit in _units:
		(unit.get_node("ClipPose") as ClipPlayback).frozen = false
		unit.debug_set_clip_state("idle")
	for i in 6:
		await get_tree().process_frame
	for i in [0, 3]:
		(_units[i].get_node("Afflictions/Look") as StoneLook).stone = true
	for i in [1, 4]:
		(_units[i].get_node("Tilt/Mesh") as BodyVisual).set_fade(0.6)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("effects_on.png"))
	for i in [0, 3]:
		(_units[i].get_node("Afflictions/Look") as StoneLook).stone = false
	for i in [1, 4]:
		(_units[i].get_node("Tilt/Mesh") as BodyVisual).set_fade(0.0)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("effects_off.png"))
