extends Node3D

## RFC-023 023e capture: a Sac Doctor walks, then takes a Trogg: the captive rises, floats and thrashes in the ring.
##   godot --path game --max-fps 60 --resolution 1280x720 res://debug/rig023e/rig023e_shots.tscn -- --out=/abs/dir
## Prints the role of both rigs at every shot. One PNG per moment.

const UNIT := preload("res://scenes/units/unit.tscn")
const DOCTOR := preload("res://scenes/sacrifice/doctor.tscn")

var _out := ""
var _doctor: DoctorBody
var _captive: UnitBody


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	_doctor = DOCTOR.instantiate() as DoctorBody
	add_child(_doctor)
	_doctor.position = Vector3(-8.0, 0.0, 0.0)
	_captive = UNIT.instantiate() as UnitBody
	_captive.creature_tag = "ycro"
	_captive.set("owner_slot", 1)
	_captive.set("idle_aggro", false)
	add_child(_captive)
	_captive.position = Vector3(6.0, 0.0, 4.0)
	_run.call_deferred()


func _look(at: Vector3, from: Vector3) -> void:
	var camera := $Camera as Camera3D
	camera.global_position = from
	camera.look_at(at, Vector3.UP)


func _shot(name_: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name_ + ".png"))
	var rig := _doctor.get_node("Pivot/Mesh/Rig") as BodyRig
	var crig := _captive.get_node("Tilt/Mesh/Rig") as BodyRig
	print("SHOT %s doctor=%s captive=%s mode=%d" % [name_, rig.active_role(), crig.active_role(), _captive.mode])


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	await _ticks(10)
	_doctor.walk_to(Vector3(0.0, 0.0, 0.0))
	for k in 3:
		await _ticks(40)
		_look(_doctor.global_position + Vector3.UP * 1.2, _doctor.global_position + Vector3(0.0, 2.2, 7.0))
		await _shot("doctor_walk_%d" % k)
	await _ticks(60)
	var captive := Captive.of(_captive)
	print("TAKE ", captive.take(_doctor))
	for k in 6:
		await _ticks(24)
		_look(_captive.global_position + Vector3.UP * 1.0, _captive.global_position + Vector3(0.0, 3.0, 8.0))
		await _shot("captive_%d" % k)
	print("RIG023E_SHOTS done")
	get_tree().quit()
