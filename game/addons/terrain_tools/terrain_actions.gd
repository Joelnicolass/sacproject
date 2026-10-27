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
	var folder := _ready_for_blender(terrain, "Abrir en Blender")
	if folder.is_empty():
		return
	if not FileAccess.file_exists(folder.path_join(MapImages.HEIGHTS_FILE)):
		EditorDialogs.say("Abrir en Blender", "No hay %s en %s: usá «Suelo plano nuevo» primero." % [MapImages.HEIGHTS_FILE, folder])
		return
	_say_errors(_history.save())
	_in_background(func() -> BlenderBridge.Run: return BlenderBridge.make_blend(folder), func(run: BlenderBridge.Run) -> void:
		if not run.ok():
			EditorDialogs.say("Abrir en Blender: falló", run.summary())
			return
		BlenderBridge.open_blend(folder)
		EditorDialogs.say("Abrir en Blender", "Blender abre %s.\nMové vértices solo en Z, pintá el grupo «void» para hacer huecos (el texto README de adentro lo explica), guardá en Blender (Ctrl+S) y apretá «Traer de Blender»." % BlenderBridge.blend_of(folder)))


## Writes the map's pictures back from its .blend and imports them again. Not undoable. When the export refuses, it says why
## and, unless already forced, offers to skip the guard against pictures changed since the .blend was made.
func bring_from_blender(terrain: Terrain, force := false) -> void:
	var folder := _ready_for_blender(terrain, "Traer de Blender")
	if folder.is_empty():
		return
	if not FileAccess.file_exists(BlenderBridge.blend_of(folder)):
		EditorDialogs.say("Traer de Blender", "No hay %s: apretá «Abrir en Blender» primero." % BlenderBridge.blend_of(folder))
		return
	_in_background(func() -> BlenderBridge.Run: return BlenderBridge.export_images(folder, force), func(run: BlenderBridge.Run) -> void:
		if run.ok():
			_history.forget(terrain)
			TerrainHistory.reimport(folder)
			EditorDialogs.say("Traer de Blender", run.summary() + "\nImportado de nuevo. Horneá el navmesh (NavRegion) y validá el mapa.")
		elif force:
			EditorDialogs.say("Traer de Blender: rechazado", run.summary())
		else:
			EditorDialogs.ask("Traer de Blender: rechazado", run.summary() + "\n\n¿Traer igual? Solo salta la guardia de imágenes cambiadas después de abrir en Blender.",
					bring_from_blender.bind(terrain, true)))


## Writes flat land at `height_m` (heights.png, no void.png) for the Terrain, after asking: it cannot be undone.
func new_flat(terrain: Terrain, height_m: float) -> void:
	var folder := TerrainEdits.folder_of(terrain)
	if folder.is_empty():
		EditorDialogs.say("Suelo plano nuevo", "Guardá la escena primero: las imágenes van en su carpeta.")
		return
	EditorDialogs.ask("Suelo plano nuevo", "Reemplaza %s por tierra plana a %.1f m y borra %s. No se puede deshacer." % [
			folder.path_join(MapImages.HEIGHTS_FILE), height_m, MapImages.VOID_FILE], func() -> void:
		var result := TerrainEdits.write_flat(folder, height_m)
		if not result.error.is_empty():
			EditorDialogs.say("Suelo plano nuevo: falló", result.error)
			return
		_history.forget(terrain)
		TerrainHistory.reimport(folder)
		if terrain.heights == null:
			var undo := EditorInterface.get_editor_undo_redo()
			undo.create_action("Terreno: suelo plano nuevo", UndoRedo.MERGE_DISABLE, terrain)
			undo.add_do_property(terrain, &"heights", load(folder.path_join(MapImages.HEIGHTS_FILE)))
			undo.add_undo_property(terrain, &"heights", null)
			undo.commit_action()
		EditorDialogs.say("Suelo plano nuevo", "Listo: %s." % ", ".join(result.written)))


## Levels the land under every GroundFootprint of the open scene, as one step Ctrl+Z undoes; Ctrl+S writes heights.png.
func level_bases(terrain: Terrain) -> void:
	if terrain.heights == null or not terrain.heights.is_valid():
		EditorDialogs.say("Aplanar bases", "Este Terrain no tiene alturas (heights.png): usá «Suelo plano nuevo».")
		return
	var now := _history.arrays(terrain)
	var edit := TerrainEdits.level_bases(EditorInterface.get_edited_scene_root(), terrain, now[0], now[1])
	var after: Array[BrushStroke.Patch] = edit["after"]
	if after.is_empty():
		EditorDialogs.say("Aplanar bases", "La escena no tiene ningún GroundFootprint (la base de un altar o de un manantial).")
		return
	_history.commit(_history.lattice(terrain), "Terreno: aplanar bases", edit["before"], after)
	EditorDialogs.say("Aplanar bases", "%d bases a nivel. Ctrl+Z lo deshace; Ctrl+S escribe heights.png." % after.size())


## Checks the open map as check_map does (seats, things on land, level bases, altar to fount on the navmesh).
func validate(terrain: Terrain) -> void:
	var root := EditorInterface.get_edited_scene_root() as MapRoot
	if root == null:
		EditorDialogs.say("Validar mapa", "La escena abierta no es un mapa (su raíz no es un MapRoot).")
		return
	if _history.has_unsaved():
		_history.rebuild(terrain)
		terrain.heights = terrain.heights  # builds the ground from the heights now, so the checks read the edited land
	var tag := StringName(root.scene_file_path.get_base_dir().get_file())
	var catalog := MapCatalog.shared()
	var problems: Array[String] = await MapChecks.check(root, catalog.find(tag) if catalog.has(tag) else null)
	if problems.is_empty():
		EditorDialogs.say("Validar mapa: PASS", "Sin problemas.")
	else:
		EditorDialogs.say("Validar mapa: FAIL (%d)" % problems.size(), "\n".join(PackedStringArray(problems)))


func _ready_for_blender(terrain: Terrain, title: String) -> String:
	var folder := TerrainEdits.folder_of(terrain)
	if BlenderBridge.find().is_empty():
		EditorDialogs.say(title, BlenderBridge.HOW_TO)
		return ""
	if folder.is_empty() or _busy:
		EditorDialogs.say(title, "Guardá la escena primero." if folder.is_empty() else "Blender todavía está trabajando.")
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
		EditorDialogs.say("Terreno: no se pudo guardar", errors)
