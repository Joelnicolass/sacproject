@tool
extends Node

## Playtest review (RFC-066): an autoload that exists only while agent/harness/pt_review/map_editor_probe.sh runs (a temporary
## override.cfg). Inside the editor (a window) it opens «Mapa nuevo…» (NewMapAction.open, the menu item's callable), types a
## refused tag and then TAG in the dialog's fields and presses its OK button; waits for the map to be made, baked and
## validated; then paints on it with the terrain tools' own pieces (TerrainHistory, the brush toolbar, BrushPainter) fed with
## mouse events under a framed editor camera, as terrain_brush_probe.gd does: roles (rock, path, earth), then a FloraLayer
## added under Vegetation (two clicks: the first makes its density picture) painted and partly erased with Shift. Saves
## (the canvases and the scene), checks the written pictures, runs «Validar mapa», captures PNGs to OUT and quits.
## The map stays in scenes/map/maps/TAG for the game run; the caller deletes it.

const NewMapAction := preload("res://addons/terrain_tools/new_map/new_map_action.gd")
const NewMapFiles := preload("res://addons/terrain_tools/new_map/new_map_files.gd")
const TerrainHistory := preload("res://addons/terrain_tools/terrain_history.gd")
const TerrainActions := preload("res://addons/terrain_tools/terrain_actions.gd")
const BrushPainter := preload("res://addons/terrain_tools/brush/brush_painter.gd")
const ToolbarScene := preload("res://addons/terrain_tools/brush/brush_toolbar.tscn")
const Toolbar := preload("res://addons/terrain_tools/brush/brush_toolbar.gd")
const TAG := "pt_review_map"
const FERN := "res://data/vegetation/species/persephone_fern_1.tres"
const OUT := "res://agent/out/pt_review/editor"
const CENTER := Vector2(1240, 1300)

var _history: TerrainHistory
var _painter: BrushPainter
var _toolbar: Node
var _camera: Camera3D
var _framing := Transform3D()


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
	_say("plugin terrain_tools enabled %s" % EditorInterface.is_plugin_enabled("terrain_tools"))
	var folder := NewMapFiles.folder_of(TAG)
	if DirAccess.dir_exists_absolute(folder):
		_say("FAIL %s exists from an earlier run" % folder)
		get_tree().quit()
		return
	_history = TerrainHistory.new(EditorInterface.get_editor_undo_redo())
	var action := NewMapAction.new(TerrainActions.new(_history))
	if not await _dialog(action):
		_say("FAIL dialog")
		get_tree().quit()
		return
	var started := Time.get_ticks_msec()
	await _frames(5)
	var scene := folder.path_join(NewMapFiles.SCENE_FILE)
	while Time.get_ticks_msec() - started < 180000:
		var root := EditorInterface.get_edited_scene_root()
		if not bool(action.get("_busy")) and root != null and root.scene_file_path == scene:
			break
		await get_tree().process_frame
	await _frames(30)
	_say("made in %.1f s, open %s" % [(Time.get_ticks_msec() - started) / 1000.0, _edited() == scene])
	_say("validate dialog after making: %s" % _newest_dialog())
	for file: String in ["map.tscn", "heights.png", "ground_roles.png", "nav.res", "%s.tres" % TAG]:
		_say("file %s %s" % [file, FileAccess.file_exists(folder.path_join(file))])
	_say("catalog has %s" % MapCatalog.shared().has(StringName(TAG)))
	var map := EditorInterface.get_edited_scene_root() as MapRoot
	if map == null:
		_say("FAIL no MapRoot open")
		get_tree().quit()
		return
	EditorInterface.set_main_screen_editor("3D")
	await _paint_roles(map)
	await _paint_flora(map, folder)
	var errors := _history.save()
	EditorInterface.save_scene()
	EditorInterface.get_resource_filesystem().scan()
	await _frames(60)
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	_say("save errors '%s'" % errors)
	_check_roles(folder)
	_check_density(folder)
	await TerrainActions.new(_history).validate(map.terrain)
	_say("validate dialog after painting: %s" % _newest_dialog())
	await _aim(map.terrain, CENTER, Vector3(0, 160, 120))
	await _frames(60)
	await _capture("saved")
	_say("DONE")
	get_tree().quit()


