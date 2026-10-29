class_name PropertyRow
extends HBoxContainer

## One editable value of an options list (Avanzado, Arte), made from a property's description (an
## entry of `Object.get_property_list()` or `Shader.get_shader_uniform_list()`): a check for a bool,
## a list for an enum, a slider for a number with a range (a spin box without one), a color button
## for a color. Anything else is not editable and `is_supported` says so. «↺» puts the default back
## (the list decides what that is); the row shows it changed (`set_changed`).

signal edited(property: StringName, value: Variant)
signal reset_requested(property: StringName)

var property: StringName
var _type := TYPE_NIL
var _editor: Control
var _value_label: Label
var _reset: Button
var _name_label: Label


## A row for `info` (name, type, hint, hint_string) titled `title`, showing `value`.
static func make(info: Dictionary, title: String, value: Variant) -> PropertyRow:
	var row := PropertyRow.new()
	row._build(info, title)
	row.show_value(value)
	return row


static func is_supported(info: Dictionary) -> bool:
	return int(info.get("type", TYPE_NIL)) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_COLOR]


## `fog_density` → «Fog density».
static func humanize(name: String) -> String:
	var words := name.replace("_", " ").strip_edges()
	return words.substr(0, 1).to_upper() + words.substr(1)


func _build(info: Dictionary, title: String) -> void:
	property = StringName(info["name"])
	_type = int(info["type"])
	_name_label = Label.new()
	_name_label.text = title
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.clip_text = true
	_name_label.tooltip_text = String(property)
	_name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_name_label)
	var hint := int(info.get("hint", PROPERTY_HINT_NONE))
	var hint_string := str(info.get("hint_string", ""))
	if _type == TYPE_BOOL:
		var check := CheckBox.new()
		check.toggled.connect(func(on: bool) -> void: edited.emit(property, on))
		_editor = check
	elif _type == TYPE_COLOR:
		var color := ColorPickerButton.new()
		color.custom_minimum_size = Vector2(80, 0)
		color.edit_alpha = false
		color.color_changed.connect(func(c: Color) -> void: edited.emit(property, c))
		_editor = color
	elif hint == PROPERTY_HINT_ENUM and _type == TYPE_INT:
		var pick := OptionButton.new()
		var next := 0
		var items := hint_string.split(",", false)
		var names := PackedStringArray()
		for part in items:
			names.append(part.split(":")[0].strip_edges())
		var shared := _shared_words(names)
		for index in items.size():
			var pieces := items[index].split(":")
			var id := int(pieces[1]) if pieces.size() > 1 else next
			pick.add_item(" ".join(names[index].split(" ").slice(shared)), id)
			next = id + 1
		pick.item_selected.connect(
			func(index: int) -> void: edited.emit(property, pick.get_item_id(index))
		)
		_editor = pick
	else:
		_editor = _number(hint, hint_string)
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_editor)
	_reset = Button.new()
	_reset.text = "↺"
	_reset.flat = true
	_reset.tooltip_text = tr("UI_ADVANCED_RESET")
	_reset.pressed.connect(func() -> void: reset_requested.emit(property))
	add_child(_reset)


# How many leading words every name shares («Msaa Disabled», «Msaa 2x» → 1), never all of one.
static func _shared_words(names: PackedStringArray) -> int:
	if names.size() < 2:
		return 0
	var first := names[0].split(" ")
	var count := 0
	while count < first.size() - 1:
		var word := first[count]
		var all_share := true
		for name in names:
			var words := name.split(" ")
			if words.size() <= count + 1 or words[count] != word:
				all_share = false
				break
		if not all_share:
			break
		count += 1
	return count


func _number(hint: int, hint_string: String) -> Control:
	var low := -1000.0
	var high := 1000.0
	var step := 1.0 if _type == TYPE_INT else 0.001
	var ranged := false
	if hint == PROPERTY_HINT_RANGE:
		var parts := hint_string.split(",", false)
		if parts.size() >= 2 and parts[0].is_valid_float() and parts[1].is_valid_float():
			low = float(parts[0])
			high = float(parts[1])
			ranged = true
		if parts.size() >= 3 and parts[2].is_valid_float():
			step = float(parts[2])
	if not ranged:
		var spin := SpinBox.new()
		spin.min_value = low
		spin.max_value = high
		spin.step = step
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.value_changed.connect(_on_number)
		return spin
	var box := HBoxContainer.new()
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_on_number)
	box.add_child(slider)
	_value_label = Label.new()
	_value_label.custom_minimum_size = Vector2(52, 0)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_value_label)
	return box


func _on_number(value: float) -> void:
	_show_number(value)
	edited.emit(property, roundi(value) if _type == TYPE_INT else value)


func _show_number(value: float) -> void:
	if _value_label != null:
		_value_label.text = str(roundi(value)) if _type == TYPE_INT else "%.3f" % value


## Shows `value` without emitting `edited`.
func show_value(value: Variant) -> void:
	if value == null:
		return
	if _editor is CheckBox:
		(_editor as CheckBox).set_pressed_no_signal(bool(value))
	elif _editor is ColorPickerButton:
		(_editor as ColorPickerButton).color = value
	elif _editor is OptionButton:
		var pick := _editor as OptionButton
		pick.select(pick.get_item_index(int(value)))
	elif _editor is SpinBox:
		(_editor as SpinBox).set_value_no_signal(float(value))
	else:
		var slider := _editor.get_child(0) as HSlider
		slider.set_value_no_signal(float(value))
		_show_number(float(value))


## Marks the row as set by the player (its title in the accent color, «↺» enabled).
func set_changed(changed: bool) -> void:
	_reset.disabled = not changed
	_name_label.modulate = Color(1.0, 0.85, 0.45) if changed else Color.WHITE
