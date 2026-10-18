extends SceneTree

## RFC-023 023e: where a skeletal body stands over its capsule. For every clip of the model, at frames 0 / middle / last,
## the posed vertices (CPU skinning) go through the game's axes (z mirrored, BodyRig) and the pose
## the BodyVisual applies (BodyCatalog.pose, skeletal), and the horizontal distance of the body to the capsule axis
## (x = z = 0 of the body) is printed: of the centroid of the vertices (the torso weighs most) and of the AABB centre
## (arms and tools stretch it). Headless: "$GODOT" --headless --path game --script res://tools/audit_skeletal_center.gd
## [-- --models=sacd,eorc]. Ends with CENTER AUDIT PASS or FAIL. Judged: the clips the game plays for the model, by the
## CENTROID: the rest pose (stance1, else idle) within REST_LIMIT of the axis, run/walk within MOVE_LIMIT and the melee
## clips (a doctor leans over what it works on) within ACT_LIMIT. The other clips are printed, not judged.

const MODELS_DIR := "res://assets/original/models"
const MIRROR := Vector3(1.0, 1.0, -1.0)
const DEFAULT_MODELS := ["sacd"]
## Horizontal distance of the centroid to the capsule axis that still reads as «centred» (m), by what the clip does.
const REST_LIMIT := 0.30
const MOVE_LIMIT := 0.40
const ACT_LIMIT := 0.60


func _initialize() -> void:
	var models: Array = DEFAULT_MODELS.duplicate()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--models="):
			models = arg.trim_prefix("--models=").split(",")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MODELS_DIR.path_join("index.json")))
	var creatures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OriginalAssets.DATA_DIR + "creatures.json"))
	var failed := false
	print("model\tclip\tframe\tcentroid_x\tcentroid_z\tcentroid_dist\taabb_cx\taabb_cz\tverdict")
	for model: String in models:
		if not index.has(model):
			print("%s\t-\tFAIL (not in index.json)" % model)
			failed = true
			continue
		var judged := _judged_tags(creatures, model)
		var state := GLTFState.new()
		var doc := GLTFDocument.new()
		state.set_additional_data("GLTFRemoveImmutableTracks", false)
		if doc.append_from_file(ProjectSettings.globalize_path(MODELS_DIR.path_join(index[model]["glb"])), state) != OK:
			print("%s\t-\tFAIL (glb does not parse)" % model)
			failed = true
			continue
		var scene_root: Node = doc.generate_scene(state)
		root.add_child(scene_root)
		var skeleton := scene_root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := scene_root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh_node := scene_root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var pose := BodyCatalog.pose(model, true, true)
		var clips: Dictionary = index[model]["clips"]
		var tags: Array = clips.keys()
		tags.sort()
		for clip: String in tags:
			var frames := int(clips[clip]["frames"])
			if frames < 2 or not player.has_animation(clip):
				continue
			for frame: int in [0, frames / 2, frames - 1]:
				player.stop()
				skeleton.reset_bone_poses()
				player.play(clip)
				player.seek(float(frame) / float(clips[clip]["framerate"]), true)
				player.advance(0.0)
				var points := _skin(mesh_node, skeleton)
				var sum := Vector3.ZERO
				var box := AABB()
				for i in points.size():
					var p := pose * (MIRROR * points[i])
					sum += p
					box = AABB(p, Vector3.ZERO) if i == 0 else box.expand(p)
				var centroid := sum / float(points.size())
				var flat := Vector2(centroid.x, centroid.z).length()
				var middle := box.get_center()
				var is_judged := judged.has(clip)
				var ok := not is_judged or flat <= float(judged[clip])
				failed = failed or not ok
				print("%s\t%s%s\t%d\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%s" % [model, clip, "*" if is_judged else "", frame,
					centroid.x, centroid.z, flat, middle.x, middle.z, "ok" if ok else "FAIL"])
	print("(* = clip the game plays for this model; the verdict only judges those)")
	print("CENTER AUDIT %s (limits rest %.2f, move %.2f, act %.2f m)" % ["FAIL" if failed else "PASS", REST_LIMIT, MOVE_LIMIT, ACT_LIMIT])
	quit(1 if failed else 0)


## tag -> limit of the clips the creatures that draw `model` play: the rest pose, run/walk and melee.
func _judged_tags(creatures: Dictionary, model: String) -> Dictionary:
	var tags := {}
	for key: String in creatures:
		var row: Dictionary = creatures[key]
		if str(row.get("model", "")) != model:
			continue
		var rest := str((row.get("stance_animation", {}) as Dictionary).get("tag", ""))
		if rest.is_empty():
			rest = str((row.get("idle_animation", {}) as Dictionary).get("tag", ""))
		tags[rest] = REST_LIMIT
		for field: String in ["run_animation", "walk_animation"]:
			tags[str((row.get(field, {}) as Dictionary).get("tag", ""))] = MOVE_LIMIT
		for clip: Variant in row.get("melee_animations", []):
			tags[str((clip as Dictionary).get("tag", ""))] = ACT_LIMIT
	tags.erase("")
	return tags


func _skin(mesh_node: MeshInstance3D, skeleton: Skeleton3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var mesh := mesh_node.mesh
	var skin := mesh_node.skin
	var matrices: Array[Transform3D] = []
	var globals: Array[Transform3D] = []
	for b in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(b)
		globals.append(skeleton.get_bone_pose(b) if parent < 0 else globals[parent] * skeleton.get_bone_pose(b))
	for i in skin.get_bind_count():
		var bone := skin.get_bind_bone(i)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(i))
		matrices.append(globals[bone] * skin.get_bind_pose(i))
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per_vertex := bones.size() / verts.size()
		for v in verts.size():
			var p := Vector3.ZERO
			for k in per_vertex:
				var w := weights[v * per_vertex + k]
				if w != 0.0:
					p += (matrices[bones[v * per_vertex + k]] * verts[v]) * w
			out.append(p)
	return out
