extends SceneTree

## Does not need the original game: it reads the albedo already in the repo. The relief (normal map,
## and an ORM if the recipe asks) of materials, from their albedo, without the editor UI. The same
## ReliefBaker and MapWriter as the editor's buttons.
##
##   Godot --headless --path . --script res://tools/bake/bake_relief.gd --
##   res://scenes/bodies/materials/eorc_001.tres
##   Godot --headless --path . --script res://tools/bake/bake_relief.gd --
##   res://scenes/bodies/materials/ --force
##   Godot --headless --path . --script res://tools/bake/bake_relief.gd -- <folder|material>
##   --recipe=res://addons/surface_maps/recipes/foliage.tres   (plants, leaves)
##
## A folder takes every .tres in it (not its subfolders) that is a BaseMaterial3D (or has an
## `albedo`) with an albedo. It never replaces a map PNG that exists (`--force` does, and throws
## away what you retouched) and then assigns the maps to the material and saves it. A map PNG
## written now is not imported yet, so it cannot be assigned in the same run: run `Godot --headless
## --path . --import` (or open the editor) and the same command again (it keeps the PNGs, assigns
## them).
## Options: --force  --recipe=res://<a ReliefRecipe>.tres (default: ReliefRecipe's defaults, normal
## only)


func _init() -> void:
	var targets := PackedStringArray()
	var force := false
	var recipe := ReliefRecipe.new()
	for arg in OS.get_cmdline_user_args():
		if arg == "--force":
			force = true
		elif arg.begins_with("--recipe="):
			recipe = load(arg.trim_prefix("--recipe=")) as ReliefRecipe
		elif not arg.begins_with("--"):
			targets.append_array(_files_of(arg))
	if recipe == null or targets.is_empty():
		printerr(
			"bake_relief: usage: -- <folder|material.tres> [--force] [--recipe=res://recipe.tres]"
		)
		quit(1)
		return
	var counts := {"written": 0, "assigned": 0, "pending": 0, "skipped": 0}
	for path in targets:
		_bake_one(path, recipe, force, counts)
	print(
		(
			"bake_relief: %d maps written, %d materials assigned, %d waiting for import, %d skipped"
			% [counts.written, counts.assigned, counts.pending, counts.skipped]
		)
	)
	if counts.pending > 0:
		print(
			# gdlint: ignore=max-line-length
			"bake_relief: run `Godot --headless --path . --import` and the same command again to assign the new maps"
		)
	quit()


func _bake_one(path: String, recipe: ReliefRecipe, force: bool, counts: Dictionary) -> void:
	var target := load(path) as Resource
	var image := MapWriter.albedo_image(target) if target != null else null
	if image == null or not (target is BaseMaterial3D or "albedo" in target):
		counts.skipped += 1
		return
	var keys := ["normal", "orm"] if recipe.orm else ["normal"]
	var on_disk := MapWriter.existing(target)
	if force or keys.any(func(key: String) -> bool: return not on_disk.has(key)):
		counts.written += MapWriter.write(target, ReliefBaker.bake(image, recipe), force).size()
		on_disk = MapWriter.existing(target)
	var wanted := {}
	for key: String in keys:
		if on_disk.has(key):
			wanted[key] = on_disk[key]
	if MapWriter.assign(target, wanted) and ResourceSaver.save(target) == OK:
		counts.assigned += 1
	else:
		counts.pending += 1


## The material at `arg`, or every .tres directly inside the folder `arg`.
func _files_of(arg: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(arg):
		out.append(arg)
		return out
	var dir := arg.trim_suffix("/") + "/"
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "tres":
			out.append(dir + file)
	return out
