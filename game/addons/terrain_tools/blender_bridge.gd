@tool
extends RefCounted

## Runs Blender on a map's ground: the .blend made from the map's pictures (tools/blender/terrain_make_blend.py), the
## pictures written back from it (terrain_export_images.py, which refuses with a reason and writes nothing), and Blender
## opened on that .blend for a human. Blender is the environment variable BLENDER (or BLENDER_BIN, as agent/harness/env.sh),
## else `blender` in the PATH, else the usual macOS install. Blocking calls: run them on a worker thread from the editor.
## Not: what the scripts check (they do), reimporting the pictures (the caller), the original game (none needed).

const MAKE_SCRIPT := "res://tools/blender/terrain_make_blend.py"
const EXPORT_SCRIPT := "res://tools/blender/terrain_export_images.py"
const WORK_DIR := "terrain_work"
const BLEND_FILE := "terrain.blend"
const MAC_APP := "/Applications/Blender.app/Contents/MacOS/Blender"
const HOW_TO := "No encontré Blender. Instalalo (4.x) y ponelo en el PATH, o definí la variable de entorno BLENDER con la ruta del ejecutable (por ejemplo BLENDER=/Applications/Blender.app/Contents/MacOS/Blender) y abrí Godot de nuevo."


## What one Blender run did: its exit code and what it printed.
class Run:
	var code := -1
	var output := ""

	func ok() -> bool:
		return code == 0

	## The lines a human needs: the scripts' verdict and every ERROR.
	func summary() -> String:
		var lines := PackedStringArray()
		for line in output.split("\n"):
			if line.begins_with("ERROR") or line.begins_with("TERRAIN"):
				lines.append(line.strip_edges())
		return "\n".join(lines) if not lines.is_empty() else output.right(600)


## The Blender executable, or "" when there is none (show HOW_TO).
static func find() -> String:
	for variable in ["BLENDER", "BLENDER_BIN"]:
		var named := OS.get_environment(variable)
		if not named.is_empty() and FileAccess.file_exists(named):
			return named
	var separator := ";" if OS.get_name() == "Windows" else ":"
	for folder in OS.get_environment("PATH").split(separator, false):
		for file in ["blender", "blender.exe"]:
			if FileAccess.file_exists(folder.path_join(file)):
				return folder.path_join(file)
	return MAC_APP if OS.get_name() == "macOS" and FileAccess.file_exists(MAC_APP) else ""


## The .blend of the map whose pictures are in `folder` (res:// or absolute).
static func blend_of(folder: String) -> String:
	return folder.path_join(WORK_DIR).path_join(BLEND_FILE)


## Makes `folder`/terrain_work/terrain.blend from the pictures in `folder`, over an older one.
static func make_blend(folder: String) -> Run:
	return run(["--background", "--factory-startup", "--python", absolute(MAKE_SCRIPT), "--", "--map=" + absolute(folder)])


## Writes the pictures of `folder` back from its terrain.blend (or from `blend`). `force` skips the guard against
## pictures that changed after the .blend was made.
static func export_images(folder: String, force: bool, blend := "") -> Run:
	var source := blend if not blend.is_empty() else blend_of(folder)
	var arguments := ["--background", "--factory-startup", absolute(source), "--python", absolute(EXPORT_SCRIPT),
			"--", "--out=" + absolute(folder)]
	if force:
		arguments.append("--force")
	return run(arguments)


## Opens Blender with the map's .blend for a human and returns at once (the process id, or -1).
static func open_blend(folder: String) -> int:
	var blender := find()
	return OS.create_process(blender, [absolute(blend_of(folder))]) if not blender.is_empty() else -1


## Runs Blender with `arguments` (res:// and user:// paths must be made absolute first, see absolute) and waits.
static func run(arguments: Array) -> Run:
	var done := Run.new()
	var blender := find()
	if blender.is_empty():
		done.output = HOW_TO
		return done
	var printed := []
	done.code = OS.execute(blender, PackedStringArray(arguments), printed, true)
	done.output = "\n".join(PackedStringArray(printed))
	return done


## `path` as the file system sees it.
static func absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
