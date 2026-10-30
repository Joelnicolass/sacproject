@tool
extends Node

## Editor only: GrassKit's tools in the 3D view while a GrassField3D is selected.
##
## On top of the view: the «GrassKit» menu (bake the ground, fit the area to the colliders, fill,
## clear, import or export the brush's map) and four brushes. They paint the ground's maps, the same
## textures the field draws from: «Grass» where it grows, «Height» how tall, «Colour» the ground's
## colour under it, «Kind» where a kind of blade grows (flowers). Under the view: the brush's size,
## strength, falloff and noise, and what the brush paints. Each stroke is one step of the editor's
## history, the grass follows the brush so what is painted shows wherever it is, and the maps are
## saved inside the ground when the scene is saved.
##
## Over the view (the keys Terrain3D uses): left button paints, Ctrl (Cmd) + left button erases,
## Shift + left button smooths, [ and ] change the size, - and = the strength, Esc puts the brush
## down. A tablet pen's pressure scales the strength.

enum Tool { NONE, GRASS, HEIGHT, COLOUR, KIND }

const TOOL_NAMES := ["", "Grass", "Height", "Colour", "Kind"]
const TOOL_TIPS := [
	"",
	"Paint where grass grows (Ctrl: none, Shift: smooth the edge).",
	"Paint how tall the grass grows: the Height value, against the look's (Ctrl: back to the look's).",
	"Paint the ground's colour under the grass (Ctrl: back to the look's ground colour).",
	"Paint where a kind of blade grows, by its map name (Ctrl: not here).",
]
const SHORTCUTS := (
	"Left button: paint · Ctrl (Cmd): erase · Shift: smooth · [ ]: size · - =: strength · "
	+ "Esc: put the brush down"
)
enum Item { BAKE, FIT, SET_UP, BAKE_COLOUR, FILL = 10, CLEAR, IMPORT, EXPORT, SHOW_MAP = 20, HELP }

const OVERLAY_SHADER := preload("grass_map_overlay.gdshader")
const CIRCLE := 64

var field: GrassField3D
var tool := Tool.NONE
var brush := GrassBrush.new()
## The «Height» brush paints this, against the look's height (0.5 = half as tall).
var height := 0.5
var colour := Color(0.36, 0.3, 0.16)
var kind_index := 0
var show_map := true

var _top: HBoxContainer
var _bottom: HBoxContainer
var _menu: MenuButton
var _tools: Array[Button] = []
var _size: EditorSpinSlider
var _strength: EditorSpinSlider
var _falloff: EditorSpinSlider
var _noise: EditorSpinSlider
var _erase: CheckBox
var _height: EditorSpinSlider
var _colour: ColorPickerButton
var _kinds: OptionButton
var _show: CheckBox
var _status: Label
var _file_dialog: EditorFileDialog

var _cursor_mesh := ImmediateMesh.new()
var _cursor_material := StandardMaterial3D.new()
var _cursor := RID()
var _overlay_mesh := ArrayMesh.new()
var _overlay_material := ShaderMaterial.new()
var _overlay := RID()
var _overlay_queued := false
var _blank_maps: Dictionary[StringName, Texture2D] = {}

## The stroke being painted.
var _painting := false
var _map: StringName
var _old_texture: Texture2D
var _new_texture: Texture2D
var _before: Image
var _dirty := Rect2i()
var _last := Vector2.INF
var _rename: Array = []
var _status_timer := 0.0


func _init() -> void:
	_cursor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cursor_material.no_depth_test = true
	_cursor_material.render_priority = 1
	_overlay_material.shader = OVERLAY_SHADER


func _exit_tree() -> void:
	_set_focus(Vector2.INF)
	for rid in [_cursor, _overlay]:
		if rid.is_valid():
			RenderingServer.free_rid(rid)
	_cursor = RID()
	_overlay = RID()


## The top bar and the bottom bar, for the plugin to place in the 3D view (built on the first call).
func bars() -> Array[Control]:
	if _top == null:
		_load_settings()
		_build()
		set_visible(false)
	return [_top, _bottom]


## Starts editing `node` (null = none).
func edit(node: GrassField3D) -> void:
	if _painting:
		_end_stroke()
	if field != null and field.ground != null:
		_watch_ground(field.ground, false)
	_set_focus(Vector2.INF)
	field = node
	if field != null and field.ground != null:
		_watch_ground(field.ground, true)
	_refresh_kinds()
	_queue_overlay()
	_update_ui()


func set_visible(visible: bool) -> void:
	if _top == null:
		return
	_top.visible = visible
	_bottom.visible = visible
	if not visible:
		_set_tool(Tool.NONE)


