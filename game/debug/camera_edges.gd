extends Node

## Each check_tick holds the pointer on the next edge for hold_s, then reports. The last step drags with the middle button.

@export var camera: Camera3D
@export var hold_s := 1.0
@export var inset_px := 10.0
@export var look_drag_px := Vector2(0.0, 360.0)
## 3 goes straight to the free-look drag.
@export var start_phase := 0

var _phase := 0
var _busy := false


func _ready() -> void:
	_phase = start_phase


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick") and not _busy:
		_run_phase()


func _run_phase() -> void:
	if camera == null:
		return
	_busy = true
	var size := get_viewport().get_visible_rect().size
	var label: String = ["izquierda", "arriba", "abajo", "vista libre"][_phase % 4]
	var before := float(camera.call("yaw_degrees"))
	match _phase % 4:
		0:
			await _hold(Vector2(inset_px, size.y * 0.5))
		1:
			await _hold(Vector2(size.x * 0.5, inset_px))
		2:
			await _hold(Vector2(size.x * 0.25, size.y - inset_px))
		3:
			await _middle_drag(size * 0.5)
	var yaw := float(camera.call("yaw_degrees"))
	print("borde %s giro %.1f" % [label, yaw - before])
	print("camara yaw %.1f zoom %.3f pitch %.1f vista %.1f" % [yaw, float(camera.get("zoom")), float(camera.get("free_pitch_deg")), float(camera.get("view_pitch_deg"))])
	_phase += 1
	_busy = false


func _hold(at: Vector2) -> void:
	camera.set("debug_pointer", at)
	await get_tree().create_timer(hold_s).timeout
	camera.set("debug_pointer", Vector2(-1.0, -1.0))


func _middle_drag(at: Vector2) -> void:
	_middle(at, true)
	var steps := 12
	for i in steps:
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		motion.relative = look_drag_px / float(steps)
		motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
		Input.parse_input_event(motion)
		await get_tree().process_frame
	_middle(at, false)
	await get_tree().process_frame


func _middle(at: Vector2, pressed: bool) -> void:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_MIDDLE
	button.pressed = pressed
	button.position = at
	button.global_position = at
	Input.parse_input_event(button)
