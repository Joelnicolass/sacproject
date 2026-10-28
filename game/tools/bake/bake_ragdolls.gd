extends SceneTree

## Gives the models of scenes/bodies/models/ the physical skeleton their bodies fall and hang with (RagdollBaker does the work).
## A model that already has its "Ragdoll" keeps it (an edit made by hand is safe) and only gets the exports of its root completed;
## `--force` bakes it again from scratch. Walks the model files by name, never by tag. Needs no autoload.
##
## Run:  Godot --headless --path . --script res://tools/bake/bake_ragdolls.gd -- <stem|res://...tscn>... [--missing] [--skip=<stem>] [--force]
##   --missing   every model of the folder (the ones without a Ragdoll are baked, the others only completed)
##   --skip=X    leave the model with stem X out (repeatable)
## Prints one line per model and `RAGDOLL BAKE baked=N completed=M failed=K`; exits 1 when something failed.

const MODEL_DIR := "res://scenes/bodies/models/"


func _init() -> void:
	var names: Array[String] = []
	var skip: Array[String] = []
	var force := false
	var everything := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--force":
			force = true
		elif arg == "--missing":
			everything = true
		elif arg.begins_with("--skip="):
			skip.append(arg.trim_prefix("--skip="))
		else:
			names.append(arg)
	if everything:
		names.append_array(_all_stems())
	var done: Array[String] = []
	var counts := {"baked": 0, "completed": 0, "failed": 0}
	for name_or_path in names:
		var stem := name_or_path.get_file().get_basename()
		if done.has(stem) or skip.has(stem):
			continue
		done.append(stem)
		counts[_bake(MODEL_DIR + stem + ".tscn", stem, force)] += 1
	print(
		(
			"RAGDOLL BAKE baked=%d completed=%d failed=%d"
			% [counts["baked"], counts["completed"], counts["failed"]]
		)
	)
	quit(1 if counts["failed"] > 0 else 0)


## Bakes or completes one model file. Returns which count it adds to: "baked", "completed" or "failed".
func _bake(path: String, stem: String, force: bool) -> String:
	var packed := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if packed == null:
		printerr("bake_ragdolls: no scene %s" % path)
		return "failed"
	var root := packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var fresh := force or not RagdollBaker.has_ragdoll(root)
	var bodies := RagdollBaker.add_to(root) if fresh else 0
	var changed := fresh or RagdollBaker.complete(root)
	var problem := "no Skeleton3D or no bodies" if fresh and bodies <= 0 else ""
	if problem.is_empty() and changed:
		problem = RagdollBaker.save(root, path)
	root.free()
	if not problem.is_empty():
		printerr("bake_ragdolls: %s: %s" % [stem, problem])
		return "failed"
	print(
		(
			"bake_ragdolls: %s -> %s"
			% [stem, "%d bodies" % bodies if fresh else "kept, exports completed"]
		)
	)
	return "baked" if fresh else "completed"


## The stem of every model scene of the folder, in name order.
func _all_stems() -> Array[String]:
	var stems: Array[String] = []
	for file in DirAccess.get_files_at(MODEL_DIR):
		if file.ends_with(".tscn"):
			stems.append(file.get_basename())
	stems.sort()
	return stems