## The 3D view's input while a field is selected: EditorPlugin.AFTER_GUI_INPUT_STOP when a brush
## took it.
func input(camera: Camera3D, event: InputEvent) -> int:
	if field == null or _top == null or not _top.visible:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventKey:
		return _key(event as InputEventKey)
	if tool == Tool.NONE:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var hit: Variant = _aim(camera, motion.position)
		_show_cursor(hit, _mode_of(motion))
		if hit != null:
			_set_focus(Vector2(hit.x, hit.z))
		if _painting and hit != null:
			_drag_to(Vector2(hit.x, hit.z), motion)
		return EditorPlugin.AFTER_GUI_INPUT_STOP if _painting else EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		if button.pressed:
			var hit: Variant = _aim(camera, button.position)
			if hit == null:
				return EditorPlugin.AFTER_GUI_INPUT_PASS
			if _begin_stroke():
				_dab(Vector2(hit.x, hit.z), button, 1.0)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		if _painting:
			_end_stroke()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


## Writes the grounds painted since the last save, and the looks whose kinds got a map name (the
## plugin's _save_external_data).
func save_painted() -> void:
	for ground: GrassGround in GrassGround._edited.duplicate():
		var path := ground.resource_path
		if path.is_empty() or path.contains("::"):
			continue
		ground.flush_maps()
		if ResourceSaver.save(ground, path, ResourceSaver.FLAG_COMPRESS) == OK:
			ground._maps_edited = false
			GrassGround._edited.erase(ground)


func _process(delta: float) -> void:
	if _top == null or not _top.visible:
		return
	_status_timer += delta
	if _status_timer > 0.5:
		_status_timer = 0.0
		_update_status()


# --- painting ---------------------------------------------------------------------------------


func _key(key: InputEventKey) -> int:
	if not key.pressed or key.echo or tool == Tool.NONE:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	match key.keycode:
		KEY_BRACKETLEFT:
			_set_setting(_size, "size", maxf(brush.radius / 1.2, _size.min_value))
		KEY_BRACKETRIGHT:
			_set_setting(_size, "size", brush.radius * 1.2)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_set_setting(_strength, "strength", clampf(brush.strength - 0.05, 0.01, 1.0))
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_set_setting(_strength, "strength", clampf(brush.strength + 0.05, 0.01, 1.0))
		KEY_ESCAPE:
			_set_tool(Tool.NONE)
		_:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
	return EditorPlugin.AFTER_GUI_INPUT_STOP


func _aim(camera: Camera3D, at: Vector2) -> Variant:
	if field == null or field.ground == null:
		return null
	return field.ground.ray_hit(
		camera.project_ray_origin(at), camera.project_ray_normal(at), camera.far
	)


func _mode_of(event: InputEventWithModifiers) -> GrassBrush.Mode:
	if event.shift_pressed:
		return GrassBrush.Mode.SMOOTH
	if event.is_command_or_control_pressed() != _erase.button_pressed:
		return GrassBrush.Mode.ERASE
	return GrassBrush.Mode.PAINT


## The map the brush paints (the menu's map items too: where grass grows when no brush is up).
## With `rename`, a kind with no map name gets one first (kept in `_rename`, one step with the
## stroke); without, such a kind has no map yet (empty).
func _map_for(rename: bool) -> StringName:
	match tool:
		Tool.HEIGHT:
			return GrassGround.SIZE
		Tool.COLOUR:
			return GrassGround.COLOR
		Tool.KIND:
			var kinds := _look_kinds()
			if kind_index >= kinds.size():
				return &""
			var kind := kinds[kind_index]
			if kind.map_name == &"" and rename:
				var given := _free_name(_label_of(kind, kind_index))
				_rename = [kind, kind.map_name, given]
				kind.map_name = given
			return kind.map_name
	return GrassGround.DENSITY


func _begin_stroke() -> bool:
	var ground := field.ground
	if ground == null:
		_say("Set the field's ground first.")
		return false
	if tool == Tool.KIND and _look_kinds().is_empty():
		_say("This look has one kind of blade: paint where it grows with «Grass».")
		return false
	if field._keep_ground_in_file().is_empty():
		_say("Save the scene first: the painted maps are kept next to it.")
		return false
	_rename = []
	_map = _map_for(true)
	if _map == &"":
		return false
	_old_texture = ground.map_texture(_map)
	_before = ground.editable_map(_map).duplicate() as Image
	_new_texture = ground.map_texture(_map)
	_dirty = Rect2i()
	_last = Vector2.INF
	_painting = true
	_queue_overlay()
	return true


