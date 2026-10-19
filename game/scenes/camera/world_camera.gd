extends Camera3D

## Third-person camera of sacengine (dagonBackend.d positionCamera / cameraControl). Units 1:1 sac → m.

@export var follow: Node3D
## Only this ground counts for the height under the camera (props on layer 1 are skipped).
@export var ground: Node3D
## Edges only scroll while the pointer hovers this control (the HUD bar is excluded).
@export var edge_area: Control
## The wheel does not zoom the world while the pointer is over one of these (the minimap zooms itself). A control with a
## `covers(screen)` method (Minimap: its circle) decides by that; any other counts by its rectangle.
@export var wheel_blockers: Array[Control] = []

@export_group("Edges")
@export var edge_px := 100.0
@export var turn_rate_deg := 36.0
@export var zoom_rate := 0.5
@export var wheel_step := 0.04
@export var key_turn_rate_deg := 180.0

@export_group("Zoom")
@export_range(0.0, 1.0) var start_zoom := 0.125
## Fraction of the zoom gap left after one second (0.01² per second at 60 fps).
@export var zoom_settle := 0.0001

@export_group("Formula")
@export var min_subject_height := 1.5
@export var distance_base := 0.6
@export var distance_per_height := 2.32
@export var min_distance := 4.5
@export var floating_per_height := 1.75
@export var floating_offset := -1.15
@export var focus_drop_per_height := 0.3
@export var distance_zoom_base := 0.6
@export var distance_zoom_scale := 3.13
@export var height_zoom_base := 0.6
@export var height_zoom_scale := 2.8
@export var focus_full_zoom := 0.125
@export var focus_min_factor := 0.75
@export var eye_lift := 1.0

@export_group("Free look")
## Degrees per pixel. Negative = the original "grab the world" feel.
@export var look_deg_per_px := -0.25
## Absolute limits of view_pitch_deg. sacengine only wraps the pitch at ±180° (dagonBackend.d:425);
## Basis.looking_at degenerates at ±90°, so the view stops short of vertical.
@export var look_down_max_deg := 85.0
@export var look_up_max_deg := 80.0
@export var drag_px := 3.0

@export_group("Debug")
## When x >= 0 it replaces the real pointer for edge scrolling.
@export var debug_pointer := Vector2(-1.0, -1.0)

var yaw := 0.0
var zoom := 0.125
var target_zoom := 0.125
## Free-look pitch on top of the follow angle (sacengine camera.pitch over pitchOffset). Negative looks up.
var free_pitch_deg := 0.0
## Resulting view pitch below the horizon, in [-look_up_max_deg, look_down_max_deg]. Negative looks up.
var view_pitch_deg := 0.0
var _dragged := false
var _drag_travel := 0.0
var _mouse_inside := true
## Last pointer position this viewport received as an event; x < 0 until the first one.
var _pointer := Vector2(-1.0, -1.0)


func _ready() -> void:
	zoom = start_zoom
	target_zoom = start_zoom
	if follow:
		set_follow(follow)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_inside = true
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_inside = false


func set_follow(node: Node3D) -> void:
	follow = node
	if follow and "look_yaw" in follow:
		yaw = float(follow.get("look_yaw"))
	_place()


func is_dragging() -> bool:
	return _dragged


func yaw_degrees() -> float:
	return rad_to_deg(yaw)


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer = (event as InputEventMouse).position
	if not current or WorldInput.blocked(self):
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragged = false
			_drag_travel = 0.0
		elif button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and _wheel_blocked(button.position):
			pass
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_nudge_zoom(-wheel_step * _wheel_factor(button))
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_nudge_zoom(wheel_step * _wheel_factor(button))
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var held := motion.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)
		if _free_look(motion):
			held = 1
			yaw -= deg_to_rad(motion.relative.x * look_deg_per_px)
			free_pitch_deg += motion.relative.y * look_deg_per_px
		if held:
			_drag_travel += motion.relative.length()
			if _drag_travel > drag_px:
				_dragged = true


func _wheel_blocked(screen: Vector2) -> bool:
	for blocker in wheel_blockers:
		if blocker == null or not blocker.is_visible_in_tree():
			continue
		if blocker is Minimap:
			if (blocker as Minimap).covers(screen):
				return true
		elif Rect2(Vector2.ZERO, blocker.size).has_point(blocker.get_global_transform().affine_inverse() * screen):
			return true
	return false


func _wheel_factor(button: InputEventMouseButton) -> float:
	return button.factor if button.factor > 0.0 else 1.0


func _free_look(motion: InputEventMouseMotion) -> bool:
	if motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		return true
	return bool(motion.button_mask & MOUSE_BUTTON_MASK_LEFT) and motion.ctrl_pressed


