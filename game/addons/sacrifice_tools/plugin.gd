@tool
extends EditorPlugin

## RFC-046 (F271): the bakes and the validator from the editor, so the day to day needs no terminal. Each entry of
## Project > Tools starts the same command the CLI documents (a headless child Godot on this project) and shows its output
## in a dialog. The CLI tools keep working as they were. Dev only: the export excludes `addons/sacrifice_tools/*`.

const ITEMS := [
	{"title": "Sacrifice: Validar catálogo", "args": ["--script", "res://debug/suite/catalog_cases.gd"], "rescan": false},
	{"title": "Sacrifice: Re-hornear navmesh", "args": ["res://tools/bake/bake_nav.tscn"], "rescan": true},
	{"title": "Sacrifice: Hornear modelos que faltan", "args": ["--script", "res://tools/bake/bake_body_scenes.gd"], "rescan": true},
	# RFC-051: asks for a .glb of assets/custom/models/ and passes it to the tool.
	{"title": "Sacrifice: Nueva criatura desde modelo…", "args": ["--script", "res://tools/bake/new_creature.gd", "--"], "rescan": true, "pick": "glb"},
	{"title": "Sacrifice: Sincronizar criatura con su modelo…", "args": ["--script", "res://tools/bake/new_creature.gd", "--", "--sync"], "rescan": true, "pick": "glb"},
]
const CUSTOM_MODELS := "res://assets/custom/models/"

var _dialog: AcceptDialog
var _picker: EditorFileDialog
var _picking: Dictionary = {}
var _log: TextEdit
var _timer: Timer
var _pipe: FileAccess
var _err: FileAccess
var _pid := -1
var _rescan := false


func _enter_tree() -> void:
	for item: Dictionary in ITEMS:
		add_tool_menu_item(item["title"], _run.bind(item))
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
	for item: Dictionary in ITEMS:
		remove_tool_menu_item(item["title"])
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
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://")]
	args.append_array(PackedStringArray(item["args"]))
	var started := OS.execute_with_pipe(OS.get_executable_path(), args)
	if started.is_empty():
		_show("No se pudo lanzar %s" % OS.get_executable_path())
		return
	_pipe = started["stdio"]
	_err = started["stderr"]
	_pid = started["pid"]
	_rescan = item["rescan"]
	_show("%s\n(corriendo, pid %d)\n" % [item["title"], _pid])
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
