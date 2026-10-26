@tool
extends ConfirmationDialog

## Project > Tools > «Generar relieve…»: the relief of many materials at once. Takes the .tres of the folders (not their
## subfolders) and the files written in «Qué», or the files and folders selected in the FileSystem dock; bakes the maps
## that are missing with the session's recipe, imports them in one go, assigns them and saves each material.
## «Saltear existentes» leaves a material whose maps are all on disk untouched; a PNG is only replaced with «Sobrescribir».
## «Detener» stops after the current material (what was written is still imported and assigned). No undo: the materials
## are saved to disk, so git or «Quitar» take it back. Not: the pixels (ReliefBaker), the files (MapWriter), one material
## at a time (the inspector section).

const ReliefJob := preload("res://addons/surface_maps/relief_job.gd")
const MATERIAL_EXTENSIONS := ["tres", "res", "material"]

## The session's recipe (the plugin's); the same one the inspector sections edit.
var recipe: ReliefRecipe

var _running := false
var _stopping := false


func _ready() -> void:
	get_ok_button().text = "Generar"
	get_cancel_button().text = "Cerrar"
	%Form.recipe = recipe
	%Browse.pressed.connect(func() -> void: %FolderPicker.popup_centered_ratio(0.6))
	%FolderPicker.dir_selected.connect(func(dir: String) -> void: %Paths.text = dir)
	%UseSelection.pressed.connect(func() -> void: %Paths.text = ", ".join(EditorInterface.get_selected_paths()))
	%Overwrite.toggled.connect(_on_overwrite_toggled)
	%Stop.pressed.connect(func() -> void: _stopping = true)
	confirmed.connect(_run)
	canceled.connect(func() -> void: _stopping = true)


func _on_overwrite_toggled(on: bool) -> void:
	%Skip.disabled = on
	if on:
		%Skip.button_pressed = false


func _run() -> void:
	if _running:
		return
	var targets := _targets()
	if targets.is_empty():
		%Status.text = "No hay materiales con un albedo en archivo en lo elegido."
		return
	_set_running(true)
	%Progress.max_value = targets.size()
	var overwrite: bool = %Overwrite.button_pressed
	var written := PackedStringArray()
	var touched: Array[Resource] = []
	var skipped := 0
	for i in targets.size():
		if _stopping:
			break
		var target := targets[i]
		%Progress.value = i
		%Status.text = "Generando %d/%d: %s" % [i + 1, targets.size(), target.resource_path.get_file()]
		await get_tree().process_frame
		if %Skip.button_pressed and ReliefJob.complete(target, recipe):
			skipped += 1
			continue
		written.append_array(ReliefJob.write_maps(target, recipe, overwrite))
		touched.append(target)
	%Status.text = "Importando %d mapas…" % written.size()
	await get_tree().process_frame
	MapWriter.import_in_editor(written)
	var saved := 0
	var unsaved := 0
	for target in touched:
		if MapWriter.assign(target, ReliefJob.on_disk(target, recipe)):
			if _save(target):
				saved += 1
			else:
				unsaved += 1
	%Progress.value = targets.size()
	%Status.text = "%d PNG escritos · %d materiales asignados y guardados · %d salteados%s%s." % [written.size(), saved, skipped,
		" · %d sin guardar (viven dentro de una escena: guardala)" % unsaved if unsaved > 0 else "", " · detenido" if _stopping else ""]
	_set_running(false)


func _set_running(on: bool) -> void:
	_running = on
	_stopping = false
	get_ok_button().disabled = on
	%Stop.visible = on


## Every material of the paths in «Qué» that has an albedo picture to read.
func _targets() -> Array[Resource]:
	var out: Array[Resource] = []
	for entry in %Paths.text.split(",", false):
		for file in _files_of(entry.strip_edges()):
			var target := load(file) as Resource
			if target != null and ReliefJob.has_source(target):
				out.append(target)
	return out


## The file at `path`, or the material files directly inside the folder `path`.
func _files_of(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(path):
		if path.get_extension() in MATERIAL_EXTENSIONS:
			out.append(path)
		return out
	var dir := path.trim_suffix("/") + "/"
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() in MATERIAL_EXTENSIONS:
			out.append(dir + file)
	return out


## Saves the file that holds the target: itself, or the .tres / .res it is embedded in. A target inside a scene is left
## for the scene's own save (false).
static func _save(target: Resource) -> bool:
	var file := target.resource_path.get_slice("::", 0)
	if file.is_empty() or file.get_extension() in ["tscn", "scn"]:
		return false
	var holder := target if file == target.resource_path else load(file) as Resource
	return holder != null and ResourceSaver.save(holder) == OK
