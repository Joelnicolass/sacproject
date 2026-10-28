class_name RtsOrderButton
extends Node

## The one owner of the order button (`order_action`, the right button) in the world. A press and
## release is the order of always (RtsOrderInput.right_at); one that ends a camera drag orders nothing.
## With a `menu` (an RtsOrderMenu: the kit's RtsRadialMenu, or a game's own), holding the button still
## for `menu.hold_s` opens it where the press started, and the entry chosen on release runs AT THE
## PRESS POINT (RtsOrderInput.run_entry); holding `menu_action` (Tab) opens it at the pointer and
## releasing runs the entry. Without a menu there is no hold: every press is a plain right click.

@export var order_action: StringName = &"rts_order"
@export var menu_action: StringName = &"rts_order_menu"
## Optional. Empty: no menu, no hold.
@export var menu: RtsOrderMenu
## The Control that takes the world's clicks. Empty: unhandled input.
@export var view: Control
@export var order_input: RtsOrderInput
@export var pointer: RtsPointer

enum Source { NONE, MOUSE, KEY }

var _source := Source.NONE
var _down := false
var _held_s := 0.0
var _press_at := Vector2.ZERO
var _origin := Vector2.ZERO
var _pointer := Vector2.ZERO


func _get_configuration_warnings() -> PackedStringArray:
	if order_input == null or pointer == null:
		return PackedStringArray(["Assign order_input and pointer."])
	return PackedStringArray()


func _ready() -> void:
	if view:
		view.gui_input.connect(_on_view_event)
	if menu:
		menu.entry_chosen.connect(_on_entry_chosen)


func is_open() -> bool:
	return menu != null and menu.is_open()


## The pointer, seen before the world and the HUD (an open menu follows it).
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_pointer = (event as InputEventMouseMotion).position
		if is_open():
			menu.point_at(_pointer)


func _unhandled_input(event: InputEvent) -> void:
	if view == null:
		_on_view_event(event)


func _process(delta: float) -> void:
	if RtsWorldInput.blocked(self):
		if is_open():
			menu.cancel()
		_reset()
		return
	if menu == null:
		return
	if _down and _source != Source.KEY:
		_held_s += delta
		if not is_open() and _held_s >= menu.hold_s and not _dragged():
			_open(Source.MOUSE, _press_at)
	_poll_key(delta)


## The menu key: held `hold_s` opens the menu at the pointer, released runs the entry.
func _poll_key(delta: float) -> void:
	if not InputMap.has_action(menu_action):
		return
	var down := Input.is_action_pressed(menu_action)
	if down and _source == Source.NONE and not _down:
		_held_s += delta
		if _held_s >= menu.hold_s:
			_open(
				Source.KEY,
				get_viewport().get_mouse_position() if _pointer == Vector2.ZERO else _pointer
			)
	elif not down and _source == Source.KEY:
		menu.point_at(_pointer)
		menu.confirm()
		_reset()
	elif not down and _source == Source.NONE and not _down:
		_held_s = 0.0


func _on_view_event(event: InputEvent) -> void:
	if not event is InputEventMouseButton or RtsWorldInput.blocked(self):
		return
	var button := event as InputEventMouseButton
	if not button.is_action(order_action):
		return
	if button.pressed:
		if _source == Source.KEY:
			return
		_down = true
		_held_s = 0.0
		_press_at = button.position
		_pointer = button.position
		return
	if not _down:
		return
	if is_open() and _source == Source.MOUSE:
		menu.point_at(button.position)
		menu.confirm()
	elif not _dragged() and order_input:
		order_input.right_at(button.position)
	_reset()


func _open(source: Source, at: Vector2) -> void:
	_source = source
	_origin = at
	menu.open_at(at, order_input.context_kind(at) if order_input else &"")
	menu.point_at(_pointer)


func _reset() -> void:
	_source = Source.NONE
	_down = false
	_held_s = 0.0


func _dragged() -> bool:
	return pointer != null and pointer.camera_dragged()


func _on_entry_chosen(entry: RtsMenuEntry) -> void:
	if order_input:
		order_input.run_entry(entry, _origin)
