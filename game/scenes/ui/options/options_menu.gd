class_name OptionsMenu
extends CanvasLayer

## The options overlay, a TabContainer (Gráficos, Jugabilidad, Sonido) and «Cerrar». It opens from
## the boot and from the pause menu. While open it is in `WorldInput.MODAL`, so the world input
## keeps quiet; the dim eats the clicks. `pause_menu` (Esc) closes it before the pause menu sees the
## key (this layer is a later node in the tree, so its `_input` runs first). process_mode ALWAYS: it
## works over a paused match.

signal opened
signal closed


func _ready() -> void:
	%CloseOptions.pressed.connect(close)
	var tabs: TabContainer = %OptionTabs
	for i in tabs.get_tab_count():
		var title: Variant = tabs.get_tab_control(i).get("tab_title")
		if title != null:
			tabs.set_tab_title(i, tr(str(title)))


func is_open() -> bool:
	return is_in_group(WorldInput.MODAL)


func open() -> void:
	if is_open():
		return
	add_to_group(WorldInput.MODAL)
	%Dim.visible = true
	%CloseOptions.grab_focus.call_deferred()
	opened.emit()


func close() -> void:
	if not is_open():
		return
	remove_from_group(WorldInput.MODAL)
	%Dim.visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not is_open() or not event.is_action_pressed("pause_menu", false, true):
		return
	get_viewport().set_input_as_handled()
	close()