func _drag_to(at: Vector2, event: InputEventMouseMotion) -> void:
	var pressure := event.pressure if event.pressure > 0.0 else 1.0
	if _last == Vector2.INF:
		_dab(at, event, pressure)
		return
	# Dabs a quarter of the brush apart along the way, so a fast stroke leaves no gaps.
	var spacing := maxf(brush.radius * 0.25, field.ground.paint_texel_size)
	var gap := _last.distance_to(at)
	if gap < spacing:
		return
	var steps := floori(gap / spacing)
	var from := _last
	for k in range(1, steps + 1):
		_dab(from.lerp(at, float(k) / float(steps)), event, pressure)


func _dab(at: Vector2, event: InputEventWithModifiers, pressure: float) -> void:
	brush.mode = _mode_of(event)
	brush.value = _paint_value()
	var changed := field.ground.paint(_map, at, brush, pressure)
	if changed.has_area():
		_dirty = changed if not _dirty.has_area() else _dirty.merge(changed)
	_last = at


func _paint_value() -> Color:
	match tool:
		Tool.HEIGHT:
			return Color(clampf(height * 0.5, 0.0, 1.0), 0.0, 0.0, 1.0)
		Tool.COLOUR:
			return Color(colour.r, colour.g, colour.b, 1.0)
	return Color(1.0, 0.0, 0.0, 1.0)


## One step of the editor's history: the texture the stroke made (if it made one) and the texels it
## changed, before and after.
func _end_stroke() -> void:
	_painting = false
	var ground := field.ground
	if ground == null:
		return
	if not _dirty.has_area() and _old_texture == _new_texture and _rename.is_empty():
		return
	var before: Image = _before.get_region(_dirty) if _dirty.has_area() else null
	var after: Image = ground.map_region(_map, _dirty) if _dirty.has_area() else null
	var history := EditorInterface.get_editor_undo_redo()
	history.create_action("Paint grass (%s)" % _map, UndoRedo.MERGE_DISABLE, field)
	history.add_do_method(ground, &"put_map", _map, _new_texture, after, _dirty.position)
	history.add_undo_method(ground, &"put_map", _map, _old_texture, before, _dirty.position)
	_add_rename(history)
	history.commit_action(false)
	_before = null
	_update_status()


## One step of the history that sets `map` to `texture` (null = none), with the kind's new name.
func _replace_map(map: StringName, texture: Texture2D, action: String) -> void:
	var ground := field.ground
	var old := ground.map_texture(map)
	var history := EditorInterface.get_editor_undo_redo()
	history.create_action(action, UndoRedo.MERGE_DISABLE, field)
	history.add_do_method(ground, &"put_map", map, texture)
	history.add_undo_method(ground, &"put_map", map, old)
	_add_rename(history)
	history.commit_action()
	_queue_overlay()


func _add_rename(history: EditorUndoRedoManager) -> void:
	if _rename.is_empty():
		return
	history.add_do_property(_rename[0], &"map_name", _rename[2])
	history.add_undo_property(_rename[0], &"map_name", _rename[1])
	_save_owner(_rename[0])
	_refresh_kinds()


# --- the menu ---------------------------------------------------------------------------------


func _on_menu(id: int) -> void:
	if field == null:
		return
	match id:
		Item.BAKE:
			field._bake_in_editor()
			_queue_overlay()
		Item.FIT:
			_fit_area()
		Item.BAKE_COLOUR:
			_bake_colour()
		Item.SET_UP:
			var made := field.set_up()
			_say("Set up: %s." % (", ".join(made) if not made.is_empty() else "nothing was missing"))
			edit(field)
		Item.FILL:
			_fill_map()
		Item.CLEAR:
			_rename = []
			var map := _map_for(false)
			if map != &"" and field.ground != null and field.ground.map_texture(map) != null:
				_replace_map(map, null, "Clear grass map (%s)" % map)
		Item.IMPORT:
			_open_dialog(EditorFileDialog.FILE_MODE_OPEN_FILE)
		Item.EXPORT:
			_open_dialog(EditorFileDialog.FILE_MODE_SAVE_FILE)
		Item.SHOW_MAP:
			_show.button_pressed = not _show.button_pressed
		Item.HELP:
			_say(SHORTCUTS)


