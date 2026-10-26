@tool
extends RefCounted

## A brush stroke on what is selected (a Terrain, a FloraLayer), from the 3D viewport's mouse: the cursor follows the
## ground of the map's Terrain (picked on the heights being edited), the left button starts a stroke (BrushStroke) on the
## canvas BrushTargets picks for the bar's tool and Shift, each move paints its working copy and shows it (the canvas's
## preview, no mesh rebuild), the release hands before and after to TerrainHistory as one undoable step. Raise and lower
## stays where it was pressed and follows the mouse up or down. Not: undo and saving, the bar, the arithmetic.

const Toolbar := preload("res://addons/terrain_tools/brush/brush_toolbar.gd")
const GroundPick := preload("res://addons/terrain_tools/brush/ground_pick.gd")
const BrushCursor := preload("res://addons/terrain_tools/brush/brush_cursor.gd")
const EditorPreview := preload("res://addons/terrain_tools/brush/editor_preview.gd")
const TerrainHistory := preload("res://addons/terrain_tools/terrain_history.gd")
const BrushTargets := preload("res://addons/terrain_tools/brush/brush_targets.gd")

var toolbar: Toolbar
var _history: TerrainHistory
var _node: Node  ## what is selected
var _terrain: Terrain  ## the ground the cursor sits on
var _lattice: LatticeCanvas  ## its heights, as the editor has them
var _cursor := BrushCursor.new()
var _preview := EditorPreview.new()
var _stroke: BrushStroke
var _target: BrushTargets.Target
var _pressed_at := Vector2()


func _init(history: TerrainHistory, bar: Toolbar) -> void:
	_history = history
	toolbar = bar
	_history.written.connect(_show_draft.unbind(2))  # a step done, undone or redone: does a draft wait now?
	_history.budget.measured.connect(_show_cost.unbind(2))


## What the brush paints on now (a Terrain or a FloraLayer; null: nothing selected).
func edit(node: Node) -> void:
	if _node == node:
		return
	_node = node
	if _terrain != null and is_instance_valid(_terrain) and _terrain.derived.is_connected(_on_derived):
		_terrain.derived.disconnect(_on_derived)
	if _lattice != null:
		_lattice.shown = null
	_lattice = null
	_stroke = null
	_cursor.hide()
	var ground := BrushTargets.ground_of(node)
	_terrain = ground if ground != null and ground.heights != null and ground.heights.is_valid() else null
	if _terrain == null:
		return
	_lattice = _history.lattice(_terrain)
	_terrain.derived.connect(_on_derived)
	_preview.clear()
	var now := _lattice.arrays()
	_preview.adopt(_terrain.heights, now[0], now[1])
	_lattice.shown = _preview
	_show_draft()
	_show_cost()


## The 3D viewport's input while a Terrain or a FloraLayer is selected: true when the brush used it.
func input(camera: Camera3D, event: InputEvent) -> bool:
	if _terrain == null or toolbar.tool == Toolbar.Tool.NONE or not is_instance_valid(_terrain):
		_cursor.hide()
		return false
	var mouse := event as InputEventMouse
	if mouse == null:
		return false
	var heights: PackedFloat32Array = _ground_now()[0]
	var frame := _terrain.global_transform
	var local := frame.affine_inverse()
	var hit: Variant = GroundPick.march(local * camera.project_ray_origin(mouse.position),
			local.basis * camera.project_ray_normal(mouse.position), heights)
	var at := Vector2(hit.x, hit.z) if hit != null else _pressed_at
	if hit != null or _stroke != null:
		_cursor.draw(_terrain.get_world_3d().scenario, frame, _pressed_at if _pinned() else at, toolbar.brush, heights)
	else:
		_cursor.hide()
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed or _stroke == null:
			return button.pressed and hit != null and _begin(at, button.shift_pressed)
		_finish()
		return true
	var motion := event as InputEventMouseMotion
	if motion != null and _stroke != null and (hit != null or _pinned()):
		_stroke.drag(_pressed_at if _pinned() else at, -motion.relative.y)
		_stroke.canvas.preview(_stroke.dirty_rect())
		return true
	return false


## Hands a waiting draft to the Terrain now (the toolbar's «Rearmar»).
func rebuild() -> void:
	if _lattice != null:
		_lattice.rebuild()
		_show_draft()


## Frees what RenderingServer holds (the plugin calls it when it leaves the editor).
func release() -> void:
	_preview.clear()
	_cursor.release()


## Starts a stroke where the bar's tool has a canvas on the selected node; false when it has none.
func _begin(at: Vector2, shift: bool) -> bool:
	_target = BrushTargets.resolve(_history, _node, toolbar.tool, shift)
	if _target == null:
		return false
	_pressed_at = at
	_stroke = BrushStroke.new()
	_stroke.begin(_target.canvas, _target.mode, toolbar.brush, at)
	_stroke.drag(at, 0.0)
	_target.canvas.preview(_stroke.dirty_rect())
	return true


func _finish() -> void:
	var done := _stroke.finish()
	_stroke = null
	if (done["rect"] as Rect2i).has_area():
		_history.commit(_target.canvas, _target.label, done["before"], done["after"])


func _ground_now() -> Array:
	return _lattice.work() if _stroke != null and _stroke.canvas == _lattice else _lattice.arrays()


func _pinned() -> bool:
	return _stroke != null and _target.pinned


## The mesh was built again from the heights: it shows them, so only a draft (or a stroke) is left to preview.
func _on_derived() -> void:
	var now := _ground_now()
	_preview.adopt(_terrain.heights, now[0], now[1])
	_show_draft()


func _show_draft() -> void:
	toolbar.show_draft(_lattice != null and _lattice.has_draft())


func _show_cost() -> void:
	if _terrain != null:
		toolbar.show_cost(_history.budget.cost_ms(_terrain), _history.budget.is_light(_terrain))