func _process(delta: float) -> void:
	if current and not WorldInput.blocked(self):
		_steer(delta)
	_settle_zoom(delta)
	if is_instance_valid(follow) and "look_yaw" in follow:
		follow.set("look_yaw", yaw)
	_place()


func _steer(delta: float) -> void:
	if Input.is_action_pressed("turn_left", true):
		yaw += deg_to_rad(key_turn_rate_deg) * delta
	if Input.is_action_pressed("turn_right", true):
		yaw -= deg_to_rad(key_turn_rate_deg) * delta
	if Input.is_action_pressed("zoom_in", true):
		_nudge_zoom(-zoom_rate * delta)
	if Input.is_action_pressed("zoom_out", true):
		_nudge_zoom(zoom_rate * delta)
	var pointer: Variant = _edge_pointer()
	if pointer == null:
		return
	var at := pointer as Vector2
	var size := get_viewport().get_visible_rect().size
	if at.x <= edge_px:
		yaw += deg_to_rad(turn_rate_deg) * delta
	elif at.x >= size.x - edge_px:
		yaw -= deg_to_rad(turn_rate_deg) * delta
	if at.y <= edge_px:
		_nudge_zoom(-zoom_rate * delta)
	elif at.y >= size.y - edge_px:
		_nudge_zoom(zoom_rate * delta)


func _edge_pointer() -> Variant:
	if debug_pointer.x >= 0.0:
		return debug_pointer
	if not _mouse_inside or not get_window().has_focus():
		return null
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		return null
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.is_key_pressed(KEY_CTRL):
		return null
	if _pointer.x < 0.0:
		return null
	if edge_area and get_viewport().gui_get_hovered_control() != edge_area:
		return null
	# The pointer the GUI hover saw, not the OS cursor, which can sit over a window the game never got events for.
	return _pointer


func _nudge_zoom(amount: float) -> void:
	target_zoom = clampf(target_zoom + amount, 0.0, 1.0)


func _settle_zoom(delta: float) -> void:
	if is_equal_approx(zoom, target_zoom):
		zoom = target_zoom
		return
	var keep := pow(zoom_settle, delta)
	zoom = clampf((1.0 - keep) * target_zoom + keep * zoom, 0.0, 1.0)


func _place() -> void:
	if not is_instance_valid(follow) or not follow.is_inside_tree():
		return
	var h := maxf(_subject_height(), min_subject_height)
	var base_distance := maxf(distance_base + distance_per_height * h, min_distance)
	var floating := floating_per_height * h + floating_offset
	var focus := floating - focus_drop_per_height * (h - 1.0)
	var focus_factor := 1.0
	if zoom < focus_full_zoom:
		focus_factor = focus_min_factor + (1.0 - focus_min_factor) * zoom / focus_full_zoom
	var distance := base_distance * (distance_zoom_base + distance_zoom_scale * zoom)
	var height := floating * (height_zoom_base + height_zoom_scale * zoom)
	var origin := follow.global_position
	var ahead := Vector3(sin(yaw), 0.0, cos(yaw))
	var spot := origin - ahead * distance
	spot.y = origin.y - _ground_y(origin, origin.y) + _ground_y(spot, origin.y) + height
	var offset := atan2(spot.y - (origin.y + focus * focus_factor), Vector2(origin.x - spot.x, origin.z - spot.z).length())
	var offset_deg := rad_to_deg(offset)
	free_pitch_deg = clampf(free_pitch_deg, -look_up_max_deg - offset_deg, look_down_max_deg - offset_deg)
	view_pitch_deg = clampf(offset_deg + free_pitch_deg, -look_up_max_deg, look_down_max_deg)
	var down := deg_to_rad(view_pitch_deg)
	var view := ahead * cos(down) + Vector3.DOWN * sin(down)
	global_transform = Transform3D(Basis.looking_at(view, Vector3.UP), spot + Vector3.UP * eye_lift)


func _subject_height() -> float:
	for child in follow.get_children():
		if child is BodyVisual:
			return (child as BodyVisual).body_height()
	return min_subject_height


func _ground_y(at: Vector3, fallback: float) -> float:
	var world := get_world_3d()
	if world == null:
		return fallback
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(at.x, fallback + 500.0, at.z), Vector3(at.x, fallback - 500.0, at.z)
	)
	var skip: Array[RID] = []
	if follow is CollisionObject3D:
		skip.append((follow as CollisionObject3D).get_rid())
	for _attempt in 4:
		query.exclude = skip
		var hit := world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return fallback
		var body: Object = hit.get("collider")
		if ground == null or body == ground or (body is Node and ground.is_ancestor_of(body)):
			return float(hit.position.y)
		skip.append(hit.get("rid"))
	return fallback
