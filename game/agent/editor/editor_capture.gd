@tool
extends Node

## RFC-035 editor probe. An autoload that exists only while agent/scripts/editor_capture.sh runs (a temporary override.cfg).
## It opens a scene in the editor, waits, frames the 3D viewport on the terrain, writes
## agent/out/035/editor_<step>.png and editor_<step>.json, prints one EDITOR_CAPTURE line per step and quits.
## With --reload it then reloads terrain.gd (what a git pull or an agent edit does to a @tool script) and repeats as step "reload".
## Lives in agent/editor/, not agent/harness/: it reads the editor, not a match, so the harness rules do not apply.
## User args (after `--`): --scene=res://...  --out=res://agent/out/035  --frames=N  --reload

const DEFAULT_SCENE := "res://scenes/match/high_noon.tscn"
const TERRAIN_SCRIPT := "res://scenes/map/terrain/terrain.gd"
const COUNTED := ["Buildings", "Npcs"]

var _scene := DEFAULT_SCENE
var _out := "res://agent/out/035"
var _frames := 90
var _reload := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			_scene = argument.substr(8)
		elif argument.begins_with("--out="):
			_out = argument.substr(6)
		elif argument.begins_with("--frames="):
			_frames = int(argument.substr(9))
		elif argument == "--reload":
			_reload = true
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _wait_frames(30)
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	EditorInterface.open_scene_from_path(_scene)
	await _wait_frames(_frames)
	await _capture("open")
	if _reload:
		var script := load(TERRAIN_SCRIPT) as Script
		script.reload(true)
		await _wait_frames(_frames)
		await _capture("reload")
	get_tree().quit()


func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _capture(step: String) -> void:
	var root := EditorInterface.get_edited_scene_root()
	var terrain: MeshInstance3D = TerrainShape.of(root) as MeshInstance3D if root else null
	var report := {"step": step, "scene": _scene, "scene_open": root != null, "terrain_found": terrain != null}
	var aabb := AABB()
	if terrain != null:
		var data = terrain.get("data")
		var mesh: ArrayMesh = terrain.mesh as ArrayMesh
		report["terrain_mesh"] = mesh != null
		report["mesh_path"] = mesh.resource_path if mesh else ""
		report["vertex_count"] = mesh.surface_get_array_len(0) if mesh and mesh.get_surface_count() > 0 else 0
		report["data_vertices"] = data.vertices.size() if data else 0
		report["vertex_match"] = report["vertex_count"] == report["data_vertices"] and report["vertex_count"] > 0
		report["material"] = terrain.material_override.resource_path if terrain.material_override else ""
		report["has_material"] = terrain.material_override != null
		if mesh != null:
			aabb = terrain.global_transform * mesh.get_aabb()
			report["aabb_position"] = _vec(aabb.position)
			report["aabb_size"] = _vec(aabb.size)
	else:
		report["terrain_mesh"] = false
	if root != null:
		for node_name in COUNTED:
			var holder := root.find_child(node_name, true, false)
			report[node_name.to_snake_case() + "_children"] = holder.get_child_count() if holder else -1
		# RFC-054 054d: the plants are no longer nodes; the Flora layer draws them around the viewport camera.
		var flora := root.find_child("Flora", true, false) as FloraField
		report["flora_instances"] = flora.instance_count() if flora else -1
	_frame_viewport(aabb)
	await _wait_frames(20)
	var image := EditorInterface.get_editor_viewport_3d(0).get_texture().get_image()
	var png := ProjectSettings.globalize_path(_out.path_join("editor_%s.png" % step))
	report["png_saved"] = image != null and image.save_png(png) == OK
	report["png_uniform"] = _is_uniform(image)
	var json := FileAccess.open(ProjectSettings.globalize_path(_out.path_join("editor_%s.json" % step)), FileAccess.WRITE)
	if json:
		json.store_string(JSON.stringify(report, "\t"))
	var line := "EDITOR_CAPTURE step=%s terrain_mesh=%s vertex_count=%s data_vertices=%s vertex_match=%s material=%s aabb_size=%s png_uniform=%s" % [
		step, str(report.get("terrain_mesh")).to_lower(), report.get("vertex_count", 0), report.get("data_vertices", 0),
		str(report.get("vertex_match", false)).to_lower(), str(report.get("has_material", false)).to_lower(),
		report.get("aabb_size", "none"), str(report["png_uniform"]).to_lower()]
	print(line)


## Best effort: put the editor's 3D camera above the terrain looking at its center. Without a mesh the camera stays.
func _frame_viewport(aabb: AABB) -> void:
	if aabb.size == Vector3.ZERO:
		return
	var camera := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	if camera == null:
		return
	var center := aabb.get_center()
	var span := maxf(aabb.size.x, aabb.size.z)
	camera.global_position = center + Vector3(0.0, span * 0.8, span * 0.6)
	camera.look_at(center)


func _vec(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]


## True when a sparse sample of the image has one single color (an empty viewport or a flat clear color).
func _is_uniform(image: Image) -> bool:
	if image == null or image.is_empty():
		return true
	var first := image.get_pixel(0, 0)
	for y in range(0, image.get_height(), 17):
		for x in range(0, image.get_width(), 17):
			if not image.get_pixel(x, y).is_equal_approx(first):
				return false
	return true
