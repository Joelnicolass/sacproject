extends SceneTree

## Does not need the original game: it works on the meshes already saved in the project. Gives
## tangents to the saved meshes (.res) whose surfaces lack them, so a normal map on their material
## draws right.
## One-shot: run it once when rules_suite `surface_refs_cases` reports `no_tangents` > 0, then
## commit the rewritten .res files.
##
##   Godot --path . --script res://tools/bake/add_tangents.gd                       #
##   scenes/props/meshes and scenes/bodies/meshes
##   Godot --path . --script res://tools/bake/add_tangents.gd -- res://scenes/props/meshes/casp.res
##   --dry
##
## Each surface is rebuilt with SurfaceTool.generate_tangents(); its material, name, primitive and
## the mesh's custom AABB stay (the mesh is rewritten in place, so its uid and every reference to it
## stay too). A surface that already has tangents is left alone. A mesh with blend shapes is skipped
## (it says so). `--dry` only lists what it would change.
## Not: the animated models (.glb): their import already has meshes/ensure_tangents=true.

const DEFAULT_DIRS: PackedStringArray = [
	"res://scenes/props/meshes/", "res://scenes/bodies/meshes/"
]
const KEPT_FLAGS := (
	Mesh.ARRAY_FLAG_USE_2D_VERTICES
	| Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE
	| Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	| Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dry := args.has("--dry")
	var paths := PackedStringArray()
	for arg in args:
		if not arg.begins_with("--"):
			paths.append(arg)
	if paths.is_empty():
		paths = DEFAULT_DIRS
	var counts := {"meshes": 0, "rewritten": 0, "failed": 0}
	for path in _mesh_files(paths):
		counts["meshes"] += 1
		var result := _add_tangents(path, dry)
		if result < 0:
			counts["failed"] += 1
		elif result > 0:
			counts["rewritten"] += 1
	print(
		(
			"add_tangents: meshes=%d %s=%d failed=%d"
			% [
				counts["meshes"],
				"would_rewrite" if dry else "rewritten",
				counts["rewritten"],
				counts["failed"]
			]
		)
	)
	quit(1 if counts["failed"] > 0 else 0)


func _mesh_files(paths: PackedStringArray) -> PackedStringArray:
	var files := PackedStringArray()
	for path in paths:
		if path.ends_with(".res"):
			files.append(path)
			continue
		var dir := path if path.ends_with("/") else path + "/"
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".res"):
				files.append(dir + file)
	return files


## Surfaces given tangents (0: none needed), or -1 when the mesh could not be rewritten.
func _add_tangents(path: String, dry: bool) -> int:
	var mesh := load(path) as ArrayMesh
	if mesh == null:
		printerr("add_tangents: %s is not an ArrayMesh" % path)
		return -1
	var missing := PackedInt32Array()
	for i in mesh.get_surface_count():
		if (mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_TANGENT) == 0:
			missing.append(i)
	if missing.is_empty():
		return 0
	if mesh.get_blend_shape_count() > 0:
		printerr("add_tangents: %s has blend shapes, skipped" % path)
		return -1
	print("add_tangents: %s surfaces %s" % [path, missing])
	if dry:
		return missing.size()
	var rebuilt: Array[Dictionary] = []
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		if arrays.is_empty():
			printerr(
				(
					"add_tangents: %s surface %d has no readable data (run without --headless)"
					% [path, i]
				)
			)
			return -1
		if i in missing:
			var tool := SurfaceTool.new()
			tool.create_from(mesh, i)
			tool.generate_tangents()
			arrays = tool.commit_to_arrays()
		rebuilt.append(
			{
				"arrays": arrays,
				"primitive": mesh.surface_get_primitive_type(i),
				"material": mesh.surface_get_material(i),
				"name": mesh.surface_get_name(i),
				"flags": mesh.surface_get_format(i) & KEPT_FLAGS
			}
		)
	var box := mesh.custom_aabb
	mesh.clear_surfaces()
	for i in rebuilt.size():
		var surface := rebuilt[i]
		mesh.add_surface_from_arrays(
			surface["primitive"], surface["arrays"], [], {}, surface["flags"]
		)
		mesh.surface_set_material(i, surface["material"])
		mesh.surface_set_name(i, surface["name"])
	mesh.custom_aabb = box
	if ResourceSaver.save(mesh, path) != OK:
		printerr("add_tangents: could not save %s" % path)
		return -1
	return missing.size()
