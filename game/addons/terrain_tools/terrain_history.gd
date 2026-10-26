@tool
extends RefCounted

## Every change the editor makes to a map through a brush canvas (a stroke, «Aplanar bases»), as one step of the scene's
## undo history: it writes the before or after patches into that canvas (BrushCanvas.write), and Ctrl+S saves every canvas
## with changes. It keeps one canvas per thing painted: the ground's heights (`lattice`; the roles and the flora densities
## join in 066c and 066d). Not: what a dab does or how a canvas stores and shows it (the canvases), the mouse (BrushPainter).

## A step of `canvas` was done, undone or redone over its cells `rect`.
signal written(canvas: BrushCanvas, rect: Rect2i)

const RefreshBudget := preload("res://addons/terrain_tools/brush/refresh_budget.gd")

var budget := RefreshBudget.new()
var _undo: EditorUndoRedoManager
var _canvases: Array[BrushCanvas] = []
var _lattices := {}  ## TerrainHeights (or the Terrain while it has none) -> LatticeCanvas


func _init(undo: EditorUndoRedoManager) -> void:
	_undo = undo


## The canvas of `terrain`'s heights and voids (one per TerrainHeights, so a reopened scene finds its draft).
func lattice(terrain: Terrain) -> LatticeCanvas:
	var key: Object = terrain.heights if terrain.heights != null else terrain
	if not _lattices.has(key):
		_lattices[key] = _kept(LatticeCanvas.of(terrain, budget))
	var canvas: LatticeCanvas = _lattices[key]
	canvas.use(terrain)
	return canvas


## One undoable step named `label` on the node of `canvas`: `after` is written now and on redo, `before` on undo.
func commit(canvas: BrushCanvas, label: String, before: Array, after: Array) -> void:
	_undo.create_action(label, UndoRedo.MERGE_DISABLE, canvas.context())
	_undo.add_do_method(self, &"write", canvas, after)
	_undo.add_undo_method(self, &"write", canvas, before)
	_undo.commit_action()


## Writes `patches` into `canvas` (the undo history calls it); nothing once its node is gone.
func write(canvas: BrushCanvas, patches: Array) -> void:
	if canvas == null or not is_instance_valid(canvas.context()):
		return
	canvas.write(patches)
	written.emit(canvas, BrushCanvas.span(patches))


func has_unsaved() -> bool:
	return _canvases.any(func(canvas: BrushCanvas) -> bool: return canvas.is_dirty())


## Saves every canvas changed since the last save (each writes its file and reimports it). "" or the errors.
func save() -> String:
	var errors := PackedStringArray()
	for canvas in _canvases:
		if canvas.is_dirty():
			var error := canvas.save()
			if not error.is_empty():
				errors.append(error)
	return "\n".join(errors)


## Files the editor imported again (`resources_reimported`): the canvas saved to each drops its preview.
func reimported(paths: PackedStringArray) -> void:
	for canvas in _canvases:
		if not canvas.file().is_empty() and paths.has(canvas.file()):
			canvas.reloaded()


## Tells the editor the pictures in `folder` changed and imports heights.png again (it reads void.png beside it).
static func reimport(folder: String) -> void:
	LatticeCanvas.reimport_pictures(folder)


## Copies of the heights and voids of `terrain` as the editor has them now (a draft wins over the resource).
func arrays(terrain: Terrain) -> Array:
	return lattice(terrain).arrays()


## True when `terrain` has changes its resource does not hold yet (the ground on screen is the preview).
func has_draft(terrain: Terrain) -> bool:
	return terrain != null and lattice(terrain).has_draft()


## Hands the draft of `terrain` to its TerrainHeights, so the Terrain builds its ground again.
func rebuild(terrain: Terrain) -> void:
	lattice(terrain).rebuild()


## Drops what the editor holds for the heights of `terrain` (its pictures were just written by something else).
func forget(terrain: Terrain) -> void:
	lattice(terrain).forget()


func _kept(canvas: BrushCanvas) -> BrushCanvas:
	_canvases.append(canvas)
	return canvas