func _fill_map() -> void:
	var ground := field.ground
	if ground == null or field._keep_ground_in_file().is_empty():
		return
	_rename = []
	var map := _map_for(true)
	if map == &"":
		return
	var old := ground.map_texture(map)
	var before := ground.editable_map(map).duplicate() as Image
	var texture := ground.map_texture(map)
	ground.fill_map(map, _paint_value())
	var whole := Rect2i(Vector2i.ZERO, before.get_size())
	var history := EditorInterface.get_editor_undo_redo()
	history.create_action("Fill grass map (%s)" % map, UndoRedo.MERGE_DISABLE, field)
	history.add_do_method(ground, &"put_map", map, texture, ground.map_region(map, whole))
	history.add_undo_method(ground, &"put_map", map, old, before)
	_add_rename(history)
	history.commit_action(false)


## «Bake ground colour»: the game's ground rendered from above as the colour map, one step of the
## history.
func _bake_colour() -> void:
	var ground := field.ground
	if ground == null or field._keep_ground_in_file().is_empty():
		return
	var old := ground.color_texture
	var target := field
	_set_tool(Tool.NONE)
	var image: Image = await target.bake_ground_color()
	if image == null:
		_say("Baking the ground's colour needs the editor's window: it renders the ground.")
		return
	var history := EditorInterface.get_editor_undo_redo()
	history.create_action("Bake ground colour of %s" % target.name, UndoRedo.MERGE_DISABLE, target)
	history.add_do_method(ground, &"put_map", GrassGround.COLOR, ground.color_texture)
	history.add_undo_method(ground, &"put_map", GrassGround.COLOR, old)
	history.commit_action(false)
	var size := image.get_size()
	_say("Baked the ground's colour (%d × %d) from layers %d." % [size.x, size.y, ground.color_layers])


## «Fit area to the colliders»: the area grows or shrinks to the scene's colliders, keeping what is
## painted where it is, and the new parts are baked when the ground was. One step of the history.
func _fit_area() -> void:
	var ground := field.ground
	if ground == null:
		return
	var fitted := field.colliders_area()
	if not fitted.has_area():
		_say("No colliders on the ground's collision mask (nor meshes) in this scene.")
		return
	resize_area(fitted, "Fit grass area to the colliders")


## The area's handles let go: `node`'s area to `rect`.
func edit_area(node: GrassField3D, rect: Rect2) -> void:
	if node != field:
		edit(node)
	resize_area(rect, "Drag grass area of %s" % node.name)


## Moves the ground's area to `rect` as one step of the history (the area's handles do it too).
func resize_area(rect: Rect2, action: String) -> void:
	var ground := field.ground
	if ground == null or rect.is_equal_approx(ground.area):
		return
	var saved := ground.layout()
	var old_area := ground.area
	var baked := ground.data != null
	ground.resize_area(rect)
	if baked and field.is_inside_tree():
		var space := field.get_world_3d().direct_space_state
		for strip in _new_parts(old_area, rect):
			ground.bake(space, strip)
	var history := EditorInterface.get_editor_undo_redo()
	history.create_action(action, UndoRedo.MERGE_DISABLE, field)
	history.add_do_method(ground, &"set_layout", ground.layout())
	history.add_undo_method(ground, &"set_layout", saved)
	history.add_do_method(field, &"update_gizmos")
	history.add_undo_method(field, &"update_gizmos")
	history.commit_action(false)
	field.update_gizmos()
	_queue_overlay()
	_say("Area: %s." % [rect])


