@tool
extends VBoxContainer

## The knobs of a ReliefRecipe as plain controls: a title per group and one row per field (a box for a switch, a number
## box for a range, a list for an enum). Built from the recipe's own property list, so a knob added to ReliefRecipe shows
## up here with its range. Edits the recipe it is given in place. Not: what the knobs do (ReliefBaker), where the
## recipe lives (the plugin keeps one per editor session).

signal edited

const NUMBER_WIDTH := 90.0

var recipe: ReliefRecipe:
	set(value):
		recipe = value
		if is_inside_tree():
			_build()


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if recipe == null:
		return
	for prop: Dictionary in recipe.get_property_list():
		var usage := int(prop.usage)
		if usage & PROPERTY_USAGE_GROUP:
			var title := Label.new()
			title.text = str(prop.name)
			title.add_theme_color_override("font_color", get_theme_color("accent_color", "Editor"))
			add_child(title)
		elif usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR:
			_add_row(prop)


func _add_row(prop: Dictionary) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = str(prop.name).capitalize()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(_editor_for(prop))
	add_child(row)


func _editor_for(prop: Dictionary) -> Control:
	var field := str(prop.name)
	var value: Variant = recipe.get(field)
	if int(prop.type) == TYPE_BOOL:
		var box := CheckBox.new()
		box.button_pressed = bool(value)
		box.toggled.connect(func(on: bool) -> void: _apply(field, on))
		return box
	if int(prop.hint) == PROPERTY_HINT_ENUM:
		return _enum_list(field, str(prop.hint_string), int(value))
	var spin := SpinBox.new()
	spin.custom_minimum_size.x = NUMBER_WIDTH
	var is_int := int(prop.type) == TYPE_INT
	var bounds := str(prop.hint_string).split(",")
	spin.step = 1.0 if is_int else 0.01
	if int(prop.hint) == PROPERTY_HINT_RANGE and bounds.size() >= 2:
		spin.min_value = float(bounds[0])
		spin.max_value = float(bounds[1])
		if bounds.size() >= 3 and bounds[2].is_valid_float():
			spin.step = float(bounds[2])
	spin.value = float(value)
	spin.value_changed.connect(func(number: float) -> void: _apply(field, roundi(number) if is_int else number))
	return spin


## An enum hint is "Name:value,Name:value" (or just names, numbered in order).
func _enum_list(field: String, hint: String, value: int) -> OptionButton:
	var list := OptionButton.new()
	var items := hint.split(",", false)
	for i in items.size():
		var item := items[i]
		list.add_item(item.get_slice(":", 0).capitalize(), int(item.get_slice(":", 1)) if item.contains(":") else i)
	list.select(maxi(list.get_item_index(value), 0))
	list.item_selected.connect(func(index: int) -> void: _apply(field, list.get_item_id(index)))
	return list


func _apply(field: String, value: Variant) -> void:
	recipe.set(field, value)
	edited.emit()
