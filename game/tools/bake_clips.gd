extends SceneTree

## RFC-027 027h: bakes every clip frame OBJ of the clips JSON into a geometry .res, so ClipPosePlayer loads it with
## ResourceLoader instead of parsing the OBJ the first time the frame shows (10–15 ms each). Sister of bake_bodies.gd.
##   "$GODOT" --headless --path game --fixed-fps 60 --script res://tools/bake_clips.gd [-- --force]
## Output: BodyCatalog.clip_frame_path(obj) under cache/baked/clips/ (ignored by git, like all of cache/), with a
## .gdignore so the editor never scans it. Incremental: a frame whose .res is newer than its OBJ is skipped.
## No materials are saved (each frame would embed its own texture copy): every surface is named after its OBJ
## label and ClipPosePlayer puts back the shared ObjMesh.material() at load.

const _OBJ := preload("res://scenes/world/obj_mesh.gd")
const CLIPS := "res://cache/data/anim_mesh_clips_f37.json"


func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var force := OS.get_cmdline_user_args().has("--force")
	if not FileAccess.file_exists(CLIPS):
		push_error("Falta %s" % CLIPS)
		quit(1)
		return
	var clips: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLIPS))
	var root := BodyCatalog.BAKED_DIR + BodyCatalog.CLIPS_SUBDIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var ignore := FileAccess.open(root + ".gdignore", FileAccess.WRITE)
	ignore.close()
	var baked := 0
	var skipped := 0
	var failed := 0
	var seen := {}
	for model: Variant in clips:
		var by_tag: Dictionary = clips[model]
		for tag: Variant in by_tag:
			for frame: Variant in by_tag[tag].get("frame_objs", []):
				var obj := str(frame)
				if seen.has(obj):
					continue
				seen[obj] = true
				var out := BodyCatalog.clip_frame_path(obj)
				if out.is_empty() or not FileAccess.file_exists(obj):
					failed += 1
					continue
				if not force and FileAccess.file_exists(out) \
						and FileAccess.get_modified_time(out) >= FileAccess.get_modified_time(obj):
					skipped += 1
					continue
				if _bake(obj, out):
					baked += 1
				else:
					failed += 1
				if (baked + skipped) % 1000 == 0:
					print("bake_clips: %d horneados, %d al día, %d ms" % [baked, skipped, Time.get_ticks_msec() - started])
	print("bake_clips: %d cuadros horneados, %d al día, %d fallidos, en %d ms" % [baked, skipped, failed, Time.get_ticks_msec() - started])
	quit(1 if failed > 0 else 0)


func _bake(obj: String, out: String) -> bool:
	var built := _OBJ.build(obj, "", {_OBJ.MIRROR_Z: true})
	if built == null:
		push_error("No se pudo armar %s" % obj)
		return false
	for i in built.get_surface_count():
		var mat := built.surface_get_material(i)
		# ObjMesh names each material after its OBJ label; a surface without texture has none, and gets none back.
		built.surface_set_name(i, mat.resource_name if mat else "")
		built.surface_set_material(i, null)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var err := ResourceSaver.save(built, out, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("No se pudo guardar %s (%d)" % [out, err])
		return false
	return true
