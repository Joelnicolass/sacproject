@tool
extends Node

## Plan 063D S5b editor probe: an autoload that exists only while agent/scripts/terrain_brush_probe.sh runs (a temporary
## override.cfg). Inside the editor (a window) it drives the terrain tools' own pieces the way the plugin wires them
## (TerrainHistory, BrushPainter, the toolbar, TerrainActions) on debug/terrain/edit_bed.tscn: a raise stroke with mouse
## events under a camera framed above the island, undo and redo, flatten, void and fill, «Aplanar bases», «Validar mapa» and a
## save (the bed's pictures are put back after). Then a stroke on winter_wonder, whose rebuild is heavy: it must stay a draft.
## It prints TERRAIN_PROBE lines (the refresh times: how long after the release the mesh was rebuilt and the longest editor
## frame meanwhile), writes agent/out/063d/probe_*.png and quits. Not the plugin itself (that one is wired in plugin.gd).

const TerrainHistory := preload("res://addons/terrain_tools/terrain_history.gd")
const TerrainActions := preload("res://addons/terrain_tools/terrain_actions.gd")
const BrushPainter := preload("res://addons/terrain_tools/brush/brush_painter.gd")
const ToolbarScene := preload("res://addons/terrain_tools/brush/brush_toolbar.tscn")
const Toolbar := preload("res://addons/terrain_tools/brush/brush_toolbar.gd")
const MapImages := preload("res://addons/terrain_tools/map_images.gd")
const BED := "res://debug/terrain/edit_bed.tscn"
const BED_DIR := "res://debug/terrain/edit_bed"
const HEAVY := "res://scenes/map/maps/winter_wonder/map.tscn"
const OUT := "res://agent/out/063d"

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
	_say("scanned")
	_history = TerrainHistory.new(EditorInterface.get_editor_undo_redo())
	_toolbar = ToolbarScene.instantiate()
	EditorInterface.get_base_control().add_child(_toolbar)
	_toolbar.visible = false
	_painter = BrushPainter.new(_history, _toolbar)
	var terrain := await _open(BED)
	var at := await _aim(terrain, Vector2(1280, 1280))
	var before := terrain.heights.checksum()
	_toolbar.tool = Toolbar.Tool.RAISE
	await _stroke(at, Vector2(0, -10), 10, false, "bed_raise")
	var raised := _history.arrays(terrain)[0] as PackedFloat32Array
	_say("raise centre %.2f m (want 60.00)" % raised[TerrainGrid.vertex_id(1280, 1280)])
	await _refresh(terrain, "bed raise")
	await _capture("bed_rebuilt")
	var after := terrain.heights.checksum()
	var undo := EditorInterface.get_editor_undo_redo()
	var steps := undo.get_history_undo_redo(undo.get_object_history_id(terrain))
	steps.undo()
	_say("undo exact %s" % (terrain.heights.checksum() == before))
	steps.redo()
	_say("redo exact %s" % (terrain.heights.checksum() == after))
	_toolbar.tool = Toolbar.Tool.SMOOTH
	await _stroke(await _aim(terrain, Vector2(1300, 1280)), Vector2(4, 0), 5, true, "bed_flatten")
	_toolbar.tool = Toolbar.Tool.VOID
	await _stroke(await _aim(terrain, Vector2(1450, 1450)), Vector2.ZERO, 1, false, "bed_void")
	var id := TerrainGrid.vertex_id(1450, 1450)
	_say("void painted %s" % ((_history.arrays(terrain)[1] as PackedByteArray)[id] == 1))
	await _refresh(terrain, "bed void")
	await _capture("bed_void")
	await _stroke(await _aim(terrain, Vector2(1450, 1450)), Vector2.ZERO, 1, true, "bed_fill")
	_say("void filled %s" % ((_history.arrays(terrain)[1] as PackedByteArray)[id] == 0))
	var actions := TerrainActions.new(_history)
	actions.level_bases(terrain)
	_say_dialog()
	await actions.validate(terrain)
	_say_dialog()
	await _save_and_restore(terrain)
	var heavy := await _open(HEAVY)
	var land := _land_near(heavy)
	at = await _aim(heavy, land)
	_toolbar.tool = Toolbar.Tool.RAISE
	var resource_before := heavy.heights.checksum()
	await _stroke(at, Vector2(0, -10), 5, false, "heavy_raise")
	_say("heavy draft %s, resource untouched %s" % [_history.has_draft(heavy), heavy.heights.checksum() == resource_before])
	await _refresh(heavy, "heavy release (draft)", 1500)
	_painter.rebuild()
	await _refresh(heavy, "heavy «Rearmar»")
	_say("DONE")
	get_tree().quit()


