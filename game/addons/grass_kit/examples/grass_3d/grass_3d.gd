extends Node3D

## GrassKit's example: hills of grass around the camera. The field reads the ground's height from
## the hills' collider when it starts (`bake_ground()`; in the editor, «Bake ground»). A walker in
## the group `units` tramples a path; the camps (group `camps`) and a GrassClear3D clear the grass
## around them; the steep mound is too steep for grass. The wind is a GrassWind the ground reads
## too (its pale bands). Keys: 1 2 3 the low, medium and high quality; L the next look (summer,
## autumn: uniforms only; flowers: another kind of blade); T a storm rises or calms (blended); G
## grass off and on; C digs a crater under the mouse and only the grass there follows. Drag with
## the right button to turn, the wheel to zoom, WASD to move.

@export var field: GrassField3D
@export var hills: Node3D
@export var walker: Node3D
@export var camera: Camera3D
@export var hud: Label
@export var autumn: GrassLook
## The summer look with a kind of flower among the blades (flower.tres: a mesh, its petals'
## texture with alpha scissor, its own colours).
@export var flowers: GrassLook

var _summer: GrassLook
var _yaw := 0.7
var _pitch := 0.55
var _distance := 30.0
var _focus := Vector3(0.0, 2.0, 0.0)
var _turning := false
var _walk := 0.0


func _ready() -> void:
	_summer = field.look
	_place_camera()
	# The hills' collider is in the physics space one frame after it enters the tree.
	await get_tree().physics_frame
	field.bake_ground()


func _process(delta: float) -> void:
	_walk += delta * 0.25
	var at := Vector2(cos(_walk), sin(_walk * 1.3)) * 12.0
	walker.global_position = Vector3(at.x, hills.call(&"height_at", at.x, at.y) + 0.9, at.y)
	var move := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if move != Vector2.ZERO:
		var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
		var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
		_focus += (right * move.x - forward * move.y) * maxf(_distance, 10.0) * delta
		_focus.y = hills.call(&"height_at", _focus.x, _focus.z) + 1.5
		_place_camera()
	_show()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_turning = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(_distance * 0.9, 3.0)
			_place_camera()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(_distance * 1.1, 150.0)
			_place_camera()
	elif event is InputEventMouseMotion and _turning:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * 0.005
		_pitch = clampf(_pitch + motion.relative.y * 0.005, 0.05, 1.5)
		_place_camera()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		match (event as InputEventKey).physical_keycode:
			KEY_1:
				field.quality = GrassQuality.preset(GrassQuality.Level.LOW)
			KEY_2:
				field.quality = GrassQuality.preset(GrassQuality.Level.MEDIUM)
			KEY_3:
				field.quality = GrassQuality.preset(GrassQuality.Level.HIGH)
			KEY_L:
				var looks := [_summer, autumn, flowers]
				field.look = looks[(looks.find(field.look) + 1) % looks.size()]
			KEY_T:
				var storm := field.wind.strength < 1.0
				field.wind.strength = 1.3 if storm else 0.5
				field.wind.direction = Vector2(0.3, 0.95) if storm else Vector2(0.8, 0.6)
			KEY_G:
				field.enabled = not field.enabled
			KEY_C:
				dig_at(_ground_at(get_viewport().get_mouse_position()))


## Digs a crater at `at` in the hills, and the grass there follows the new ground.
func dig_at(at: Vector3) -> void:
	if at == Vector3.INF:
		return
	hills.call(&"dig", at.x, at.z, 5.0, 2.5)
	# The new collider is in the physics space on the next physics frame.
	await get_tree().physics_frame
	field.ground_changed(at, 6.0)


func _ground_at(screen: Vector2) -> Vector3:
	var from := camera.project_ray_origin(screen)
	var to := from + camera.project_ray_normal(screen) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else Vector3.INF


func _place_camera() -> void:
	var offset := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	camera.global_position = _focus + offset * _distance
	camera.look_at(_focus)


func _show() -> void:
	var lines := PackedStringArray()
	lines.append("%d fps   %s" % [Engine.get_frames_per_second(), field.stats])
	lines.append("Quality: %s" % field.quality.describe())
	var shown := "summer"
	if field.look == autumn:
		shown = "autumn"
	elif field.look == flowers:
		shown = "flowers"
	var weather := "storm" if field.wind.strength >= 1.0 else "breeze"
	lines.append("Look: %s   Wind: %s   Grass: %s" % [shown, weather, "on" if field.enabled else "off"])
	lines.append("1 2 3 quality   L look   T storm   G grass   C crater   right drag turn   wheel zoom")
	lines.append("WASD move")
	hud.text = "\n".join(lines)
