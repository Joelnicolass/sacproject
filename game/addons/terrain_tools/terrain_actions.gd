@tool
extends RefCounted

## What the buttons of a Terrain's inspector do in the editor, each telling the result in a dialog: open the map's ground in
## Blender and bring it back (BlenderBridge, on a worker thread), write a new flat ground, level every GroundFootprint as one
## undoable step, and check the open map (MapChecks). Writing pictures always ends in a reimport. Not: the buttons
## (TerrainPanel), the arithmetic (TerrainEdits), the undo history and saving (TerrainHistory).

const BlenderBridge := preload("res://addons/terrain_tools/blender_bridge.gd")
const TerrainEdits := preload("res://addons/terrain_tools/terrain_edits.gd")
const TerrainHistory := preload("res://addons/terrain_tools/terrain_history.gd")
const MapImages := preload("res://addons/terrain_tools/map_images.gd")
const MapChecks := preload("res://tools/audit/map_checks.gd")
const EditorDialogs := preload("res://addons/terrain_tools/editor_dialogs.gd")

var _history: TerrainHistory
var _busy := false
var _task := -1  ## the Blender run on a worker thread


func _init(history: TerrainHistory) -> void:
	_history = history


## Saves what is pending, makes the .blend from the map's pictures and opens Blender on it.
func open_in_blender(terrain: Terrain) -> void:
	var folder := _ready_for_blender(terrain, "Open in Blender")
	if folder.is_empty():
		return
	if not FileAccess.file_exists(folder.path_join(MapImages.HEIGHTS_FILE)):
		EditorDialogs.say("Open in Blender", "There is no %s in %s: use «New flat ground» first." % [MapImages.HEIGHTS_FILE, folder])
		return
	_say_errors(_history.save())
	_in_background(func() -> BlenderBridge.Run: return BlenderBridge.make_blend(folder), func(run: BlenderBridge.Run) -> void:
		if not run.ok():
			EditorDialogs.say("Open in Blender: failed", run.summary())
			return
		BlenderBridge.open_blend(folder)
		EditorDialogs.say("Open in Blender", "Blender opens %s.\nMove vertices in Z only, paint the «void» group to make holes (the README text inside explains it), save in Blender (Ctrl+S) and press «Bring from Blender»." % BlenderBridge.blend_of(folder)))


## Writes the map's pictures back from its .blend and imports them again. Not undoable. When the export refuses, it says why
## and, unless already forced, offers to skip the guard against pictures changed since the .blend was made.
func bring_from_blender(terrain: Terrain, force := false) -> void:
	var folder := _ready_for_blender(terrain, "Bring from Blender")
	if folder.is_empty():
		return
	if not FileAccess.file_exists(BlenderBridge.blend_of(folder)):
		EditorDialogs.say("Bring from Blender", "There is no %s: press «Open in Blender» first." % BlenderBridge.blend_of(folder))
		return
	_in_background(func() -> BlenderBridge.Run: return BlenderBridge.export_images(folder, force), func(run: BlenderBridge.Run) -> void:
		if run.ok():
			_history.forget(terrain)
			TerrainHistory.reimport(folder)
			EditorDialogs.say("Bring from Blender", run.summary() + "\nImported again. Bake the navmesh (Nav) and validate the map.")
		elif force:
			EditorDialogs.say("Bring from Blender: refused", run.summary())
		else:
			EditorDialogs.ask("Bring from Blender: refused", run.summary() + "\n\nBring it anyway? It only skips the guard for pictures changed after opening in Blender.",
					bring_from_blender.bind(terrain, true)))