func _open(scene: String) -> Terrain:
	EditorInterface.open_scene_from_path(scene)
	await _frames(60)
	var root := EditorInterface.get_edited_scene_root() as MapRoot
	var terrain := root.terrain
	_painter.edit(terrain)
	var waited := 0
	while _history.budget.cost_ms(terrain) < 0.0 and waited < 600:
		await get_tree().process_frame
		waited += 1
	_say("%s: rebuild measured %.0f ms, light %s" % [scene.get_file(), _history.budget.cost_ms(terrain), _history.budget.is_light(terrain)])
	return terrain


## Frames the editor camera straight above the ground point `point` (Terrain frame) and returns the screen point under it.
func _aim(terrain: Terrain, point: Vector2) -> Vector2:
	_camera = EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	var ground := terrain.to_global(Vector3(point.x, terrain.height_at(point.x, point.y), point.y))
	_camera.global_position = ground + Vector3(0.0, 500.0, 200.0)
	_camera.look_at(ground)
	_framing = _camera.global_transform
	await get_tree().process_frame
	_camera.global_transform = _framing
	return _camera.unproject_position(ground)


func _stroke(at: Vector2, step: Vector2, moves: int, shift: bool, name: String) -> void:
	_send(_button(at, true, shift))
	var mouse := at
	for k in moves:
		var motion := InputEventMouseMotion.new()
		mouse += step
		motion.position = mouse
		motion.relative = step
		motion.shift_pressed = shift
		_send(motion)
		await get_tree().process_frame
	await _capture(name)
	_send(_button(mouse, false, shift))


func _button(at: Vector2, pressed: bool, shift: bool) -> InputEventMouseButton:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.position = at
	button.shift_pressed = shift
	return button


func _send(event: InputEvent) -> void:
	_camera.global_transform = _framing  # the editor moves its camera back between frames
	_painter.input(_camera, event)


## Waits for the ground to be built again (or `limit_ms`), timing the longest editor frame meanwhile.
func _refresh(terrain: Terrain, what: String, limit_ms := 4000) -> void:
	var built := [false]
	var on_derived := func() -> void: built[0] = true
	terrain.derived.connect(on_derived)
	var started := Time.get_ticks_msec()
	var last := Time.get_ticks_usec()
	var longest := 0.0
	while not built[0] and Time.get_ticks_msec() - started < limit_ms:
		await get_tree().process_frame
		longest = maxf(longest, (Time.get_ticks_usec() - last) / 1000.0)
		last = Time.get_ticks_usec()
	terrain.derived.disconnect(on_derived)
	_say("refresh %s: rebuilt %s after %d ms, longest editor frame %.0f ms" % [what, built[0], Time.get_ticks_msec() - started, longest])


func _save_and_restore(terrain: Terrain) -> void:
	var files := [BED_DIR.path_join(MapImages.HEIGHTS_FILE), BED_DIR.path_join(MapImages.VOID_FILE)]
	var kept := files.map(func(path: String) -> PackedByteArray: return FileAccess.get_file_as_bytes(path))
	var errors := _history.save()
	await _frames(30)
	_say("save errors '%s', heights.png changed %s, heights still valid %s" % [errors,
			FileAccess.get_file_as_bytes(files[0]) != kept[0], terrain.heights != null and terrain.heights.is_valid()])
	for k in files.size():
		var file := FileAccess.open(files[k], FileAccess.WRITE)
		file.store_buffer(kept[k])
		file.close()
	TerrainHistory.reimport(BED_DIR)
	await _frames(30)


func _land_near(terrain: Terrain) -> Vector2:
	for radius in range(0, 1200, 20):
		for angle in 16:
			var point := Vector2(1280, 1280) + Vector2.from_angle(TAU * angle / 16.0) * radius
			if terrain.is_on_ground(point.x, point.y):
				return point
	return Vector2(1280, 1280)


func _capture(name: String) -> void:
	await _frames(3)
	var image := EditorInterface.get_editor_viewport_3d(0).get_texture().get_image()
	if image != null:
		image.save_png(ProjectSettings.globalize_path(OUT.path_join("probe_%s.png" % name)))


## The title and text of the newest dialog the terrain tools opened.
func _say_dialog() -> void:
	var dialogs := EditorInterface.get_base_control().find_children("*", "AcceptDialog", false, false)
	var newest := dialogs.back() as AcceptDialog if not dialogs.is_empty() else null
	_say("dialog «%s»: %s" % [newest.title, newest.dialog_text.replace("\n", " | ")] if newest != null else "no dialog")


func _frames(count: int) -> void:
	for k in count:
		await get_tree().process_frame


## Printed and appended to OUT/probe.txt at once (a killed editor loses what it buffered for stdout).
func _say(line: String) -> void:
	print("TERRAIN_PROBE " + line)
	var path := ProjectSettings.globalize_path(OUT.path_join("probe.txt"))
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	file.seek_end()
	file.store_line(line)
	file.close()
