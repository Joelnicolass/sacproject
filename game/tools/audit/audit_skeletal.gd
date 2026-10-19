extends SceneTree

## RFC-023a: parity of the skeletal models against the baked OBJ frames.
## For every clip of the test models that has a baked reference, imports the .glb, seeks the AnimationPlayer to
## frames {0, middle, last}, skins the mesh on the CPU (skeleton global pose x skin bind) and compares every vertex
## with the same frame of the baked OBJ. Prints model / clip / frame / max_err_mm and fails above TOLERANCE_MM.
## "$GODOT" --headless --path game --script res://tools/audit/audit_skeletal.gd [-- --dir=res://other/models --models=eorc,jnwr --ref=DIR]
## --clips=FILE: a JSON {model: [tag]} (tools/import/export_skeletal_reference.py --unit-clips writes it): only those clips are audited.
## --ref=DIR: reference OBJs written by tools/import/export_skeletal_reference.py (sacengine export, every clip, frames
## 0 / middle / last: <DIR>/<model>/<clip>/<frame>.obj). A clip without them fails. --ref is required
## (RFC-023 023h retired the baked OBJs this audit used to fall back on).
## Vertices whose raw weights do not sum to 1 (index.json unnormalized_vertices) are compared the way the game
## computes them (weights not normalized: p = D + sum * (p_normalized - D), D = root displacement), so a 4 mm
## difference there is predicted, not tolerated.
## Ends with SKELETAL AUDIT PASS, or SKELETAL AUDIT FAIL and exit code 1.

## The one place that names where the skeletal models live (same folder export_skeletal.py writes to).
const MODELS_DIR := "res://assets/original/models"
## Baked per-frame OBJs, only the parity reference. Retired with RFC-023h.
const DEFAULT_MODELS := ["eorc", "jnwr"]
## RFC-023 023g (user decision 2026-10-17): <= 30 mm per vertex with one bind per vertex; 1 mm is no longer required.
const TOLERANCE_MM := 30.0


func _initialize() -> void:
	var dir := MODELS_DIR
	var models: Array = DEFAULT_MODELS.duplicate()
	var ref_dir := ""
	var only: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			dir = arg.trim_prefix("--dir=")
		elif arg.begins_with("--models="):
			models = arg.trim_prefix("--models=").split(",")
		elif arg.begins_with("--ref="):
			ref_dir = arg.trim_prefix("--ref=")
		elif arg.begins_with("--clips="):
			only = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--clips=")))
	if ref_dir == "":
		push_error("audit_skeletal: --ref=DIR is required (tools/import/export_skeletal_reference.py writes it)")
		quit(1)
		return
	var index: Dictionary = {}
	var text := FileAccess.get_file_as_string(dir.path_join("index.json"))
	if text != "":
		index = JSON.parse_string(text)
	var failed := false
	var rows := 0
	var missing := 0
	var clips_audited := 0
	var clips_total := 0
	print("model\tclip\tframe\tmax_err_mm\tverts_over_tol\tunnorm\tunnorm_pred_mm\tunnorm_raw_mm\tresult")
	for model: String in models:
		if not index.has(model):
			print("%s\t-\t-\t-\t-\tFAIL (not in index.json)" % model)
			failed = true
			continue
		var glb: String = dir.path_join(index[model]["glb"])
		# The editor import regenerates tangents (mikktspace), which reorders and merges vertices, so the
		# per-vertex comparison reads the glb itself; the imported scene is only checked for loading.
		var imported: PackedScene = load(glb)
		if imported == null:
			print("%s\t-\t-\t-\t-\tFAIL (glb does not import)" % model)
			failed = true
			continue
		var state := GLTFState.new()
		var doc := GLTFDocument.new()
		# Same as the .glb.import: a constant non-rest track must not be dropped.
		state.set_additional_data("GLTFRemoveImmutableTracks", false)
		if doc.append_from_file(ProjectSettings.globalize_path(glb), state) != OK:
			print("%s\t-\t-\t-\t-\tFAIL (glb does not parse)" % model)
			failed = true
			continue
		var scene_root: Node = doc.generate_scene(state)
		root.add_child(scene_root)
		var skeleton := _find(scene_root, "Skeleton3D") as Skeleton3D
		var player := _find(scene_root, "AnimationPlayer") as AnimationPlayer
		var mesh_node := _find(scene_root, "MeshInstance3D") as MeshInstance3D
		if skeleton == null or player == null or mesh_node == null:
			print("%s\t-\t-\t-\t-\tFAIL (missing Skeleton3D / AnimationPlayer / MeshInstance3D)" % model)
			failed = true
			continue
		print("# %s: %d joints, %d animations, mesh node at %s" % [model, skeleton.get_bone_count(), player.get_animation_list().size(), mesh_node.transform])
		var clips: Dictionary = index[model]["clips"]
		var unnorm: Array = index[model].get("unnormalized_vertices", [])
		var unnorm_global := _global_indices(mesh_node, unnorm)
		for clip: String in clips.keys():
			if not only.is_empty() and not (only.get(model, []) as Array).has(clip):
				continue
			clips_total += 1
			var clip_dir := ref_dir.path_join(model).path_join(clip)
			var frames := int(clips[clip]["frames"])
			var framerate := float(clips[clip]["framerate"])
			var wanted: Array = [0, frames / 2, frames - 1]
			var have := true
			for frame: int in wanted:
				have = have and FileAccess.file_exists(clip_dir.path_join("%d.obj" % frame))
			if ref_dir == "" and have and _frame_count(clip_dir) != frames:
				print("%s\t%s\t-\t-\t-\t-\t-\t-\tFAIL (baked %d frames, clip %d)" % [model, clip, _frame_count(clip_dir), frames])
				failed = true
				continue
			if not have:
				if ref_dir != "":
					print("%s\t%s\t-\t-\t-\t-\t-\t-\tFAIL (no reference OBJ)" % [model, clip])
					failed = true
				missing += 1
				continue
			if not player.has_animation(clip):
				print("%s\t%s\t-\t-\t-\t-\t-\t-\tFAIL (animation missing in glb)" % [model, clip])
				failed = true
				continue
			clips_audited += 1
			for frame: int in wanted:
				var ref := _read_obj(clip_dir.path_join("%d.obj" % frame), index[model].get("dropped_vertices", []))
				player.stop()
				# Constant tracks equal to the rest pose are dropped by the glTF importer: start every seek from rest.
				skeleton.reset_bone_poses()
				player.play(clip)
				player.seek(float(frame) / framerate, true)
				player.advance(0.0)
				var skinned := _skin(mesh_node, skeleton)
				if skinned.size() != ref.size():
					print("%s\t%s\t%d\t-\t-\t-\t-\t-\tFAIL (%d skinned vertices, %d in OBJ)" % [model, clip, frame, skinned.size(), ref.size()])
					failed = true
					continue
				# Root displacement D = origin of the root bone (the only translation track).
				var d := skeleton.get_bone_pose(0).origin
				var pred := 0.0
				var raw := 0.0
				for k in unnorm.size():
					var gi: int = unnorm_global[k]
					var s_sum := float(unnorm[k]["weight_sum"])
					raw = maxf(raw, skinned[gi].distance_to(ref[gi]) * 1000.0)
					pred = maxf(pred, absf(s_sum - 1.0) * (skinned[gi] - d).length() * 1000.0)
					skinned[gi] = d + (skinned[gi] - d) * s_sum
				var worst := 0.0
				var over := 0
				for i in skinned.size():
					var err := skinned[i].distance_to(ref[i]) * 1000.0
					worst = maxf(worst, err)
					if err > TOLERANCE_MM:
						over += 1
				var ok := worst <= TOLERANCE_MM
				failed = failed or not ok
				rows += 1
				print("%s\t%s\t%d\t%.3f\t%d\t%d\t%.2f\t%.2f\t%s" % [model, clip, frame, worst, over, unnorm.size(), pred, raw, "ok" if ok else "FAIL"])
	if rows == 0:
		failed = true
	print("# clips audited %d of %d (%d without reference OBJ)" % [clips_audited, clips_total, missing])
	print("SKELETAL AUDIT %s (%d rows, tolerance %.1f mm)" % ["FAIL" if failed else "PASS", rows, TOLERANCE_MM])
	quit(1 if failed else 0)


