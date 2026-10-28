class_name RadialStandalone
extends Node

## Run on its own, radial_menu.tscn opens the menu in the middle of the window, follows the mouse, a
## release chooses and it reopens. It logs (`--log=radial`, on by default here) what it hovers and
## chooses. Inert when the menu is part of a match.

@export var menu: RadialMenu


func _ready() -> void:
	set_process_input(false)
	if menu == null or get_tree().current_scene != menu:
		return
	DebugLog.enable(&"radial")
	set_process_input(true)
	menu.hovered_changed.connect(
		func(entry: RadialEntry) -> void: _log("hover " + (entry.display_label() if entry else "-"))
	)
	menu.entry_chosen.connect(func(entry: RadialEntry) -> void: _log("chosen %s" % entry.id))
	menu.cancelled.connect(func() -> void: _log("cancelled"))
	_reopen.call_deferred()


func _input(event: InputEvent) -> void:
	if not menu.is_open():
		return
	if event is InputEventMouseMotion:
		menu.point_at((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		menu.point_at((event as InputEventMouseButton).position)
		menu.confirm()
		_reopen.call_deferred()


func _reopen() -> void:
	menu.open_at(get_viewport().get_visible_rect().size * 0.5)


func _log(text: String) -> void:
	if DebugLog.on(&"radial"):
		print("RADIAL ", text)