## The parts of `new` outside `old`: up to four strips.
static func _new_parts(old: Rect2, new: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var both := old.intersection(new)
	if not both.has_area():
		out.append(new)
		return out
	if both.position.x > new.position.x:
		out.append(Rect2(new.position, Vector2(both.position.x - new.position.x, new.size.y)))
	if both.end.x < new.end.x:
		out.append(Rect2(both.end.x, new.position.y, new.end.x - both.end.x, new.size.y))
	if both.position.y > new.position.y:
		out.append(Rect2(both.position.x, new.position.y, both.size.x, both.position.y - new.position.y))
	if both.end.y < new.end.y:
		out.append(Rect2(both.position.x, both.end.y, both.size.x, new.end.y - both.end.y))
	return out


func _open_dialog(mode: EditorFileDialog.FileMode) -> void:
	if field.ground == null:
		return
	var saving := mode == EditorFileDialog.FILE_MODE_SAVE_FILE
	var map := _map_for(false)
	if saving and (map == &"" or field.ground.export_map(map) == null):
		_say("Nothing painted on this map yet.")
		return
	if map == &"":
		var kind := _look_kinds()[kind_index] if not _look_kinds().is_empty() else null
		if kind == null:
			return
		map = _free_name(_label_of(kind, kind_index))
	_file_dialog.file_mode = mode
	_file_dialog.title = ("Export the %s map" if saving else "Import the %s map") % map
	var scene := EditorInterface.get_edited_scene_root()
	var base := scene.scene_file_path.get_basename() if scene != null else "res://grass"
	_file_dialog.current_path = ProjectSettings.globalize_path("%s_grass_%s.png" % [base, map])
	_file_dialog.set_meta(&"map", map)
	_file_dialog.popup_file_dialog()


func _on_file(path: String) -> void:
	var map: StringName = _file_dialog.get_meta(&"map")
	var ground := field.ground if field != null else null
	if ground == null:
		return
	if _file_dialog.file_mode == EditorFileDialog.FILE_MODE_SAVE_FILE:
		var err := ground.export_map(map).save_png(path)
		_say("Exported the %s map to %s." % [map, path] if err == OK else "Could not write %s." % path)
		return
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		_say("Could not read %s." % path)
		return
	if field._keep_ground_in_file().is_empty():
		return
	_rename = []
	if tool == Tool.KIND:
		map = _map_for(true)
	var copy := image.duplicate() as Image
	if copy.is_compressed():
		copy.decompress()
	copy.clear_mipmaps()
	copy.convert(Image.FORMAT_RGBA8 if map == GrassGround.COLOR else Image.FORMAT_R8)
	_replace_map(map, ImageTexture.create_from_image(copy), "Import grass map (%s)" % map)
	var size := copy.get_size()
	_say("Imported %s as the %s map (%d × %d)." % [path.get_file(), map, size.x, size.y])


# --- the cursor and the map overlay -----------------------------------------------------------


func _show_cursor(hit: Variant, mode: GrassBrush.Mode) -> void:
	if hit == null or field == null or not field.is_inside_tree():
		if _cursor.is_valid():
			RenderingServer.instance_set_visible(_cursor, false)
		return
	if not _cursor.is_valid():
		_cursor = RenderingServer.instance_create2(_cursor_mesh.get_rid(), field.get_world_3d().scenario)
	RenderingServer.instance_set_scenario(_cursor, field.get_world_3d().scenario)
	RenderingServer.instance_set_visible(_cursor, true)
	var tint := Color(1.0, 1.0, 1.0)
	match mode:
		GrassBrush.Mode.ERASE:
			tint = Color(1.0, 0.35, 0.3)
		GrassBrush.Mode.SMOOTH:
			tint = Color(0.4, 0.85, 1.0)
	_cursor_material.albedo_color = tint
	var centre := Vector2(hit.x, hit.z)
	_cursor_mesh.clear_surfaces()
	for r: float in [brush.radius, brush.radius * (1.0 - brush.falloff)]:
		if r < 0.05:
			continue
		_cursor_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _cursor_material)
		for k in CIRCLE + 1:
			var a := TAU * k / CIRCLE
			var p := centre + Vector2(cos(a), sin(a)) * r
			_cursor_mesh.surface_add_vertex(Vector3(p.x, field.ground.height_at(p) + 0.05, p.y))
		_cursor_mesh.surface_end()
	# The centre: a short tick up.
	_cursor_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _cursor_material)
	_cursor_mesh.surface_add_vertex(Vector3(hit.x, hit.y, hit.z))
	_cursor_mesh.surface_add_vertex(Vector3(hit.x, hit.y + maxf(brush.radius * 0.25, 0.3), hit.z))
	_cursor_mesh.surface_end()


func _queue_overlay() -> void:
	if not _overlay_queued:
		_overlay_queued = true
		_update_overlay.call_deferred()


## The brush's map drawn over the ground while a brush is up: where grass grows (green, red where
## it does not), how tall (blue shorter, orange taller), the colour, a kind (magenta).
func _update_overlay() -> void:
	_overlay_queued = false
	var shown := field != null and field.ground != null and tool != Tool.NONE and show_map
	shown = shown and field.is_inside_tree()
	if not shown:
		if _overlay.is_valid():
			RenderingServer.instance_set_visible(_overlay, false)
		return
	var ground := field.ground
	var map := _map_for(false)
	var texture := ground.map_texture(map) if map != &"" else null
	if texture == null:
		texture = _blank(map)
	_overlay_material.set_shader_parameter(&"map", texture)
	_overlay_material.set_shader_parameter(&"kind", clampi(int(tool) - 1, 0, 3))
	_build_overlay_mesh(ground)
	if not _overlay.is_valid():
		var scenario := field.get_world_3d().scenario
		_overlay = RenderingServer.instance_create2(_overlay_mesh.get_rid(), scenario)
	RenderingServer.instance_set_scenario(_overlay, field.get_world_3d().scenario)
	RenderingServer.instance_set_visible(_overlay, true)


