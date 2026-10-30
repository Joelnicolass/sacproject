class_name RtsCamera2D
extends Camera2D

## The camera of a 2D RTS, with the contract of RtsCamera3D (`yaw`, `is_dragging()`, `focus()`,
## `debug_pointer`). FOLLOW: it keeps a body in the middle (Camera2D's own smoothing does the rest)
## and zooms with the wheel. FREE: it pans with the keys, the screen edges and a middle drag, zooms
## with the wheel between `min_zoom` and `max_zoom`, turns with the turn keys when `can_turn`, and
## stays inside `bounds`. The edges only work over `edge_area`; the wheel does nothing over a
## `wheel_blockers` control; nothing reads input while a modal UI is open (RtsWorldInput).

enum Mode { FOLLOW, FREE }

@export var mode := Mode.FREE:
	set(value):
		mode = value
		_dragged = false
## FOLLOW: the body kept in the middle.
@export var follow: Node2D
## Edges only work while the pointer hovers this control. Empty: anywhere.
@export var edge_area: Control
## The wheel does not zoom while the pointer is over one of these (`covers(screen)` decides when the
## control has it).
@export var wheel_blockers: Array[Control] = []
## The world rectangle the camera's center stays in; empty = anywhere.
@export var bounds := Rect2()
## FREE: the turn keys rotate the view (the camera's `ignore_rotation` is turned off).
@export var can_turn := false

@export_group("Actions")
@export var select_action: StringName = &"rts_select"
@export var order_action: StringName = &"rts_order"
@export var orbit_action: StringName = &"rts_camera_orbit"
@export var wheel_in_action: StringName = &"rts_camera_wheel_in"
@export var wheel_out_action: StringName = &"rts_camera_wheel_out"
@export var turn_left_action: StringName = &"rts_camera_turn_left"
@export var turn_right_action: StringName = &"rts_camera_turn_right"
@export var zoom_in_action: StringName = &"rts_camera_zoom_in"
@export var zoom_out_action: StringName = &"rts_camera_zoom_out"
@export var pan_left_action: StringName = &"rts_camera_pan_left"
@export var pan_right_action: StringName = &"rts_camera_pan_right"
@export var pan_up_action: StringName = &"rts_camera_pan_up"
@export var pan_down_action: StringName = &"rts_camera_pan_down"

@export_group("Motion")
@export var edge_px := 24.0
## Screen pixels per second the keys and edges pan at.
@export var pan_speed := 900.0
@export var key_turn_rate_deg := 90.0
@export var min_zoom := 0.35
@export var max_zoom := 3.0
## Zoom factor per wheel notch.
@export var wheel_step := 1.12
@export var drag_px := 3.0

@export_group("Debug")
## When x >= 0 it replaces the real pointer for the edges and keyboard aiming (test flows).
@export var debug_pointer := Vector2(-1.0, -1.0)

## The view's kit yaw: a formation turned by it faces up the screen.
var yaw: float:
	get:
		var up := Vector2(0.0, -1.0).rotated(0.0 if ignore_rotation else global_rotation)
		return atan2(up.x, up.y)

var _dragged := false
var _drag_travel := 0.0
var _mouse_inside := true
var _pointer := Vector2(-1.0, -1.0)


func _ready() -> void:
	if can_turn:
		ignore_rotation = false
	_keep_in_bounds()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_inside = true
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_inside = false


## FREE: center on `point` (a kit point; RtsSpace.from_2d for a 2D one). FOLLOW: nothing (false).
func focus(point: Vector3) -> bool:
	if mode != Mode.FREE:
		return false
	global_position = RtsSpace.to_2d(point)
	_keep_in_bounds()
	reset_smoothing()
	return true


func is_dragging() -> bool:
	return _dragged


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer = (event as InputEventMouse).position
	if not is_current() or RtsWorldInput.blocked(self):
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		var wheel_in := _pressed(button, wheel_in_action)
		var wheel_out := _pressed(button, wheel_out_action)
		if _pressed(button, select_action) or _pressed(button, order_action) or _pressed(button, orbit_action):
			_dragged = false
			_drag_travel = 0.0
		elif (wheel_in or wheel_out) and _wheel_blocked(button.position):
			pass
		elif wheel_in:
			_zoom_by(wheel_step)
		elif wheel_out:
			_zoom_by(1.0 / wheel_step)
	elif event is InputEventMouseMotion and _held(orbit_action):
		var motion := event as InputEventMouseMotion
		if mode == Mode.FREE:
			_move_screen(-motion.relative)
		_drag_travel += motion.relative.length()
		if _drag_travel > drag_px:
			_dragged = true


func _process(delta: float) -> void:
	if mode == Mode.FOLLOW and is_instance_valid(follow):
		global_position = follow.global_position
		_keep_in_bounds()
	if not is_current() or RtsWorldInput.blocked(self):
		return
	if _held(zoom_in_action):
		_zoom_by(pow(wheel_step, delta * 8.0))
	if _held(zoom_out_action):
		_zoom_by(pow(1.0 / wheel_step, delta * 8.0))
	if mode != Mode.FREE:
		return
	if can_turn:
		if _held(turn_left_action):
			rotation -= deg_to_rad(key_turn_rate_deg) * delta
		if _held(turn_right_action):
			rotation += deg_to_rad(key_turn_rate_deg) * delta
	var move := Vector2.ZERO
	if _held(pan_left_action):
		move.x -= 1.0
	if _held(pan_right_action):
		move.x += 1.0
	if _held(pan_up_action):
		move.y -= 1.0
	if _held(pan_down_action):
		move.y += 1.0
	var pointer: Variant = _edge_pointer()
	if pointer != null:
		var at := pointer as Vector2
		var size := get_viewport().get_visible_rect().size
		if at.x <= edge_px:
			move.x -= 1.0
		elif at.x >= size.x - edge_px:
			move.x += 1.0
		if at.y <= edge_px:
			move.y -= 1.0
		elif at.y >= size.y - edge_px:
			move.y += 1.0
	if move != Vector2.ZERO:
		_move_screen(move.limit_length(1.0) * pan_speed * delta)


## Moves the view by `screen_step` screen pixels (turned and zoomed into the world).
func _move_screen(screen_step: Vector2) -> void:
	var turn := 0.0 if ignore_rotation else global_rotation
	global_position += (screen_step / zoom).rotated(turn)
	_keep_in_bounds()


func _zoom_by(factor: float) -> void:
	var next := clampf(zoom.x * factor, min_zoom, max_zoom)
	zoom = Vector2(next, next)


func _keep_in_bounds() -> void:
	if not bounds.has_area():
		return
	global_position = global_position.clamp(bounds.position, bounds.end)


func _edge_pointer() -> Variant:
	if debug_pointer.x >= 0.0:
		return debug_pointer
	if not _mouse_inside or not get_window().has_focus() or _held(orbit_action):
		return null
	if _pointer.x < 0.0:
		return null
	if edge_area and get_viewport().gui_get_hovered_control() != edge_area:
		return null
	return _pointer


func _wheel_blocked(screen: Vector2) -> bool:
	for blocker in wheel_blockers:
		if blocker == null or not blocker.is_visible_in_tree():
			continue
		if blocker.has_method("covers"):
			if bool(blocker.call("covers", screen)):
				return true
		elif Rect2(Vector2.ZERO, blocker.size).has_point(
			blocker.get_global_transform().affine_inverse() * screen
		):
			return true
	return false


func _held(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action, true)


func _pressed(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action)
