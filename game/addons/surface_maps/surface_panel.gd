@tool
extends VBoxContainer

## The «Relieve desde albedo» section of a material's (or ground role's) inspector: the recipe's knobs, the albedo beside
## its relief (a live preview while the knobs move), «Generar» (bake, write the PNGs that are missing, import them and
## assign them in one undo step) and «Quitar» (takes the maps off in one undo step; the PNGs stay on disk). A PNG that
## exists is only replaced with «Sobrescribir». Not: the pixels (ReliefBaker), the files (MapWriter), the recipe's
## lifetime (the plugin keeps one per editor session).

const ReliefJob := preload("res://addons/surface_maps/relief_job.gd")

## Open or folded, the same for every material this session (the inspector rebuilds the section on each change).
static var _open := false
## The last result line, kept for the target it belongs to while the inspector rebuilds after an assign.
static var _note := {"id": 0, "text": ""}

var _target: Resource
var _recipe: ReliefRecipe
var _undo: EditorUndoRedoManager


func setup(target: Resource, recipe: ReliefRecipe, undo: EditorUndoRedoManager) -> void:
	_target = target
	_recipe = recipe
	_undo = undo


func _ready() -> void:
	if _target == null:
		return
	%Header.button_pressed = _open
	%Body.visible = _open
	%Header.toggled.connect(_on_header_toggled)
	%Form.recipe = _recipe
	%Form.edited.connect(%PreviewDelay.start)
	%PreviewDelay.timeout.connect(_show_preview)
	%Preview.pressed.connect(_show_preview)
	%Generate.pressed.connect(_generate)
	%Clear.pressed.connect(_clear)
	_refresh()


func _on_header_toggled(on: bool) -> void:
	_open = on
	%Body.visible = on


func _refresh() -> void:
	var readable := ReliefJob.has_source(_target)
	%Albedo.texture = MapWriter.albedo_of(_target)
	%Normal.texture = _assigned("normal")
	%Preview.disabled = not readable
	%Generate.disabled = not readable
	%Clear.disabled = _assigned("normal") == null and _assigned("orm") == null
	if _note.id == _target.get_instance_id():
		%Status.text = _note.text
	elif not readable:
		%Status.text = "Sin textura de albedo en un archivo: no hay de dónde sacar el relieve."
	else:
		var names := PackedStringArray()
		for path: String in MapWriter.existing(_target).values():
			names.append(path.get_file())
		if not names.is_empty():
			%Status.text = "Mapas en disco: %s" % ", ".join(names)
		else:
			%Status.text = "Sin mapas todavía. Generar escribe %s" % MapWriter.map_path(MapWriter.albedo_of(_target).resource_path, "normal")


## The texture the target carries for map `key` ("normal" or "orm"); null when it has none.
func _assigned(key: String) -> Texture2D:
	if _target is BaseMaterial3D:
		var material := _target as BaseMaterial3D
		return material.normal_texture if key == "normal" else material.ao_texture
	return _target.get(key) as Texture2D if key in _target else null


## Bakes with the current knobs and shows the normal, without writing anything.
func _show_preview() -> void:
	var image := MapWriter.albedo_image(_target)
	if image == null:
		return
	var maps := ReliefBaker.bake(image, _recipe)
	%Normal.texture = ImageTexture.create_from_image(maps["normal"] as Image)
	%Status.text = "Vista previa (sin guardar). Generar la escribe y la asigna."


func _generate() -> void:
	var written := ReliefJob.write_maps(_target, _recipe, %Overwrite.button_pressed)
	MapWriter.import_in_editor(written)
	var paths := ReliefJob.on_disk(_target, _recipe)
	var text := ""
	if paths.is_empty():
		text = "No se pudo escribir el mapa (mirá la salida del editor)."
	elif MapWriter.assign(_target, paths, _undo):
		text = "Asignado: %s. %s Guardá con Ctrl+S; Ctrl+Z lo deshace." % [", ".join(PackedStringArray(paths.keys())),
			"Escritos %d PNG." % written.size() if not written.is_empty() else "Se usaron los PNG que ya estaban (Sobrescribir los rehace)."]
	else:
		text = "Los PNG están en disco pero todavía no se importaron; probá de nuevo en un momento."
	_set_note(text)


func _clear() -> void:
	if MapWriter.clear(_target, _undo):
		_set_note("Mapas quitados del material (los PNG quedan en disco). Ctrl+Z lo deshace.")


func _set_note(text: String) -> void:
	_note = {"id": _target.get_instance_id(), "text": text}
	_refresh()
