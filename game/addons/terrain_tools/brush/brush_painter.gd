@tool
extends RefCounted

## A ground brush stroke on the selected Terrain, from the 3D viewport's mouse: the cursor follows the ground, the left
## button starts a stroke (BrushStroke) with the toolbar's tool and Shift, each move paints a working copy shown by
## EditorPreview (no mesh rebuild), the release hands before and after to TerrainHistory as one undoable step. Raise and
## lower stays where it was pressed and follows the mouse up or down. Not: undo and saving, the bar, the arithmetic.

const Toolbar := preload("res://addons/terrain_tools/brush/brush_toolbar.gd")
const GroundPick := preload("res://addons/terrain_tools/brush/ground_pick.gd")
const BrushCursor := preload("res://addons/terrain_tools/brush/brush_cursor.gd")
const EditorPreview := preload("res://addons/terrain_tools/brush/editor_preview.gd")
const TerrainHistory := preload("res://addons/terrain_tools/terrain_history.gd")
## The undo history's name of a stroke, by BrushStroke.Mode.
const LABELS := ["Terreno: subir o bajar", "Terreno: suavizar", "Terreno: aplanar", "Terreno: hueco", "Terreno: rellenar"]

var toolbar: Toolbar
var _history: TerrainHistory
var _terrain: Terrain
var _cursor := BrushCursor.new()
var _preview := EditorPreview.new()
var _stroke: BrushStroke
var _work: Array = []  ## [heights, mask] the stroke paints
var _pressed_at := Vector2()


func _init(history: TerrainHistory, bar: Toolbar) -> void:
	_history = history
	toolbar = bar
	_history.written.connect(_on_written)
	_history.budget.measured.connect(_show_cost.unbind(2))


## The Terrain the brush paints on now (null: none selected).
func edit(terrain: Terrain) -> void:
	if _terrain == terrain:
		return
	if _terrain != null and is_instance_valid(_terrain) and _terrain.derived.is_connected(_on_derived):
		_terrain.derived.disconnect(_on_derived)
	_stroke = null
	_cursor.hide()
	_terrain = terrain if terrain != null and terrain.heights != null and terrain.heights.is_valid() else null
	if _terrain == null:
		return
	_terrain.derived.connect(_on_derived)
	_preview.clear()
	var now := _history.arrays(_terrain)
	_preview.adopt(_terrain.heights, now[0], now[1])
	_show_draft()
	_show_cost()


## The 3D viewport's input while a Terrain is selected: true when the brush used it.
func input(camera: Camera3D, event: InputEvent) -> bool:
	if _terrain == null or toolbar.tool == Toolbar.Tool.NONE or not is_instance_valid(_terrain):
		_cursor.hide()
		return false
	var mouse := event as InputEventMouse
	if mouse == null:
		return false
	var heights: PackedFloat32Array = _work[0] if _stroke != null else _history.arrays(_terrain)[0]
	var frame := _terrain.global_transform
	var local := frame.affine_inverse()
	var hit: Variant = GroundPick.march(local * camera.project_ray_origin(mouse.position),
			local.basis * camera.project_ray_normal(mouse.position), heights)
	var at := Vector2(hit.x, hit.z) if hit != null else _pressed_at
	if hit != null or _stroke != null:
		_cursor.draw(_terrain.get_world_3d().scenario, frame, _pressed_at if _raising() else at, toolbar.brush, heights)
	else:
		_cursor.hide()
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		var stroking := _stroke != null
		if button.pressed and hit != null:
			_begin(at, button.shift_pressed)
		elif not button.pressed and stroking:
			_finish()
		return (button.pressed and hit != null) or (not button.pressed and stroking)
	var motion := event as InputEventMouseMotion
	if motion != null and _stroke != null and (hit != null or _raising()):
		_stroke.drag(_pressed_at if _raising() else at, -motion.relative.y)
		_preview.show(_stroke.dirty_rect(), _work[0], _work[1])
		return true
	return false


## Hands a waiting draft to the Terrain now (the toolbar's «Rearmar»).
func rebuild() -> void:
	if _terrain != null:
		_history.rebuild(_terrain)
		_show_draft()


## Frees what RenderingServer holds (the plugin calls it when it leaves the editor).
func release() -> void:
	_preview.clear()
	_cursor.release()


func _begin(at: Vector2, shift: bool) -> void:
	var mode := BrushStroke.Mode.RAISE
	match toolbar.tool:
		Toolbar.Tool.SMOOTH:
			mode = BrushStroke.Mode.FLATTEN if shift else BrushStroke.Mode.SMOOTH
		Toolbar.Tool.VOID:
			mode = BrushStroke.Mode.FILL if shift else BrushStroke.Mode.VOID
	_work = _history.arrays(_terrain)
	_pressed_at = at
	_stroke = BrushStroke.new()
	_stroke.begin(_work[0], _work[1], mode, toolbar.brush, at)
	_stroke.drag(at, 0.0)
	_preview.show(_stroke.dirty_rect(), _work[0], _work[1])


func _finish() -> void:
	var done := _stroke.finish()
	var label: String = LABELS[_stroke.mode]
	_stroke = null
	if (done["rect"] as Rect2i).has_area():
		var before: Array[BrushStroke.Patch] = [done["before"]]
		var after: Array[BrushStroke.Patch] = [done["after"]]
		_history.commit(_terrain, label, before, after)


func _raising() -> bool:
	return _stroke != null and _stroke.mode == BrushStroke.Mode.RAISE


## A step was done, undone or redone over `rect`: the preview shows the ground there as the editor has it now.
func _on_written(terrain: Terrain, rect: Rect2i) -> void:
	if terrain == _terrain:
		var now := _history.arrays(terrain)
		_preview.show(rect, now[0], now[1])
		_show_draft()


## The mesh was built again from the heights: it shows them, so only a draft (or a stroke) is left to preview.
func _on_derived() -> void:
	var now: Array = _work if _stroke != null else _history.arrays(_terrain)
	_preview.adopt(_terrain.heights, now[0], now[1])
	_show_draft()


func _show_draft() -> void:
	toolbar.show_draft(_history.has_draft(_terrain))


func _show_cost() -> void:
	if _terrain != null:
		toolbar.show_cost(_history.budget.cost_ms(_terrain), _history.budget.is_light(_terrain))
