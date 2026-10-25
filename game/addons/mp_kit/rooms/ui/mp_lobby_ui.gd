class_name MpLobbyUi
extends RefCounted

## The controls of MpLobbyScreen, built by code (three pages: connect, rooms, room; and a status line) and wired to
## its public methods. Plain Godot controls, so the project's Theme styles them. Not: lobby logic (MpLobbyScreen).

var _screen: MpLobbyScreen
var _pages: Dictionary = {}
var _status: Label
var _name: LineEdit
var _address: LineEdit
var _rooms: ItemList
var _room_name: LineEdit
var _private: CheckBox
var _code: LineEdit
var _room_title: Label
var _seats: ItemList
var _ready: CheckButton
var _rejoin: Button
var _chat: ItemList
var _chat_line: LineEdit


func _init(screen: MpLobbyScreen) -> void:
	_screen = screen
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var box := _vbox(center)
	var title := Label.new()
	title.text = screen.title_text
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_build_connect(box)
	_build_rooms(box)
	_build_room(box)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(420, 0)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)


func show_page(page: StringName) -> void:
	for key in _pages:
		(_pages[key] as Control).visible = key == page


func set_status(text: String) -> void:
	_status.text = text


func set_rooms(lines: PackedStringArray) -> void:
	_rooms.clear()
	for line in lines:
		_rooms.add_item(line)


func set_room(title: String, seat_lines: PackedStringArray) -> void:
	_room_title.text = title
	_seats.clear()
	for line in seat_lines:
		_seats.add_item(line)


func show_rejoin(on: bool) -> void:
	_rejoin.visible = on


func add_chat(line: String) -> void:
	_chat.add_item(line)
	_chat.ensure_current_is_visible()


func _build_connect(parent: Control) -> void:
	var page := _page(parent, &"connect")
	_name = _line(page, _screen.player_name)
	_address = _line(page, _screen.default_address())
	var row := _hbox(page)
	_button(row, _screen.connect_text, func() -> void: _screen.connect_lobby(_address.text, _name.text))
	_button(row, _screen.back_text, _screen.go_back)


func _build_rooms(parent: Control) -> void:
	var page := _page(parent, &"rooms")
	_rooms = ItemList.new()
	_rooms.custom_minimum_size = Vector2(420, 140)
	_rooms.item_activated.connect(_screen.join_listed)
	page.add_child(_rooms)
	var row := _hbox(page)
	_button(row, _screen.join_text, func() -> void:
		var picked := _rooms.get_selected_items()
		if not picked.is_empty():
			_screen.join_listed(picked[0]))
	_button(row, _screen.refresh_text, _screen.refresh)
	_button(row, _screen.back_text, _screen.go_back)
	var create := _hbox(page)
	_room_name = _line(create, "Room")
	_private = CheckBox.new()
	_private.text = _screen.private_text
	create.add_child(_private)
	_button(create, _screen.create_text, func() -> void: _screen.create_room(_room_name.text, _private.button_pressed))
	var by_code := _hbox(page)
	_code = _line(by_code, "")
	_code.placeholder_text = "ABCD"
	_button(by_code, _screen.join_code_text, func() -> void: _screen.join_code(_code.text))


func _build_room(parent: Control) -> void:
	var page := _page(parent, &"room")
	_room_title = Label.new()
	_room_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_room_title)
	_seats = ItemList.new()
	_seats.custom_minimum_size = Vector2(420, 100)
	page.add_child(_seats)
	var row := _hbox(page)
	_ready = CheckButton.new()
	_ready.text = _screen.ready_text
	_ready.toggled.connect(_screen.set_ready)
	row.add_child(_ready)
	_button(row, _screen.leave_text, func() -> void:
		_ready.set_pressed_no_signal(false)
		_screen.leave_room())
	_rejoin = _button(row, _screen.rejoin_text, _screen.rejoin_match)
	_rejoin.visible = false
	_chat = ItemList.new()
	_chat.custom_minimum_size = Vector2(420, 90)
	page.add_child(_chat)
	var say := _hbox(page)
	_chat_line = _line(say, "")
	_chat_line.text_submitted.connect(func(text: String) -> void:
		_screen.send_chat(text)
		_chat_line.clear())
	_button(say, _screen.send_text, func() -> void:
		_screen.send_chat(_chat_line.text)
		_chat_line.clear())


func _page(parent: Control, key: StringName) -> VBoxContainer:
	var page := _vbox(parent)
	page.visible = false
	_pages[key] = page
	return page


func _vbox(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)
	return box


func _hbox(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	return row


func _line(parent: Control, text: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.custom_minimum_size = Vector2(200, 0)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(edit)
	return edit


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button