## «Mapa nuevo…»: the dialog as the menu opens it; a refused tag, then TAG and a name typed; OK pressed.
func _dialog(action: NewMapAction) -> bool:
	action.open()
	await _frames(10)
	var dialog: ConfirmationDialog = null
	for each in EditorInterface.get_base_control().find_children("*", "ConfirmationDialog", false, false):
		if each.get_script() != null and (each.get_script() as Script).resource_path.ends_with("new_map_dialog.gd"):
			dialog = each
	if dialog == null:
		return false
	var tag := dialog.find_child("Tag", true, false) as LineEdit
	var display := dialog.find_child("DisplayName", true, false) as LineEdit
	var reason := dialog.find_child("Reason", true, false) as Label
	_say("dialog open «%s», OK disabled empty %s, reason «%s»" % [dialog.title, dialog.get_ok_button().disabled, reason.text])
	_type(tag, "Mi-Mapa")
	_type(display, "Mapa de prueba")
	await _frames(2)
	_say("tag «Mi-Mapa»: OK disabled %s, reason «%s»" % [dialog.get_ok_button().disabled, reason.text])
	_type(tag, TAG)
	await _frames(5)
	_say("tag «%s»: OK disabled %s, reason «%s»" % [TAG, dialog.get_ok_button().disabled, reason.text])
	var shot := dialog.get_texture().get_image() if dialog.get_texture() != null else null
	if shot != null:
		shot.save_png(ProjectSettings.globalize_path(OUT.path_join("dialog.png")))
	if dialog.get_ok_button().disabled:
		return false
	dialog.get_ok_button().pressed.emit()
	return true


func _type(field: LineEdit, text: String) -> void:
	field.clear()
	field.insert_text_at_caret(text)
	field.text_changed.emit(field.text)


func _paint_roles(map: MapRoot) -> void:
	var terrain := map.terrain
	_toolbar = ToolbarScene.instantiate()
	EditorInterface.get_base_control().add_child(_toolbar)
	_toolbar.visible = false
	_toolbar.show_for(Toolbar.Kind.TERRAIN)
	_toolbar.brush = (_toolbar.brush as TerrainBrush).duplicate()  # sizes below change this session's copy only
	_painter = BrushPainter.new(_history, _toolbar)
	_painter.edit(terrain)
	var waited := 0
	while _history.budget.cost_ms(terrain) < 0.0 and waited < 600:
		await get_tree().process_frame
		waited += 1
	await _aim(terrain, CENTER, Vector3(0, 160, 120))
	await _frames(30)
	await _capture("new_map")
	_toolbar.brush.size_m = 20.0
	_toolbar.tool = Toolbar.Tool.ROLE_ROCK
	await _line(terrain, Vector2(1240, 1255), Vector2(1260, 1255), 4, false)
	_toolbar.tool = Toolbar.Tool.ROLE_PATH
	await _line(terrain, Vector2(1195, 1300), Vector2(1295, 1300), 12, false)
	_toolbar.tool = Toolbar.Tool.ROLE_EARTH
	await _line(terrain, Vector2(1240, 1345), Vector2(1265, 1350), 4, false)
	await _aim(terrain, CENTER, Vector3(0, 160, 120))
	await _frames(10)
	await _capture("roles")
	_say("roles strokes done, unsaved %s" % _history.has_unsaved())


func _paint_flora(map: MapRoot, folder: String) -> void:
	var vegetation := map.get_node("Vegetation")
	var layer := FloraLayer.new()
	layer.name = "Ferns"
	layer.species = load(FERN) as VegetationSpecies
	vegetation.add_child(layer)
	layer.owner = map
	EditorInterface.save_scene()
	await _frames(10)
	_painter.edit(layer)
	_toolbar.show_for(Toolbar.Kind.FLORA)
	_toolbar.tool = Toolbar.Tool.FLORA
	_toolbar.brush.size_m = 30.0
	var terrain := map.terrain
	await _line(terrain, Vector2(1215, 1230), Vector2(1270, 1230), 6, false)  # first click: makes the picture
	EditorInterface.get_resource_filesystem().scan()
	await _frames(30)
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	await _frames(30)
	_say("density picture made %s (%s)" % [layer.density != null or FileAccess.file_exists(folder.path_join("flora/ferns.png")),
			folder.path_join("flora/ferns.png")])
	for k in 3:
		await _line(terrain, Vector2(1200, 1225 + k * 8), Vector2(1280, 1225 + k * 8), 10, false)
	_say("density assigned %s" % (layer.density != null))
	await _aim(terrain, Vector2(1240, 1240), Vector3(0, 90, 70))
	await _frames(30)
	await _capture("flora_painted")
	await _line(terrain, Vector2(1240, 1215), Vector2(1240, 1245), 4, true)  # Shift: erase a band
	await _frames(30)
	await _aim(terrain, Vector2(1240, 1240), Vector3(0, 90, 70))
	await _frames(10)
	await _capture("flora_erased")


