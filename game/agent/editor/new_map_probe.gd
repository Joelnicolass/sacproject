@tool
extends Node

## Plan 066b editor probe: an autoload that exists only while agent/scripts/new_map_probe.sh runs (a temporary
## override.cfg). Inside the editor (a window) it runs «Mapa nuevo» the way the menu does (NewMapAction): first three tags
## it must refuse without writing anything, then `probe_new_map`, timed. It measures what plan 066 §8 066b asks (the files,
## the pictures, no "_template" and no template uid in the copy, the catalog, the navmesh, «Validar mapa», the instances in
## map.tscn, each WizardSpot 30 m from its altar toward the nearest fount, the template untouched), prints NEW_MAP_PROBE
## lines (also to agent/out/066b/probe.txt), deletes the folder and quits. Not the plugin's menu item itself.

const NewMapAction := preload("res://addons/terrain_tools/new_map/new_map_action.gd")
const NewMapFiles := preload("res://addons/terrain_tools/new_map/new_map_files.gd")
const TerrainHistory := preload("res://addons/terrain_tools/terrain_history.gd")
const TerrainActions := preload("res://addons/terrain_tools/terrain_actions.gd")
const Png16 := preload("res://addons/terrain_tools/png16.gd")
const TAG := &"probe_new_map"
const OUT := "res://agent/out/066b"


func _ready() -> void:
	if Engine.is_editor_hint():
		_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT.path_join("probe.txt")))
	_say("start")
	await _frames(30)
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	var folder := NewMapFiles.folder_of(String(TAG))
	if DirAccess.dir_exists_absolute(folder):
		_say("FAIL %s exists from an earlier run: delete it first" % folder)
		get_tree().quit()
		return
	var template_before := _template_sums()
	var action := NewMapAction.new(TerrainActions.new(TerrainHistory.new(EditorInterface.get_editor_undo_redo())))
	var maps_before := DirAccess.get_directories_at(NewMapFiles.MAPS_DIR).size()
	for tag: String in ["test_flat", "Mi-Mapa", "_x"]:
		await action.make(StringName(tag), "Rechazado")
		_say("refused «%s»: %s, nothing written %s" % [tag, _newest_dialog(),
				DirAccess.get_directories_at(NewMapFiles.MAPS_DIR).size() == maps_before])
	var started := Time.get_ticks_msec()
	await action.make(TAG, "Probe new map")
	_say("made in %.1f s (want <= 60)" % ((Time.get_ticks_msec() - started) / 1000.0))
	_say("validate dialog: %s" % _newest_dialog())
	_files(folder)
	_scene(folder)
	_say("template untouched %s" % (_template_sums() == template_before))
	await _remove(folder)
	_say("DONE")
	get_tree().quit()


func _files(folder: String) -> void:
	for file: String in ["map.tscn", "heights.png", "ground_roles.png", "nav.res", "%s.tres" % TAG]:
		_say("file %s %s" % [file, FileAccess.file_exists(folder.path_join(file))])
	_say("no void.png %s" % (not FileAccess.file_exists(folder.path_join("void.png"))))
	var heights := Png16.read_file(folder.path_join("heights.png"))
	var flat := heights.samples.size() == 65536 and heights.width == 256
	for sample in heights.samples:
		flat = flat and sample == 100
	_say("heights 256² all 100 %s" % flat)
	var roles := Image.load_from_file(ProjectSettings.globalize_path(folder.path_join("ground_roles.png")))
	roles.convert(Image.FORMAT_RGBA8)
	var bytes := roles.get_data()
	var grass := roles.get_width() == 256 and roles.get_height() == 256
	for i in range(0, bytes.size(), 4):
		grass = grass and bytes[i] == 255 and bytes[i + 1] == 0 and bytes[i + 2] == 0 and bytes[i + 3] == 0
	_say("roles 256² all (255,0,0,0) %s" % grass)
	var mentions := 0
	for file in DirAccess.get_files_at(folder):
		mentions += int(FileAccess.get_file_as_string(folder.path_join(file)).contains("_template")) if not file.ends_with(".png") else 0
	_say("files naming _template: %d (want 0)" % mentions)
	for file in NewMapFiles.PICTURES:
		var mine := _uid_line(folder.path_join(file) + ".import")
		var theirs := _uid_line(NewMapFiles.TEMPLATE_DIR.path_join(file) + ".import")
		_say("%s uid own %s (%s)" % [file, not mine.is_empty() and mine != theirs, mine])
	var catalog := MapCatalog.shared()
	_say("catalog has %s, lists _template %s" % [catalog.has(TAG), catalog.all_tags().has("_template")])
	var nav := ResourceLoader.load(folder.path_join("nav.res"), "", ResourceLoader.CACHE_MODE_IGNORE) as NavigationMesh
	_say("navmesh polygons %d (want > 0)" % (nav.get_polygon_count() if nav != null else -1))


