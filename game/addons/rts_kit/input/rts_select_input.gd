class_name RtsSelectInput
extends Node

## The left button in the world. A press that travels `rect_threshold_px` becomes a selection box
## (never while something is armed, with Ctrl held or while the camera drags). A click goes to what is
## armed (an order icon: RtsOrderInput; anything else: `armed_clicked` for the game); otherwise it
## selects the unit under it, shows a body that is no unit (`clicked_other`), or, a plain click on the
## ground, clears the selection (`clicked_empty`).
## Mouse events come from `view` (the Control that covers the world, so the HUD keeps its clicks);
## without one, from unhandled input.

## Something the game armed (a spell) took a left click at `screen`.
signal armed_clicked(mode: StringName, screen: Vector2)
## A left click landed on a body that is no unit of this player's to select (a building, a foe): the
## selection stays. A HUD may show it.
signal clicked_other(body: Node)
## A plain left click on the ground or on nothing cleared the selection.
signal clicked_empty

## The left button's action.
@export var select_action: StringName = &"rts_select"
## Pixels the pointer must travel before a press becomes a box.
@export var rect_threshold_px := 3.0
## The Control that takes the world's clicks. Empty: unhandled input.
@export var view: Control
@export var selection: RtsSelection
@export var pointer: RtsPointer
@export var armed: RtsArmedCommand
@export var order_input: RtsOrderInput

var _left_down := false
var _press_at := Vector2.ZERO
var _press_ctrl := false
var _rect := false


func _ready() -> void:
	if view:
		view.gui_input.connect(_on_event)
		set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	_on_event(event)


## True while the left button draws a box.
func is_boxing() -> bool:
	return _rect


## The left click at `screen`: what is armed takes it, else it selects what is there.
func left_at(screen: Vector2, shift: bool, ctrl: bool) -> void:
	if armed and armed.is_armed():
		if armed.is_order():
			if order_input:
				order_input.icon_at(screen)
		else:
			armed_clicked.emit(armed.mode, screen)
		return
	var unit := pointer.unit_under(screen)
	if unit and selection.can_select(unit):
		selection.click(unit, screen, shift, ctrl)
		return
	var body := unit.body if unit else pointer.body_under(screen)
	if body:
		clicked_other.emit(body)
	elif not shift and not ctrl:
		selection.clear()
		clicked_empty.emit()


func _on_event(event: InputEvent) -> void:
	if RtsWorldInput.blocked(self):
		_left_down = false
		_rect = false
		selection.hide_box()
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.is_action(select_action):
			return
		if button.pressed:
			_left_down = true
			_press_at = button.position
			_press_ctrl = button.ctrl_pressed or button.meta_pressed
			_rect = false
		elif _left_down:
			_left_down = false
			_release(button)
	elif event is InputEventMouseMotion and _left_down:
		var at := (event as InputEventMouseMotion).position
		var busy := (armed != null and armed.is_armed()) or pointer.camera_dragged()
		if not _rect and not busy and not _press_ctrl:
			_rect = (
				absf(at.x - _press_at.x) >= rect_threshold_px
				or absf(at.y - _press_at.y) >= rect_threshold_px
			)
		if _rect:
			selection.show_box(_press_at, at)


func _release(button: InputEventMouseButton) -> void:
	if _rect:
		_rect = false
		selection.select_rect(_press_at, button.position, button.shift_pressed)
		return
	if pointer.camera_dragged():
		return
	left_at(button.position, button.shift_pressed, button.ctrl_pressed or button.meta_pressed)
