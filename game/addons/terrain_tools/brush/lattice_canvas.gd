@tool
class_name LatticeCanvas
extends BrushCanvas

## The ground's heights and voids as a brush canvas (mode = BrushStroke.Mode): a dab raises, smooths, flattens to the
## height under the press, paints or fills void (BrushRules) on a working copy. In the editor `write` hands patches to the
## Terrain's TerrainHeights (a new array: it builds its ground again) or, when that rebuild is heavy (RefreshBudget), keeps
## them as a draft the preview shows until `rebuild` or `save`; `save` writes heights.png + void.png and reimports them.
## Headless (`over`) it edits the given arrays IN PLACE. Not: the mouse, undo, the preview itself, the arithmetic.

const MapImages := preload("res://addons/terrain_tools/map_images.gd")
const TerrainEdits := preload("res://addons/terrain_tools/terrain_edits.gd")
const RefreshBudget := preload("res://addons/terrain_tools/brush/refresh_budget.gd")
const EditorPreview := preload("res://addons/terrain_tools/brush/editor_preview.gd")
const CanvasFiles := preload("res://addons/terrain_tools/brush/canvas_files.gd")
const LABELS := ["Terrain: raise or lower", "Terrain: smooth", "Terrain: flatten", "Terrain: hole", "Terrain: fill"]

## Where edits show before the mesh is built again (the painter sets it while its Terrain is selected).
var shown: EditorPreview
## The height of the vertex nearest to where the stroke began (flatten aims at it).
var start_height_m := 0.0

var _terrain: Terrain
var _heights: TerrainHeights  ## the resource this canvas edits (null headless)
var _budget: RefreshBudget
var _work: Array = []  ## [heights, mask] the stroke paints (headless: the caller's arrays)
var _draft: Array = []  ## [heights, mask] not yet handed to `_heights` (empty: none)
var _folder := ""  ## where `_heights` is saved; "" = nothing unsaved
var _mode := 0
var _brush: TerrainBrush


## A canvas over these lattice arrays (TerrainGrid.COUNT values each, row by row), edited in place. No editor.
static func over(heights: PackedFloat32Array, mask: PackedByteArray) -> LatticeCanvas:
	var canvas := LatticeCanvas.new()
	canvas._work = [heights, mask]
	return canvas


## The editor's canvas of `terrain`'s heights; `budget` says when a rebuild is light enough to do on release.
static func of(terrain: Terrain, budget: RefreshBudget) -> LatticeCanvas:
	var canvas := LatticeCanvas.new()
	canvas._terrain = terrain
	canvas._heights = terrain.heights
	canvas._budget = budget
	return canvas


## The Terrain that shows these heights now (TerrainHistory keeps one canvas per TerrainHeights).
func use(terrain: Terrain) -> void:
	_terrain = terrain


func context() -> Node:
	return _terrain


func cell_rect(center_m: Vector2, reach_m: float) -> Rect2i:
	return TerrainGrid.vertex_rect(center_m, reach_m)


func begin(mode: int, brush: TerrainBrush, at_m: Vector2) -> void:
	if _heights != null:
		_work = arrays()
	_mode = mode
	_brush = brush
	start_height_m = (_work[0] as PackedFloat32Array)[TerrainGrid.vertex_id(at_m.x, at_m.y)]


func dab(at_m: Vector2, vertical_px: float) -> Rect2i:
	var heights: PackedFloat32Array = _work[0]
	var mask: PackedByteArray = _work[1]
	var rect := cell_rect(at_m, _brush.size_m)
	var weights := BrushRules.weights(_brush, at_m, rect)
	match _mode:
		BrushStroke.Mode.RAISE:
			BrushRules.raise(heights, rect, weights, vertical_px * _brush.strength_m)
		BrushStroke.Mode.SMOOTH:
			BrushRules.smooth(heights, rect, weights, BrushStroke.PASS_STRENGTH)
		BrushStroke.Mode.FLATTEN:
			BrushRules.flatten(heights, rect, weights, start_height_m)
		BrushStroke.Mode.VOID:
			BrushRules.paint_void(mask, rect, weights, true)
		BrushStroke.Mode.FILL:
			BrushRules.paint_void(mask, rect, weights, false)
	return rect


func copy() -> Variant:
	return [(_work[0] as PackedFloat32Array).duplicate(), (_work[1] as PackedByteArray).duplicate()]


func patch(rect: Rect2i, from: Variant = null) -> RefCounted:
	var source: Array = _work if from == null else from
	return BrushStroke.Patch.read(source[0], source[1], rect)


func write(patches: Array) -> void:
	if _heights == null:
		for each: BrushStroke.Patch in patches:
			each.write(_work[0], _work[1])
		return
	if not is_instance_valid(_terrain) or not _heights.is_valid():
		return
	var now := arrays()
	for each: BrushStroke.Patch in patches:
		each.write(now[0], now[1])
	_folder = TerrainEdits.folder_of(_terrain)
	_draft = [] if _budget.is_light(_terrain) else now
	if _draft.is_empty():
		_hand(now)
	if shown != null:
		shown.show(BrushCanvas.span(patches), now[0], now[1])


func preview(rect: Rect2i) -> void:
	if shown != null and not _work.is_empty():
		shown.show(rect, _work[0], _work[1])


func is_dirty() -> bool:
	return not _folder.is_empty()


func save() -> String:
	if _folder.is_empty():
		return ""
	rebuild()
	var folder := _folder
	_folder = ""
	var result := MapImages.write(_heights, folder)
	if result.error.is_empty() and not result.written.is_empty():
		reimport_pictures.call_deferred(folder)
	return result.error


func label(mode: int) -> String:
	return LABELS[mode]


## Copies of the heights and voids as the editor has them now (a draft wins over the resource); headless, of the arrays.
func arrays() -> Array:
	if _heights == null:
		return copy()
	var now: Array = _draft if not _draft.is_empty() else [_heights.heights_m, _heights.void_mask]
	return [(now[0] as PackedFloat32Array).duplicate(), (now[1] as PackedByteArray).duplicate()]


## The working copy of the last stroke (the arrays themselves, not a copy; empty before the first one).
func work() -> Array:
	return _work


## True when the Terrain's resource does not hold the changes yet (the ground on screen is the preview).
func has_draft() -> bool:
	return not _draft.is_empty()


## Hands the draft to the TerrainHeights, so the Terrain builds its ground again (the editor waits for it).
func rebuild() -> void:
	if has_draft():
		_hand(_draft)


## Drops what the editor holds for these heights (their pictures were just written by something else).
func forget() -> void:
	_work = []
	_draft = []
	_folder = ""


## Tells the editor the pictures in `folder` changed and imports heights.png again (it reads void.png beside it).
static func reimport_pictures(folder: String) -> void:
	CanvasFiles.reimport(PackedStringArray([folder.path_join(MapImages.VOID_FILE), folder.path_join(MapImages.HEIGHTS_FILE)]))


func _hand(now: Array) -> void:
	_draft = []
	_heights.heights_m = now[0]
	_heights.void_mask = now[1]