func _scene(folder: String) -> void:
	var text := FileAccess.get_file_as_string(folder.path_join("map.tscn"))
	for scene: String in ["terrain.tscn", "player_start.tscn", "manafount.tscn"]:
		var id := ""
		for line in text.split("\n"):
			if line.begins_with("[ext_resource") and line.contains("/" + scene + "\""):
				id = line.get_slice("id=\"", 1).get_slice("\"", 0)
		_say("instances of %s: %d" % [scene, text.count("instance=ExtResource(\"%s\")" % id) if not id.is_empty() else 0])
	var root := EditorInterface.get_edited_scene_root() as MapRoot
	if root == null:
		_say("FAIL no map open")
		return
	var founts: Array[Vector3] = []
	for fount in root.find_child("Founts", true, false).get_children():
		founts.append((fount as Node3D).global_position)
	for start: PlayerStart in root.starts.get_children():
		var spot := start.spawn_transform()
		var altar := (start.find_child("Altar", false, false) as Node3D).global_position
		var nearest := founts[0]
		for fount in founts:
			if fount.distance_to(spot.origin) < nearest.distance_to(spot.origin):
				nearest = fount
		var toward := ((nearest - spot.origin) * Vector3(1, 0, 1)).normalized()
		_say("%s spot %.2f m from altar (want 30 ± 0.1), turned to nearest fount %.3f (want > 0.99)" % [
				start.name, spot.origin.distance_to(altar), spot.basis.z.normalized().dot(toward)])


func _template_sums() -> PackedStringArray:
	var sums := PackedStringArray()
	for file in DirAccess.get_files_at(NewMapFiles.TEMPLATE_DIR):
		sums.append("%s %s" % [file, FileAccess.get_md5(NewMapFiles.TEMPLATE_DIR.path_join(file))])
	return sums


func _uid_line(path: String) -> String:
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("uid="):
			return line
	return ""


func _remove(folder: String) -> void:
	EditorInterface.close_scene()
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	EditorInterface.get_resource_filesystem().scan()
	await _frames(30)
	_say("removed %s %s" % [folder, not DirAccess.dir_exists_absolute(folder)])


func _newest_dialog() -> String:
	var dialogs := EditorInterface.get_base_control().find_children("*", "AcceptDialog", false, false)
	var newest := dialogs.back() as AcceptDialog if not dialogs.is_empty() else null
	return "«%s» %s" % [newest.title, newest.dialog_text.replace("\n", " | ")] if newest != null else "no dialog"


func _frames(count: int) -> void:
	for k in count:
		await get_tree().process_frame


## Printed and appended to OUT/probe.txt at once (a killed editor loses what it buffered for stdout).
func _say(line: String) -> void:
	print("NEW_MAP_PROBE " + line)
	var path := ProjectSettings.globalize_path(OUT.path_join("probe.txt"))
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	file.seek_end()
	file.store_line(line)
	file.close()
