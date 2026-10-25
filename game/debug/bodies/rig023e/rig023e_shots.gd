extends Node3D

## RFC-023 023e capture: a Sac Doctor walks, then takes a Trogg: the captive rises, floats and thrashes in the ring.
##   godot --path game --max-fps 60 --resolution 1280x720 res://debug/bodies/rig023e/rig023e_shots.tscn -- --out=/abs/dir
## Prints the role of both rigs at every shot, and (055a-5) the metrics of the captive's ragdoll. One PNG per moment.

const UNIT := preload("res://scenes/units/unit.tscn")
const DOCTOR := preload("res://scenes/sacrifice/doctor.tscn")
const METRICS := preload("res://debug/bodies/ragdoll_metrics.gd")

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
	_captive.type = GameData.creature("ycro")
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
	print("SHOT %s doctor=%s captive=%s mode=%d %s" % [name_, rig.active_role(), crig.active_role(), _captive.mode, _ragdoll_metrics(crig)])


## The numbers of the captive's ragdoll (ragdoll_metrics.gd) at this moment: pose, extent and stretch against the rest pose, how far under
## the anchor it hangs, NaN. "ragdoll=none" when the model has no ragdoll.
func _ragdoll_metrics(crig: BodyRig) -> String:
	var model := crig.model_root()
	var driver := _captive.find_child("RagdollDriver", false, false) as RagdollDriver
	if model == null or model.ragdoll == null or driver == null:
		return "ragdoll=none"
	var skeleton := crig.skeleton()
	var rest := PackedVector3Array()
	var now := PackedVector3Array()
	var parents := PackedInt32Array()
	for bone in skeleton.get_bone_count():
		rest.append(skeleton.global_transform * skeleton.get_bone_global_rest(bone).origin)
		now.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin)
		parents.append(skeleton.get_bone_parent(bone))
	var ref_m := maxf(METRICS.longest_side(rest), 0.3)
	var m := {
		"extent_ratio": METRICS.extent_ratio(now, ref_m),
		"stretch_ratio": METRICS.stretch_ratio(rest, now, parents),
		"nan": METRICS.has_nan(now),
	}
	if model.hang_bone != null:
		m["drop_ratio"] = METRICS.drop_ratio(now, now[model.hang_bone.get_bone_id()].y, ref_m)
	return "pose=%d %s" % [driver.pose(), METRICS.summary(m)]


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