func _build_overlay_mesh(ground: GrassGround) -> void:
	var area := ground.area
	var steps := Vector2i(
		clampi(ceili(area.size.x / 2.0), 2, 160), clampi(ceili(area.size.y / 2.0), 2, 160)
	)
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	for y in steps.y + 1:
		for x in steps.x + 1:
			var uv := Vector2(float(x) / steps.x, float(y) / steps.y)
			var at := area.position + area.size * uv
			points.append(Vector3(at.x, ground.height_at(at) + 0.03, at.y))
			uvs.append(uv)
	var indices := PackedInt32Array()
	var row := steps.x + 1
	for y in steps.y:
		for x in steps.x:
			var i := y * row + x
			indices.append_array([i, i + 1, i + row, i + 1, i + row + 1, i + row])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_overlay_mesh.clear_surfaces()
	_overlay_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_overlay_mesh.surface_set_material(0, _overlay_material)


func _blank(map: StringName) -> Texture2D:
	if not _blank_maps.has(map):
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(GrassGround.map_rest(map) if map != &"" else Color(0, 0, 0, 0))
		_blank_maps[map] = ImageTexture.create_from_image(image)
	return _blank_maps[map]


func _set_focus(at: Vector2) -> void:
	if field != null:
		field._editor_focus = at


func _watch_ground(ground: GrassGround, on: bool) -> void:
	if on:
		if not ground.area_changed.is_connected(_on_area_changed):
			ground.area_changed.connect(_on_area_changed)
	elif ground.area_changed.is_connected(_on_area_changed):
		ground.area_changed.disconnect(_on_area_changed)


func _on_area_changed(_rect: Rect2) -> void:
	_queue_overlay()


# --- the bars ---------------------------------------------------------------------------------


func _build() -> void:
	_top = HBoxContainer.new()
	_menu = MenuButton.new()
	_menu.text = "GrassKit"
	_menu.flat = false
	_menu.theme_type_variation = &"FlatMenuButton"
	_menu.tooltip_text = "GrassKit: the ground and its painted maps."
	var popup := _menu.get_popup()
	popup.add_item("Bake ground", Item.BAKE)
	popup.add_item("Fit area to the colliders", Item.FIT)
	popup.add_item("Set up what is missing", Item.SET_UP)
	popup.add_item("Bake ground colour", Item.BAKE_COLOUR)
	popup.add_separator()
	popup.add_item("Fill the map", Item.FILL)
	popup.add_item("Clear the map", Item.CLEAR)
	popup.add_item("Import the map from a PNG…", Item.IMPORT)
	popup.add_item("Export the map to a PNG…", Item.EXPORT)
	popup.add_separator()
	popup.add_check_item("Show the painted map", Item.SHOW_MAP)
	popup.add_item("Shortcuts", Item.HELP)
	popup.id_pressed.connect(_on_menu)
	popup.about_to_popup.connect(_update_menu)
	_top.add_child(_menu)
	_top.add_child(VSeparator.new())
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for index in range(1, TOOL_NAMES.size()):
		var button := Button.new()
		button.text = TOOL_NAMES[index]
		button.toggle_mode = true
		# The 3D view's own toggles: pressed shows.
		button.theme_type_variation = &"FlatButton"
		button.button_group = group
		button.tooltip_text = "%s\n%s" % [TOOL_TIPS[index], SHORTCUTS]
		button.toggled.connect(_on_tool_toggled.bind(index))
		_tools.append(button)
		_top.add_child(button)

	_bottom = HBoxContainer.new()
	_size = _slider("Size", 0.1, 50.0, 0.1, brush.radius, "m")
	_size.tooltip_text = "The brush's radius ([ and ])."
	_strength = _slider("Strength", 0.01, 1.0, 0.01, brush.strength, "")
	_strength.tooltip_text = "How far one dab goes (- and =). A pen's pressure scales it."
	_falloff = _slider("Falloff", 0.0, 1.0, 0.01, brush.falloff, "")
	_falloff.tooltip_text = "How much of the radius fades out."
	_noise = _slider("Noise", 0.0, 1.0, 0.01, brush.noise, "")
	_noise.tooltip_text = "A ragged edge, the same wherever the brush passes: natural patches."
	_erase = CheckBox.new()
	_erase.text = "Erase"
	_erase.tooltip_text = "Erase instead of paint (Ctrl or Cmd swaps it while held)."
	_height = _slider("Height", 0.0, 2.0, 0.05, height, "×")
	_height.tooltip_text = "How tall the «Height» brush makes the grass, against the look's."
	_colour = ColorPickerButton.new()
	_colour.color = colour
	_colour.edit_alpha = false
	_colour.custom_minimum_size = Vector2(48, 0)
	_colour.tooltip_text = "The ground's colour the «Colour» brush paints."
	_kinds = OptionButton.new()
	_kinds.tooltip_text = "The kind of blade the «Kind» brush paints (its map name)."
	_show = CheckBox.new()
	_show.text = "Map"
	_show.button_pressed = show_map
	_show.tooltip_text = "Show the brush's map over the ground."
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	_status.mouse_filter = Control.MOUSE_FILTER_PASS
	_status.tooltip_text = SHORTCUTS
	var controls: Array[Control] = [
		_size, _strength, _falloff, _noise, _erase, _height, _colour, _kinds, _show, _status
	]
	for control in controls:
		_bottom.add_child(control)
	_size.value_changed.connect(_on_setting.bind("size"))
	_strength.value_changed.connect(_on_setting.bind("strength"))
	_falloff.value_changed.connect(_on_setting.bind("falloff"))
	_noise.value_changed.connect(_on_setting.bind("noise"))
	_height.value_changed.connect(_on_setting.bind("height"))
	_colour.color_changed.connect(_on_setting.bind("colour"))
	_show.toggled.connect(_on_setting.bind("show_map"))
	_kinds.item_selected.connect(_on_kind_selected)

	_file_dialog = EditorFileDialog.new()
	_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(
		["*.png ; PNG", "*.exr ; EXR", "*.webp ; WebP", "*.jpg ; JPEG"]
	)
	_file_dialog.file_selected.connect(_on_file)
	add_child(_file_dialog)
	_update_ui()


