@tool
extends AcceptDialog

## Project > Tools > MpKit: Setup game... A few choices, the list of files that will be written ([+] new, [~] exists:
## then nothing is written), and Create. Writes with MpSetupWizard and opens the new boot scene. Not: the generation.

signal created(boot_path: String)

var _folder: LineEdit
var _dimension: OptionButton
var _players: SpinBox
var _transport: OptionButton
var _rooms: CheckBox
var _private: CheckBox
var _main: CheckBox
var _files: Label


func _init() -> void:
	title = "MpKit: setup a multiplayer game"
	ok_button_text = "Create"
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	add_child(box)
	_folder = _row(box, "Folder", LineEdit.new()) as LineEdit
	_folder.text = "res://game"
	_dimension = _row(box, "World", OptionButton.new()) as OptionButton
	_dimension.add_item("2D")
	_dimension.add_item("3D")
	_players = _row(box, "Max players", SpinBox.new()) as SpinBox
	_players.min_value = 1
	_players.max_value = 64
	_players.value = 4
	_transport = _row(box, "Transport", OptionButton.new()) as OptionButton
	_transport.add_item("ENet (UDP, desktop)")
	_transport.add_item("WebSocket (TCP, web builds)")
	_rooms = _check(box, "Online rooms (room server + lobby screen)", true)
	_private = _check(box, "Private server button (match on this PC with a code)", true)
	_main = _check(box, "Make the boot scene the main scene", true)
	var files_title := Label.new()
	files_title.text = "Files:"
	box.add_child(files_title)
	_files = Label.new()
	box.add_child(_files)
	for control in [_folder, _dimension, _players, _transport, _rooms]:
		var refresh := func(_a: Variant = null) -> void: _show_plan()
		if control is LineEdit:
			control.text_changed.connect(refresh)
		elif control is OptionButton:
			control.item_selected.connect(refresh)
		elif control is SpinBox:
			control.value_changed.connect(refresh)
		else:
			control.toggled.connect(refresh)
	confirmed.connect(_on_create)
	about_to_popup.connect(_show_plan)


func wizard() -> MpSetupWizard:
	var w := MpSetupWizard.new()
	w.folder = _folder.text.strip_edges().trim_suffix("/")
	w.dimension_3d = _dimension.selected == 1
	w.max_players = int(_players.value)
	w.transport = "ws" if _transport.selected == 1 else "enet"
	w.online_rooms = _rooms.button_pressed
	w.private_server = _private.button_pressed
	return w


func _show_plan() -> void:
	var w := wizard()
	_files.text = w.plan_text()
	get_ok_button().disabled = not w.folder.begins_with("res://") or _files.text.contains("[~]")


func _on_create() -> void:
	var w := wizard()
	var err := w.write()
	if err != OK:
		push_error("MpKit: setup failed (%s)" % error_string(err))
		return
	var boot := w.folder.path_join(MpSetupWizard.BOOT)
	if _main.button_pressed:
		ProjectSettings.set_setting("application/run/main_scene", boot)
		ProjectSettings.save()
	created.emit(boot)


func _row(box: VBoxContainer, label_text: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	box.add_child(row)
	return control


func _check(box: VBoxContainer, text: String, on: bool) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.button_pressed = on
	box.add_child(check)
	return check