func _check_roles(folder: String) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(folder.path_join("ground_roles.png")))
	image.convert(Image.FORMAT_RGBA8)
	var counts := [0, 0, 0, 0]
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.g > 0.5:
				counts[1] += 1
			if c.b > 0.5:
				counts[2] += 1
			if c.a > 0.5:
				counts[3] += 1
			if c.r < 0.5:
				counts[0] += 1
	_say("ground_roles.png %dx%d: pixels not grass %d, earth %d, rock %d, path %d" % [image.get_width(), image.get_height(),
			counts[0], counts[1], counts[2], counts[3]])


func _check_density(folder: String) -> void:
	var path := folder.path_join("flora/ferns.png")
	if not FileAccess.file_exists(path):
		_say("density ferns.png missing")
		return
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	image.convert(Image.FORMAT_L8)
	var painted := 0
	for byte in image.get_data():
		painted += int(byte > 0)
	_say("density ferns.png %dx%d: painted cells %d" % [image.get_width(), image.get_height(), painted])


func _line(terrain: Terrain, from: Vector2, to: Vector2, moves: int, shift: bool) -> void:
	var start := await _aim(terrain, (from + to) * 0.5, Vector3(0, 160, 120), from)
	var end := _camera.unproject_position(terrain.to_global(Vector3(to.x, terrain.height_at(to.x, to.y), to.y)))
	var step := (end - start) / maxf(1.0, moves)
	_send(_button(start, true, shift))
	var mouse := start
	for k in moves:
		var motion := InputEventMouseMotion.new()
		mouse += step
		motion.position = mouse
		motion.relative = step
		motion.shift_pressed = shift
		_send(motion)
		await get_tree().process_frame
	_send(_button(mouse, false, shift))
	await _frames(3)


## Frames the editor camera at `offset` from the ground point `look` and returns the screen point of `point` (default `look`).
func _aim(terrain: Terrain, look: Vector2, offset: Vector3, point: Variant = null) -> Vector2:
	_camera = EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	var ground := terrain.to_global(Vector3(look.x, terrain.height_at(look.x, look.y), look.y))
	_camera.global_position = ground + offset
	_camera.look_at(ground)
	_framing = _camera.global_transform
	await get_tree().process_frame
	_camera.global_transform = _framing
	var at: Vector2 = point if point != null else look
	return _camera.unproject_position(terrain.to_global(Vector3(at.x, terrain.height_at(at.x, at.y), at.y)))


func _button(at: Vector2, pressed: bool, shift: bool) -> InputEventMouseButton:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.position = at
	button.shift_pressed = shift
	return button


func _send(event: InputEvent) -> void:
	_camera.global_transform = _framing
	_painter.input(_camera, event)


func _capture(name: String) -> void:
	await _frames(3)
	_camera.global_transform = _framing
	await RenderingServer.frame_post_draw
	var image := EditorInterface.get_editor_viewport_3d(0).get_texture().get_image()
	if image != null:
		image.save_png(ProjectSettings.globalize_path(OUT.path_join("%s.png" % name)))
		_say("shot %s.png" % name)


func _edited() -> String:
	var root := EditorInterface.get_edited_scene_root()
	return root.scene_file_path if root != null else ""


func _newest_dialog() -> String:
	var dialogs := EditorInterface.get_base_control().find_children("*", "AcceptDialog", false, false)
	var newest := dialogs.back() as AcceptDialog if not dialogs.is_empty() else null
	return "«%s» %s" % [newest.title, newest.dialog_text.replace("\n", " | ")] if newest != null else "no dialog"


func _frames(count: int) -> void:
	for k in count:
		await get_tree().process_frame


func _say(line: String) -> void:
	print("PT_MAP_PROBE " + line)
	var path := ProjectSettings.globalize_path(OUT.path_join("probe.txt"))
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	file.seek_end()
	file.store_line(line)
	file.close()
