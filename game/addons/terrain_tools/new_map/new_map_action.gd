@tool
extends RefCounted

## «Mapa nuevo…» in the editor: asks the tag and the name, writes the map's files from the template (NewMapFiles), imports
## its pictures, opens its scene, bakes its navmesh and checks it as «Validar mapa» does (that dialog says PASS or the
## problems). A step that fails says which and where in a dialog and in the Output. Not: what the files hold (NewMapFiles),
## the checks (MapChecks through TerrainActions), the bake itself (MapNavRegion.bake_now).

const NewMapFiles := preload("res://addons/terrain_tools/new_map/new_map_files.gd")
const DialogScene := preload("res://addons/terrain_tools/new_map/new_map_dialog.tscn")
const TerrainActions := preload("res://addons/terrain_tools/terrain_actions.gd")
const EditorDialogs := preload("res://addons/terrain_tools/editor_dialogs.gd")
const TITLE := "Mapa nuevo"
## How long the editor may take to see the new files before giving up.
const SCAN_LIMIT_MS := 10000

var _actions: TerrainActions
var _busy := false


func _init(actions: TerrainActions) -> void:
	_actions = actions


## Shows the dialog; accepting it makes the map.
func open() -> void:
	if _busy:
		EditorDialogs.say(TITLE, "Ya se está creando un mapa.")
		return
	var dialog := DialogScene.instantiate()
	dialog.chosen.connect(make)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()


## Makes the map `tag` named `display_name`, opens it, bakes it and checks it.
func make(tag: StringName, display_name: String) -> void:
	var refused := NewMapFiles.refusal(String(tag), display_name)
	if not refused.is_empty():
		EditorDialogs.say(TITLE + ": rechazado", refused)
		return
	_busy = true
	var started := Time.get_ticks_msec()
	var folder := NewMapFiles.folder_of(String(tag))
	var error: String = await _write(folder, tag, display_name)
	if error.is_empty():
		error = await _open_and_bake(folder)
	_busy = false
	if not error.is_empty():
		EditorDialogs.say(TITLE + ": falló", "%s\nLo que se alcanzó a escribir quedó en %s." % [error, folder])
		return
	print("%s: %s en %.1f s" % [TITLE, folder, (Time.get_ticks_msec() - started) / 1000.0])
	var root := EditorInterface.get_edited_scene_root() as MapRoot
	await _actions.validate(root.terrain)


func _write(folder: String, tag: StringName, display_name: String) -> String:
	var pictures := NewMapFiles.write_pictures(folder)
	if pictures.is_empty():
		return "No se pudieron copiar las imágenes de %s (ver Salida)." % NewMapFiles.TEMPLATE_DIR
	var error := NewMapFiles.write_nav(folder)
	if not error.is_empty():
		return error
	if not await _import(folder):
		return "El editor no importó las imágenes de %s en %d s." % [folder, SCAN_LIMIT_MS / 1000]
	error = NewMapFiles.write_scene(folder)
	if error.is_empty():
		error = NewMapFiles.write_definition(folder, tag, display_name)
	if error.is_empty():
		await _scan()
	return error


## The editor finds the new folder and imports its pictures; true once they load.
func _import(folder: String) -> bool:
	await _scan()
	var sources := PackedStringArray()
	for file in NewMapFiles.PICTURES:
		sources.append(folder.path_join(file))
	EditorInterface.get_resource_filesystem().reimport_files(sources)
	for path in sources:
		if not ResourceLoader.exists(path):
			return false
	return true


## WORKAROUND: EditorFileSystem.update_file is not known to work in a folder the editor has never seen, so the whole
## project is scanned (a second or two) and the action waits for the scan, up to SCAN_LIMIT_MS.
func _scan() -> void:
	var files := EditorInterface.get_resource_filesystem()
	var tree := EditorInterface.get_base_control().get_tree()
	files.scan()
	await tree.process_frame
	var deadline := Time.get_ticks_msec() + SCAN_LIMIT_MS
	while files.is_scanning() and Time.get_ticks_msec() < deadline:
		await tree.process_frame


func _open_and_bake(folder: String) -> String:
	var scene := folder.path_join(NewMapFiles.SCENE_FILE)
	EditorInterface.open_scene_from_path(scene)
	await EditorInterface.get_base_control().get_tree().process_frame
	var root := EditorInterface.get_edited_scene_root() as MapRoot
	if root == null or root.scene_file_path != scene:
		return "No se pudo abrir %s." % scene
	var region := root.nav_region as MapNavRegion
	if region == null:
		return "%s no tiene un NavRegion (MapNavRegion)." % scene
	if region.bake_now() != OK:
		return "No se pudo hornear el navmesh de %s (ver Salida)." % scene
	return ""