func _find(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _find(child, type_name)
		if found != null:
			return found
	return null


## Index in the concatenated skinned list of each {surface, vertex} entry.
func _global_indices(mesh_node: MeshInstance3D, entries: Array) -> Array:
	var starts: Array[int] = []
	var total := 0
	for s in mesh_node.mesh.get_surface_count():
		starts.append(total)
		total += mesh_node.mesh.surface_get_array_len(s)
	var out := []
	for e: Dictionary in entries:
		out.append(starts[int(e["surface"])] + int(e["vertex"]))
	return out


func _frame_count(clip_dir: String) -> int:
	var dir := DirAccess.open(clip_dir)
	if dir == null:
		return 0
	var count := 0
	for file in dir.get_files():
		if file.ends_with(".obj"):
			count += 1
	return count


## Vertices of every surface, in surface order, as Godot skins them on the GPU.
func _skin(mesh_node: MeshInstance3D, skeleton: Skeleton3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var mesh := mesh_node.mesh
	var skin := mesh_node.skin
	var binds := skin.get_bind_count()
	var matrices: Array[Transform3D] = []
	# Global poses from the local poses, parents first: independent of the skeleton's cached global poses.
	var globals: Array[Transform3D] = []
	for b in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(b)
		globals.append(skeleton.get_bone_pose(b) if parent < 0 else globals[parent] * skeleton.get_bone_pose(b))
	for i in binds:
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


## Vertices of a baked OBJ in file order (all body parts). Same axes the game uses: no transform.
## dropped: per body part, vertex indices the exporter did not write (no face uses them).
func _read_obj(path: String, dropped: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	var part := -1
	var local := 0
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("o "):
			part += 1
			local = 0
		elif line.begins_with("v "):
			var skip: bool = part >= 0 and part < dropped.size() and (dropped[part] as Array).has(float(local))
			if not skip:
				var parts := line.split(" ", false)
				out.append(Vector3(parts[1].to_float(), parts[2].to_float(), parts[3].to_float()))
			local += 1
	return out
