@tool
extends EditorPlugin

## RFC-046 (F271): the bakes and the validator from the editor, so the day to day needs no terminal. Each entry of
## Project > Tools starts the same command the CLI documents (a headless child Godot on this project) and shows its output
## in a dialog. The CLI tools keep working as they were. Dev only: the export excludes `addons/sacrifice_tools/*`.

const ITEMS := [
	{"title": "Sacrifice: Validar catálogo", "args": ["--script", "res://debug/suite/catalog_cases.gd"], "rescan": false},
	{"title": "Sacrifice: Re-hornear navmesh", "args": ["res://tools/bake/bake_nav.tscn"], "rescan": true},
	{"title": "Sacrifice: Hornear modelos que faltan", "args": ["--script", "res://tools/bake/bake_body_scenes.gd"], "rescan": true,
		"about": "Crea la escena de cuerpo (.tscn) de cada modelo ya importado (assets/original/models/*.glb) que todavía no tiene una. No pisa las existentes. NO necesita el juego original: usa los modelos que ya están en el repo."},
	# RFC-051: asks for a .glb of assets/custom/models/ and passes it to the tool.
	{"title": "Sacrifice: Nueva criatura desde modelo…", "args": ["--script", "res://tools/bake/new_creature.gd", "--"], "rescan": true, "pick": "glb"},
	{"title": "Sacrifice: Sincronizar criatura con su modelo…", "args": ["--script", "res://tools/bake/new_creature.gd", "--", "--sync"], "rescan": true, "pick": "glb"},
]
# Entries with "original": true read the ORIGINAL game (not in the repo); their label says so. "exe": the command is that program
# (not this Godot) and "args" are paths relative to the project. SETTING_INSTALL is passed to every child process as SAC_INSTALL.
const ITEMS_ORIGINAL := [
	{"title": "Sacrifice: Listar mapas del original", "exe": "python3", "args": ["tools/import/import_map.py", "--list"], "rescan": false,
		"original": true, "about": "Lista los mapas (.scp) del juego original instalado."},
]
const CUSTOM_MODELS := "res://assets/custom/models/"
const SETTING_INSTALL := "sacrifice/original_install_path"
const LABEL_ORIGINAL := " (requiere juego original)"

var _dialog: AcceptDialog
var _picker: EditorFileDialog
var _picking: Dictionary = {}
var _log: TextEdit
var _timer: Timer
var _pipe: FileAccess
var _err: FileAccess
var _pid := -1
var _rescan := false
var _items: Array = []
var _env_set := false


func _enter_tree() -> void:
	_register_settings()
	_items = ITEMS + ITEMS_ORIGINAL
	for item: Dictionary in _items:
		add_tool_menu_item(_label(item), _run.bind(item))
	_dialog = AcceptDialog.new()
	_dialog.title = "Sacrifice"
	_dialog.min_size = Vector2i(760, 420)
	_log = TextEdit.new()
	_log.editable = false
	_log.custom_minimum_size = Vector2(720, 340)
	_dialog.add_child(_log)
	EditorInterface.get_base_control().add_child(_dialog)
	_picker = EditorFileDialog.new()
	_picker.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_picker.access = EditorFileDialog.ACCESS_RESOURCES
	_picker.title = "Elegí el modelo (.glb) de la criatura"
	_picker.add_filter("*.glb", "Modelo glTF")
	_picker.file_selected.connect(_on_model_picked)
	EditorInterface.get_base_control().add_child(_picker)
	_timer = Timer.new()
	_timer.wait_time = 0.2
	_timer.timeout.connect(_poll)
	add_child(_timer)


func _exit_tree() -> void:
	for item: Dictionary in _items:
		remove_tool_menu_item(_label(item))
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	if _dialog != null:
		_dialog.queue_free()
	if _picker != null:
		_picker.queue_free()


func _run(item: Dictionary) -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		_show("Ya hay una tarea corriendo; esperá a que termine.")
		return
	if item.has("pick"):
		_picking = item
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(CUSTOM_MODELS)):
			_picker.current_dir = CUSTOM_MODELS
		_picker.popup_file_dialog()
		return
	_pass_install_path()
	var exe := OS.get_executable_path()
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://")]
	if item.has("exe"):
		exe = item["exe"]
		args = PackedStringArray()
		for arg: String in item["args"]:
			args.append(ProjectSettings.globalize_path("res://" + arg))
	else:
		args.append_array(PackedStringArray(item["args"]))
	var started := OS.execute_with_pipe(exe, args)
	if started.is_empty():
		_show("No se pudo lanzar %s" % exe)
		return
	_pipe = started["stdio"]
	_err = started["stderr"]
	_pid = started["pid"]
	_rescan = item["rescan"]
	_show("%s\n%s\n(corriendo, pid %d)\n" % [item["title"], _about(item), _pid])
	_timer.start()


func _on_model_picked(path: String) -> void:
	var item := _picking.duplicate()
	item.erase("pick")
	item["args"] = PackedStringArray(item["args"]) + PackedStringArray([path])
	_run(item)


func _poll() -> void:
	_append(_pipe)
	_append(_err)
	if OS.is_process_running(_pid):
		return
	_timer.stop()
	_append(_pipe)
	_append(_err)
	_log.text += "\n-- terminó --"
	_pid = -1
	if _rescan:
		EditorInterface.get_resource_filesystem().scan()


func _append(file: FileAccess) -> void:
	if file == null or not file.is_open():
		return
	var text := ""
	while file.get_error() == OK:
		var line := file.get_line()
		if line.is_empty() and file.get_error() != OK:
			break
		text += line + "\n"
	if not text.is_empty():
		_log.text += text
		_log.scroll_vertical = _log.get_line_count()


func _show(text: String) -> void:
	_log.text = text
	_dialog.popup_centered()


## Editor setting `sacrifice/original_install_path`: the folder with the ORIGINAL game's .wad files (the same as SAC_INSTALL).
func _register_settings() -> void:
	var settings := EditorInterface.get_editor_settings()
	if not settings.has_setting(SETTING_INSTALL):
		settings.set_setting(SETTING_INSTALL, "")
	settings.set_initial_value(SETTING_INSTALL, "", false)
	settings.add_property_info({"name": SETTING_INSTALL, "type": TYPE_STRING, "hint": PROPERTY_HINT_GLOBAL_DIR})


## Child processes inherit the environment of the editor: SAC_INSTALL is read by tools/import/sac_formats/install.py.
func _pass_install_path() -> void:
	var path := str(EditorInterface.get_editor_settings().get_setting(SETTING_INSTALL)).strip_edges()
	if not path.is_empty():
		OS.set_environment("SAC_INSTALL", path)
		_env_set = true
	elif _env_set:
		OS.unset_environment("SAC_INSTALL")
		_env_set = false


func _label(item: Dictionary) -> String:
	return str(item["title"]) + (LABEL_ORIGINAL if item.get("original", false) else "")


func _about(item: Dictionary) -> String:
	var text := str(item.get("about", ""))
	if item.get("original", false):
		text += "\nRequiere el juego ORIGINAL instalado (no viene en el repo). Carpeta: Editor > Editor Settings > sacrifice > original_install_path"
		text += ", o la variable SAC_INSTALL, o tools/import/local.cfg."
	elif not text.is_empty() and not text.contains("original"):
		text += " No necesita el juego original."
	return text
