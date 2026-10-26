@tool
extends RefCounted

## Every change the editor makes to a map's heights (a brush stroke, «Aplanar bases»), as one step of the scene's undo
## history: it writes before or after patches (BrushStroke.Patch) into the Terrain's TerrainHeights, a new array each time
## so the Terrain builds its ground again. When that rebuild is heavy (RefreshBudget) the change stays a draft, shown by the
## preview, until `rebuild` or `save`. `save` writes the pictures of every TerrainHeights changed since (MapImages) and
## reimports them. Not: what a stroke or a levelling does (BrushStroke, TerrainEdits), drawing the preview (EditorPreview).

## The heights of `terrain` changed in the editor over the lattice `rect` (a step done, undone or redone).
signal written(terrain: Terrain, rect: Rect2i)

const MapImages := preload("res://addons/terrain_tools/map_images.gd")
const TerrainEdits := preload("res://addons/terrain_tools/terrain_edits.gd")
const RefreshBudget := preload("res://addons/terrain_tools/brush/refresh_budget.gd")

var budget := RefreshBudget.new()
var _undo: EditorUndoRedoManager
var _drafts := {}  ## TerrainHeights -> [PackedFloat32Array, PackedByteArray] not yet handed to it
var _unsaved := {}  ## TerrainHeights -> folder of its pictures


func _init(undo: EditorUndoRedoManager) -> void:
	_undo = undo


## Copies of the heights and voids as the editor has them now (a draft wins over the resource).
func arrays(terrain: Terrain) -> Array:
	var source := terrain.heights
	var now: Array = _drafts.get(source, [source.heights_m, source.void_mask])
	return [(now[0] as PackedFloat32Array).duplicate(), (now[1] as PackedByteArray).duplicate()]


## One undoable step named `label`: `after` is written now and on redo, `before` on undo (each in order).
func commit(terrain: Terrain, label: String, before: Array[BrushStroke.Patch], after: Array[BrushStroke.Patch]) -> void:
	_undo.create_action(label, UndoRedo.MERGE_DISABLE, terrain)
	_undo.add_do_method(self, &"write", terrain, after)
	_undo.add_undo_method(self, &"write", terrain, before)
	_undo.commit_action()


## Writes `patches` into the heights of `terrain` (the undo history calls it).
func write(terrain: Terrain, patches: Array[BrushStroke.Patch]) -> void:
	if not is_instance_valid(terrain) or terrain.heights == null or not terrain.heights.is_valid():
		return
	var now := arrays(terrain)
	var rect := Rect2i()
	for patch in patches:
		patch.write(now[0], now[1])
		rect = rect.merge(patch.rect) if rect.has_area() else patch.rect
	_unsaved[terrain.heights] = TerrainEdits.folder_of(terrain)
	if budget.is_light(terrain):
		_hand(terrain.heights, now)
	else:
		_drafts[terrain.heights] = now
	written.emit(terrain, rect)


## True when `terrain` has changes the resource does not hold yet (the ground on screen is the preview).
func has_draft(terrain: Terrain) -> bool:
	return terrain != null and _drafts.has(terrain.heights)


## Hands the draft of `terrain` to its TerrainHeights, so the Terrain builds its ground again (the editor waits for it).
func rebuild(terrain: Terrain) -> void:
	if has_draft(terrain):
		_hand(terrain.heights, _drafts[terrain.heights])


## Drops what the editor holds for the heights of `terrain` (its pictures were just written by something else).
func forget(terrain: Terrain) -> void:
	if terrain.heights != null:
		_drafts.erase(terrain.heights)
		_unsaved.erase(terrain.heights)


func has_unsaved() -> bool:
	return not _unsaved.is_empty()


## Writes the pictures of every TerrainHeights changed since the last save and reimports them. "" or the errors.
func save() -> String:
	var errors := PackedStringArray()
	for heights: TerrainHeights in _unsaved.keys():
		if _drafts.has(heights):
			_hand(heights, _drafts[heights])
		var folder: String = _unsaved[heights]
		var result := MapImages.write(heights, folder)
		if not result.error.is_empty():
			errors.append(result.error)
		elif not result.written.is_empty():
			reimport.call_deferred(folder)
	_unsaved.clear()
	return "\n".join(errors)


## Tells the editor the pictures in `folder` changed and imports heights.png again (it reads void.png beside it).
static func reimport(folder: String) -> void:
	var files := EditorInterface.get_resource_filesystem()
	var heights := folder.path_join(MapImages.HEIGHTS_FILE)
	var voids := folder.path_join(MapImages.VOID_FILE)
	files.update_file(voids)
	files.update_file(heights)
	var stale := PackedStringArray([heights])
	if FileAccess.file_exists(voids):
		stale.append(voids)
	files.reimport_files(stale)


func _hand(heights: TerrainHeights, now: Array) -> void:
	_drafts.erase(heights)
	heights.heights_m = now[0]
	heights.void_mask = now[1]
