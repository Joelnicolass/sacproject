extends Node3D

## RFC-023 023d capture: a wizard casting with the camera close. The Caster's replicated `cast_fx_shown` is set by hand (the
## cast itself is the simulation's and is not touched), then one PNG per step and a report with where the hands were.
##   godot --path game --max-fps 60 --resolution 1280x720 res://debug/bodies/rig023d/rig023d_cast.tscn -- --out=/abs/dir [--wizard=cwa0] [--fx=cast_james]
## Steps: rest pose, casting (standing) three times 0.4 s apart, casting (walking), rest again.

const WIZARD := preload("res://scenes/wizards/wizard_body.tscn")

var _out := ""
var _tag := "cwa0"
var _fx := "cast_james"
var _walk_speed := 0.0
var _wizard: WizardBody


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--wizard="):
			_tag = arg.trim_prefix("--wizard=")
		elif arg.begins_with("--fx="):
			_fx = arg.trim_prefix("--fx=")
	DirAccess.make_dir_recursive_absolute(_out)
	_wizard = WIZARD.instantiate() as WizardBody
	_wizard.wizard_type = GameData.wizard(_tag)
	_wizard.model = str(GameData.wizard(_tag).model)
	add_child(_wizard)
	_wizard.set_physics_process(false)
	_wizard.set_process(false)
	_run.call_deferred()


func _shot(step: String, report: PackedStringArray) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("%s.png" % step))
	var rig := _wizard.get_node("Tilt/Mesh/Rig") as BodyRig
	var camera := get_viewport().get_camera_3d()
	var screen: PackedStringArray = []
	for p in rig.hand_points():
		var s := camera.unproject_position(p)
		screen.append("(%.2f,%.2f,%.2f)->px(%.0f,%.0f)" % [p.x, p.y, p.z, s.x, s.y])
	var clip := _wizard.get_node("ClipPose") as ClipPlayback
	report.append("%s\trole=%s\ttag=%s\tframe=%d\thands=%s" % [step, rig.active_role(), clip.active_tag(), clip.active_frame(), " ".join(screen)])


func _ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		_wizard.call("_update_clip_state", _walk_speed)


func _run() -> void:
	await get_tree().process_frame
	var report: PackedStringArray = []
	var caster := _wizard.get_node("Caster")
	await _ticks(20)
	await _shot("1_rest", report)
	caster.set("cast_fx_shown", _fx)
	for i in 3:
		await _ticks(24)
		await _shot("2_cast_%d" % i, report)
	_walk_speed = 5.0
	await _ticks(24)
	await _shot("3_cast_run", report)
	caster.set("cast_fx_shown", "")
	_walk_speed = 0.0
	await _ticks(40)
	await _shot("4_rest_again", report)
	var file := FileAccess.open(_out.path_join("report.txt"), FileAccess.WRITE)
	file.store_string("\n".join(report) + "\n")
	file.close()
	print("RIG023D_CAST done ", _out)
	get_tree().quit()