func _on_setting(value: Variant, key: String) -> void:
	match key:
		"size":
			brush.radius = value
		"strength":
			brush.strength = value
		"falloff":
			brush.falloff = value
		"noise":
			brush.noise = value
		"height":
			height = value
		"colour":
			colour = value
		"show_map":
			show_map = value
	_save_setting(key, value)


## A key's change: the brush and its slider together.
func _set_setting(slider: EditorSpinSlider, key: String, value: float) -> void:
	slider.set_value_no_signal(value)
	_on_setting(value, key)


func _on_kind_selected(index: int) -> void:
	kind_index = index
	_queue_overlay()
	_update_status()


func _slider(
	label: String, low: float, high: float, step: float, value: float, suffix: String
) -> EditorSpinSlider:
	var slider := EditorSpinSlider.new()
	slider.label = label
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.allow_greater = label == "Size"
	slider.value = value
	slider.suffix = suffix
	slider.custom_minimum_size = Vector2(150, 0) * EditorInterface.get_editor_scale()
	return slider


func _on_tool_toggled(on: bool, index: int) -> void:
	if on:
		_set_tool(index as Tool)
	elif tool == index:
		_set_tool(Tool.NONE)


func _set_tool(value: Tool) -> void:
	if _painting:
		_end_stroke()
	tool = value
	for index in _tools.size():
		_tools[index].set_pressed_no_signal(index + 1 == int(tool))
	if tool == Tool.NONE:
		_set_focus(Vector2.INF)
		if _cursor.is_valid():
			RenderingServer.instance_set_visible(_cursor, false)
	_queue_overlay()
	_update_ui()


func _update_ui() -> void:
	if _bottom == null:
		return
	_height.visible = tool == Tool.HEIGHT
	_colour.visible = tool == Tool.COLOUR
	_kinds.visible = tool == Tool.KIND
	for control: Control in [_size, _strength, _falloff, _noise, _erase, _show]:
		control.visible = tool != Tool.NONE
	_update_status()


func _update_menu() -> void:
	var popup := _menu.get_popup()
	var map := String(_map_for(false)) if field != null else "density"
	if map.is_empty():
		map = "kind's"
	popup.set_item_text(popup.get_item_index(Item.FILL), "Fill the %s map" % map)
	popup.set_item_text(popup.get_item_index(Item.CLEAR), "Clear the %s map" % map)
	popup.set_item_text(popup.get_item_index(Item.IMPORT), "Import the %s map from a PNG…" % map)
	popup.set_item_text(popup.get_item_index(Item.EXPORT), "Export the %s map to a PNG…" % map)
	popup.set_item_checked(popup.get_item_index(Item.SHOW_MAP), show_map)


