extends Node3D

## F208 (RFC-036 036g): dumps "model|role|t|hash" for every (model, role) of every creature and wizard, where hash is the
## pose of the skeleton at that second of the role's clip. Run once before and once after the model-scene change; the two
## files must match line by line. Window run (headless loads no meshes). Output: res://agent/out/f208/poses_<phase>.txt.

const TIMES := [0.0, 0.37, 0.9]
const RIG_SCENE := preload("res://scenes/bodies/body_rig.tscn")


func _ready() -> void:
	await get_tree().process_frame
	var phase := "before"
	for arg in OS.get_cmdline_user_args():
		phase = arg
	var rig := RIG_SCENE.instantiate() as BodyRig
	add_child(rig)
	var lines := PackedStringArray()
	for job: Array in _jobs():
		var model: String = job[0]
		if not BodyModel.exists(model):
			lines.append("%s|nonskeletal" % model)
			continue
		_show(rig, model, job[1])
		await get_tree().process_frame
		if not rig.is_loaded():
			lines.append("%s|notloaded" % model)
			continue
		for role: String in _roles():
			if not rig.has_role(role):
				continue
			for t: float in TIMES:
				rig.pose_at(role, t)
				lines.append("%s|%s|%.2f|%s" % [model, role, t, _hash(rig.skeleton())])
	lines.sort()
	var unique := PackedStringArray()
	for line in lines:
		if unique.is_empty() or unique[unique.size() - 1] != line:
			unique.append(line)
	var file := FileAccess.open("res://agent/out/f208/poses_%s.txt" % phase, FileAccess.WRITE)
	file.store_string("\n".join(unique) + "\n")
	file.close()
	print("F208_POSES %s lines=%d" % [phase, unique.size()])
	get_tree().quit()


func _hash(skeleton: Skeleton3D) -> String:
	var text := ""
	for i in skeleton.get_bone_count():
		var pose := skeleton.get_bone_global_pose(i)
		for v: Vector3 in [pose.origin, pose.basis.x, pose.basis.y, pose.basis.z]:
			text += "%.3f,%.3f,%.3f;" % [v.x, v.y, v.z]
	return str(text.hash())


# AFTER-API part (the before run used BodyClips / UnitClipRoles).
func _roles() -> PackedStringArray:
	return BodyModel.ROLES


func _jobs() -> Array:
	var out: Array = []
	var models := {}
	for t: CreatureType in GameData.all_creatures():
		models[t.model_id()] = true
	for w: WizardType in GameData.wizards():
		models[w.model_id()] = true
	for model: String in models:
		out.append([model, {}])
	return out


func _show(rig: BodyRig, model: String, _roles_of_model: Dictionary) -> void:
	var look := BodyLook.new()
	var root := (load(BodyModel.scene_path(model)) as PackedScene).instantiate() as BodyModel
	look.add_child(root)
	look.model = root
	rig.mount(look)