## Writes flat land at `height_m` (heights.png, no void.png) for the Terrain, after asking: it cannot be undone.
func new_flat(terrain: Terrain, height_m: float) -> void:
	var folder := TerrainEdits.folder_of(terrain)
	if folder.is_empty():
		EditorDialogs.say("New flat ground", "Save the scene first: the pictures go in its folder.")
		return
	EditorDialogs.ask("New flat ground", "Replaces %s with flat land at %.1f m and deletes %s. It cannot be undone." % [
			folder.path_join(MapImages.HEIGHTS_FILE), height_m, MapImages.VOID_FILE], func() -> void:
		var result := TerrainEdits.write_flat(folder, height_m)
		if not result.error.is_empty():
			EditorDialogs.say("New flat ground: failed", result.error)
			return
		_history.forget(terrain)
		TerrainHistory.reimport(folder)
		if terrain.heights == null:
			var undo := EditorInterface.get_editor_undo_redo()
			undo.create_action("Terrain: new flat ground", UndoRedo.MERGE_DISABLE, terrain)
			undo.add_do_property(terrain, &"heights", load(folder.path_join(MapImages.HEIGHTS_FILE)))
			undo.add_undo_property(terrain, &"heights", null)
			undo.commit_action()
		EditorDialogs.say("New flat ground", "Done: %s." % ", ".join(result.written)))


## Levels the land under every GroundFootprint of the open scene, as one step Ctrl+Z undoes; Ctrl+S writes heights.png.
func level_bases(terrain: Terrain) -> void:
	if terrain.heights == null or not terrain.heights.is_valid():
		EditorDialogs.say("Flatten bases", "This Terrain has no heights (heights.png): use «New flat ground».")
		return
	var now := _history.arrays(terrain)
	var edit := TerrainEdits.level_bases(EditorInterface.get_edited_scene_root(), terrain, now[0], now[1])
	var after: Array[BrushStroke.Patch] = edit["after"]
	if after.is_empty():
		EditorDialogs.say("Flatten bases", "The scene has no GroundFootprint (the base of an altar or a manafount).")
		return
	_history.commit(_history.lattice(terrain), "Terrain: flatten bases", edit["before"], after)
	EditorDialogs.say("Flatten bases", "%d bases levelled. Ctrl+Z undoes it; Ctrl+S writes heights.png." % after.size())


## Checks the open map as check_map does (seats, things on land, level bases, altar to fount on the navmesh).
func validate(terrain: Terrain) -> void:
	var root := EditorInterface.get_edited_scene_root() as MapRoot
	if root == null:
		EditorDialogs.say("Validate map", "The open scene is not a map (its root is not a MapRoot).")
		return
	if _history.has_unsaved():
		_history.rebuild(terrain)
		terrain.heights = terrain.heights  # builds the ground from the heights now, so the checks read the edited land
	var tag := StringName(root.scene_file_path.get_base_dir().get_file())
	var catalog := MapCatalog.shared()
	var problems: Array[String] = await MapChecks.check(root, catalog.find(tag) if catalog.has(tag) else null)
	if problems.is_empty():
		EditorDialogs.say("Validate map: PASS", "No problems.")
	else:
		EditorDialogs.say("Validate map: FAIL (%d)" % problems.size(), "\n".join(PackedStringArray(problems)))


func _ready_for_blender(terrain: Terrain, title: String) -> String:
	var folder := TerrainEdits.folder_of(terrain)
	if BlenderBridge.find().is_empty():
		EditorDialogs.say(title, BlenderBridge.HOW_TO)
		return ""
	if folder.is_empty() or _busy:
		EditorDialogs.say(title, "Save the scene first." if folder.is_empty() else "Blender is still working.")
		return ""
	return folder


## Runs `work` on a worker thread and `done` with its result on the main thread.
func _in_background(work: Callable, done: Callable) -> void:
	_busy = true
	_task = WorkerThreadPool.add_task(func() -> void: _finished.call_deferred(work.call(), done), false, "Blender")


func _finished(result: Variant, done: Callable) -> void:
	WorkerThreadPool.wait_for_task_completion(_task)
	_busy = false
	done.call(result)


func _say_errors(errors: String) -> void:
	if not errors.is_empty():
		EditorDialogs.say("Terrain: could not save", errors)