func _refresh_kinds() -> void:
	if _kinds == null:
		return
	_kinds.clear()
	var kinds := _look_kinds()
	for index in kinds.size():
		_kinds.add_item(_label_of(kinds[index], index))
	kind_index = clampi(kind_index, 0, maxi(kinds.size() - 1, 0))
	if not kinds.is_empty():
		_kinds.select(kind_index)


func _update_status() -> void:
	if _status == null:
		return
	_status.text = _status_text()


func _status_text() -> String:
	if field == null:
		return ""
	var ground := field.ground
	if ground == null:
		return "Set the field's ground (GrassKit ▸ Set up what is missing)."
	var parts := PackedStringArray()
	if ground.data == null:
		parts.append("The ground is flat: GrassKit ▸ Bake ground")
	if tool == Tool.NONE:
		parts.append("Pick a brush to paint the grass")
	elif tool == Tool.KIND and _look_kinds().is_empty():
		parts.append("This look has one kind of blade")
	else:
		var map := GrassGround.DENSITY
		match tool:
			Tool.HEIGHT:
				map = GrassGround.SIZE
			Tool.COLOUR:
				map = GrassGround.COLOR
			Tool.KIND:
				var kind := _look_kinds()[kind_index]
				map = kind.map_name if kind.map_name != &"" else _free_name(_label_of(kind, kind_index))
		var size := ground.map_size(map)
		if size == Vector2i.ZERO:
			size = ground.new_map_size()
			parts.append("%s map: new on the first stroke (%d × %d)" % [map, size.x, size.y])
		else:
			parts.append("%s map %d × %d" % [map, size.x, size.y])
	parts.append("%s blades in view" % _thousands(field.stats.blades_in_view))
	return " · ".join(parts)


func _say(text: String) -> void:
	if _status != null:
		_status.text = text
	print("GrassKit: %s" % text)


# --- kinds ------------------------------------------------------------------------------------


## The look's own kinds (none when it only has the kit's blade).
func _look_kinds() -> Array[GrassMesh]:
	var out: Array[GrassMesh] = []
	if field == null or field.look == null:
		return out
	for kind in field.look.meshes:
		if kind != null and kind.weight > 0.0:
			out.append(kind)
	return out


func _label_of(kind: GrassMesh, index: int) -> String:
	if kind.map_name != &"":
		return kind.map_name
	var path := kind.resource_path
	if not path.is_empty() and not path.contains("::"):
		return path.get_file().get_basename()
	if kind.mesh == null:
		return "blade"
	if not kind.mesh.resource_path.is_empty() and not kind.mesh.resource_path.contains("::"):
		return kind.mesh.resource_path.get_file().get_basename()
	return "kind_%d" % (index + 1)


## `wanted`, or with a number after it, so no two kinds and none of the ground's maps share it.
func _free_name(wanted: String) -> StringName:
	var taken: Array[StringName] = [GrassGround.DENSITY, GrassGround.SIZE, GrassGround.COLOR]
	for kind in _look_kinds():
		if kind.map_name != &"":
			taken.append(kind.map_name)
	var name := StringName(wanted.to_snake_case())
	var n := 2
	while taken.has(name):
		name = StringName("%s_%d" % [wanted.to_snake_case(), n])
		n += 1
	return name


## Saves the file a renamed kind lives in (its own .tres, or the look it is inside).
func _save_owner(resource: Resource) -> void:
	var path := resource.resource_path
	if path.is_empty():
		return
	var file := path.get_slice("::", 0)
	if path.contains("::"):
		if file.get_extension() in ["tscn", "scn"]:
			return
		if ResourceLoader.has_cached(file):
			ResourceSaver.save(ResourceLoader.get_cached_ref(file), file)
		return
	ResourceSaver.save(resource, file)


# --- settings ---------------------------------------------------------------------------------


func _load_settings() -> void:
	brush.radius = _setting("size", 2.0)
	brush.strength = _setting("strength", 0.5)
	brush.falloff = _setting("falloff", 0.5)
	brush.noise = _setting("noise", 0.3)
	height = _setting("height", 0.5)
	colour = _setting("colour", colour)
	show_map = _setting("show_map", true)


func _setting(key: String, fallback: Variant) -> Variant:
	var settings := EditorInterface.get_editor_settings()
	return settings.get_project_metadata("grass_kit", key, fallback)


func _save_setting(key: String, value: Variant) -> void:
	EditorInterface.get_editor_settings().set_project_metadata("grass_kit", key, value)
	_queue_overlay()


static func _thousands(n: int) -> String:
	if n >= 10000:
		return "%dk" % roundi(n / 1000.0)
	return str(n)
