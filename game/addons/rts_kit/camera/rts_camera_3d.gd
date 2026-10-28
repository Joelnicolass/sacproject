class_name RtsCamera3D
extends Camera3D

## The camera of a 3D RTS, in two modes with one contract (`yaw`, `is_dragging()`, `focus()`,
## `debug_pointer`), so formations and input never ask which one is on.
##
## FOLLOW: third person behind a body (`follow`): it places itself from the body's height and the
## zoom, turns with the keys, the screen edges and free look, and zooms with the wheel. FREE: a
## top-down view over a point of the map: it pans with the keys, the screen edges and a middle drag,
## turns with the keys or the orbit modifier + drag, zooms with the wheel between `free_min_distance`
## and `free_max_distance`, and stays inside `bounds`.
##
## In both the eye never goes below `ground_clearance` over the ground under it (a ray to `ground`,
## and `height_at` when the game gives one: live terrain that moves before its collision does). The
## edges only work while the pointer is over `edge_area`; the wheel does nothing over a
## `wheel_blockers` control (one with a `covers(screen) -> bool` method decides by it). Nothing reads
## input while a modal UI is open (RtsWorldInput).

enum Mode { FOLLOW, FREE }

@export var mode := Mode.FREE:
	set(value):
		mode = value
		_dragged = false
## FOLLOW: the body to stand behind (change it with `set_follow`).
@export var follow: Node3D
## Only this ground counts for the ray under the camera (other bodies on `ground_mask` are skipped).
## Empty: anything on the mask.
@export var ground: Node
@export_flags_3d_physics var ground_mask := 1
## The eye never goes lower than this over the ground under it.
@export var ground_clearance := 0.5
## Edges only work while the pointer hovers this control (a HUD bar stays out). Empty: anywhere.
@export var edge_area: Control
## The wheel does not zoom while the pointer is over one of these.
@export var wheel_blockers: Array[Control] = []
## Composed last on top of the placement (a shake). Empty: none.
@export var effect: RtsCameraEffect
## FOLLOW: the follow body's property that mirrors `yaw` both ways (a hero that walks where the camera
## looks); empty = none.
@export var follow_yaw_property: StringName = &""

@export_group("Actions")
@export var select_action: StringName = &"rts_select"
@export var order_action: StringName = &"rts_order"
@export var orbit_action: StringName = &"rts_camera_orbit"
@export var orbit_modifier_action: StringName = &"rts_camera_orbit_modifier"
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

@export_group("Edges")
@export var edge_px := 100.0
## FOLLOW: degrees per second the edges turn the view.
@export var turn_rate_deg := 36.0
## FOLLOW: zoom per second the top and bottom edges change.
@export var zoom_rate := 0.5
@export var wheel_step := 0.04
@export var key_turn_rate_deg := 180.0

@export_group("Zoom")
@export_range(0.0, 1.0) var start_zoom := 0.125
## Fraction of the zoom gap left after one second.
@export var zoom_settle := 0.0001

@export_group("Follow formula")
## The follow body's height when `height_of` is not set.
@export var follow_height := 1.5
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
## Degrees per pixel. Negative = "grab the world".
@export var look_deg_per_px := -0.25
## Absolute limits of `view_pitch_deg`. Basis.looking_at degenerates at ±90°.
@export var look_down_max_deg := 85.0
@export var look_up_max_deg := 80.0
## Pixels a held button travels before it counts as a drag.
@export var drag_px := 3.0

@export_group("Free mode")
## The point the free view looks at, a kit point (`focus` moves it).
@export var free_target := Vector3.ZERO
## Degrees below the horizon the free view looks.
@export_range(10.0, 89.0) var free_pitch_deg := 55.0
@export var free_min_distance := 8.0
@export var free_max_distance := 60.0
## World units per second the keys and edges pan at the closest zoom (it grows with the distance).
@export var pan_speed := 12.0
## The map rectangle (x, z) the free target stays in; empty = anywhere.
@export var bounds := Rect2()

@export_group("Debug")
## When x >= 0 it replaces the real pointer for the edges and keyboard aiming (test flows).
@export var debug_pointer := Vector2(-1.0, -1.0)

## The view's yaw (RtsSpace: forward is (sin, 0, cos)).
var yaw := 0.0
var zoom := 0.125
var target_zoom := 0.125
## FOLLOW: free-look pitch on top of the follow angle (negative looks up).
var look_pitch_deg := 0.0
## The resulting view pitch below the horizon.
var view_pitch_deg := 0.0
## The follow body's height: `func(body: Node3D) -> float`. Unset: `follow_height`.
var height_of: Callable
## Live ground height at a point: `func(x: float, z: float) -> float` (NAN = unknown). Unset: only the
## ray.
var height_at: Callable

var _dragged := false
var _drag_travel := 0.0
var _mouse_inside := true
## The last pointer this viewport got as an event; x < 0 until the first one.
var _pointer := Vector2(-1.0, -1.0)


func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ready() -> void:
	zoom = start_zoom
	target_zoom = start_zoom
	free_target = _clamped(free_target)
	if follow:
		set_follow(follow)
	_place()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_inside = true
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_inside = false


## FOLLOW: the body to stand behind (its `follow_yaw_property` gives the yaw).
func set_follow(node: Node3D) -> void:
	follow = node
	if follow and follow_yaw_property != &"" and follow_yaw_property in follow:
		yaw = float(follow.get(follow_yaw_property))
	_place()


## FREE: look at `point` (a kit point, kept inside `bounds`). FOLLOW: nothing (false).
func focus(point: Vector3) -> bool:
	if mode != Mode.FREE:
		return false
	free_target = _clamped(point)
	_place()
	return true


## True while a held button travelled past `drag_px`: the click that ends it is not an order.
func is_dragging() -> bool:
	return _dragged


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer = (event as InputEventMouse).position
	if not current or RtsWorldInput.blocked(self):
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		var wheel_in := _is_action_pressed(button, wheel_in_action)
		var wheel_out := _is_action_pressed(button, wheel_out_action)
		if (
			_is_action_pressed(button, select_action)
			or _is_action_pressed(button, order_action)
			or _is_action_pressed(button, orbit_action)
		):
			_dragged = false
			_drag_travel = 0.0
		elif (wheel_in or wheel_out) and _wheel_blocked(button.position):
			pass
		elif wheel_in:
			_nudge_zoom(-wheel_step * _wheel_factor(button))
		elif wheel_out:
			_nudge_zoom(wheel_step * _wheel_factor(button))
	elif event is InputEventMouseMotion:
		_on_motion(event as InputEventMouseMotion)


func _on_motion(motion: InputEventMouseMotion) -> void:
	var held := _held(order_action)
	if mode == Mode.FOLLOW:
		if _free_look():
			held = true
			yaw -= deg_to_rad(motion.relative.x * look_deg_per_px)
			look_pitch_deg += motion.relative.y * look_deg_per_px
	else:
		if _held(orbit_action) or _free_look():
			held = true
			if _held(orbit_modifier_action):
				yaw -= deg_to_rad(motion.relative.x * look_deg_per_px)
			else:
				_drag_pan(motion.relative)
	if held:
		_drag_travel += motion.relative.length()
		if _drag_travel > drag_px:
			_dragged = true


func _process(delta: float) -> void:
	if current and not RtsWorldInput.blocked(self):
		if mode == Mode.FOLLOW:
			_steer_follow(delta)
		else:
			_steer_free(delta)
	_settle_zoom(delta)
	if (
		mode == Mode.FOLLOW
		and is_instance_valid(follow)
		and follow_yaw_property != &""
		and follow_yaw_property in follow
	):
		follow.set(follow_yaw_property, yaw)
	_place()


func _steer_follow(delta: float) -> void:
	if _held(turn_left_action):
		yaw += deg_to_rad(key_turn_rate_deg) * delta
	if _held(turn_right_action):
		yaw -= deg_to_rad(key_turn_rate_deg) * delta
	if _held(zoom_in_action):
		_nudge_zoom(-zoom_rate * delta)
	if _held(zoom_out_action):
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


func _steer_free(delta: float) -> void:
	if _held(turn_left_action):
		yaw += deg_to_rad(key_turn_rate_deg) * delta
	if _held(turn_right_action):
		yaw -= deg_to_rad(key_turn_rate_deg) * delta
	if _held(zoom_in_action):
		_nudge_zoom(-zoom_rate * delta)
	if _held(zoom_out_action):
		_nudge_zoom(zoom_rate * delta)
	# (right, forward) of the screen.
	var move := Vector2.ZERO
	if _held(pan_left_action):
		move.x -= 1.0
	if _held(pan_right_action):
		move.x += 1.0
	if _held(pan_up_action):
		move.y += 1.0
	if _held(pan_down_action):
		move.y -= 1.0
	var pointer: Variant = _edge_pointer()
	if pointer != null:
		var at := pointer as Vector2
		var size := get_viewport().get_visible_rect().size
		if at.x <= edge_px:
			move.x -= 1.0
		elif at.x >= size.x - edge_px:
			move.x += 1.0
		if at.y <= edge_px:
			move.y += 1.0
		elif at.y >= size.y - edge_px:
			move.y -= 1.0
	if move == Vector2.ZERO:
		return
	move = move.limit_length(1.0)
	var speed := pan_speed * free_distance() / maxf(free_min_distance, 0.001)
	_pan(move * speed * delta)


## FREE: the distance from the eye to the target at the current zoom.
func free_distance() -> float:
	return lerpf(free_min_distance, free_max_distance, zoom)


## A middle drag moves the map with the pointer.
func _drag_pan(relative: Vector2) -> void:
	var viewport_height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var per_px := 2.0 * free_distance() * tan(deg_to_rad(fov) * 0.5) / viewport_height
	_pan(Vector2(-relative.x, relative.y) * per_px)


## Moves the free target by (right, forward) world units of the view.
func _pan(step: Vector2) -> void:
	free_target = _clamped(
		free_target + RtsSpace.right(yaw) * step.x + RtsSpace.ahead(yaw) * step.y
	)


func _clamped(point: Vector3) -> Vector3:
	if not bounds.has_area():
		return point
	return Vector3(
		clampf(point.x, bounds.position.x, bounds.end.x),
		point.y,
		clampf(point.z, bounds.position.y, bounds.end.y)
	)


func _edge_pointer() -> Variant:
	if debug_pointer.x >= 0.0:
		return debug_pointer
	if not _mouse_inside or not get_window().has_focus():
		return null
	if _free_look() or _held(orbit_action):
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


func _wheel_factor(button: InputEventMouseButton) -> float:
	return button.factor if button.factor > 0.0 else 1.0


## The look gesture: the modifier + `select_action`, and in FOLLOW also `orbit_action` (in FREE the
## orbit button drags the map instead).
func _free_look() -> bool:
	var gesture := _held(orbit_modifier_action) and _held(select_action)
	if mode == Mode.FOLLOW:
		return gesture or _held(orbit_action)
	return gesture


func _held(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action, true)


func _is_action_pressed(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action)


func _nudge_zoom(amount: float) -> void:
	target_zoom = clampf(target_zoom + amount, 0.0, 1.0)


func _settle_zoom(delta: float) -> void:
	if is_equal_approx(zoom, target_zoom):
		zoom = target_zoom
		return
	var keep := pow(zoom_settle, delta)
	zoom = clampf((1.0 - keep) * target_zoom + keep * zoom, 0.0, 1.0)


func _place() -> void:
	if not is_inside_tree():
		return
	if mode == Mode.FOLLOW:
		_place_follow()
	else:
		_place_free()


func _place_free() -> void:
	var ahead := RtsSpace.ahead(yaw)
	var down := deg_to_rad(free_pitch_deg)
	view_pitch_deg = free_pitch_deg
	var distance := free_distance()
	var target := free_target
	var base_y := _ground_y(target, target.y)
	target.y = base_y
	var eye := target - ahead * cos(down) * distance + Vector3.UP * sin(down) * distance
	eye.y = _above_ground(eye)
	var view := ahead * cos(down) + Vector3.DOWN * sin(down)
	_compose(Basis.looking_at(view, Vector3.UP), eye)


func _place_follow() -> void:
	if not is_instance_valid(follow) or not follow.is_inside_tree():
		return
	var h := maxf(_subject_height(), min_subject_height)
	var base_distance := maxf(distance_base + distance_per_height * h, min_distance)
	var floating := floating_per_height * h + floating_offset
	var focus_height := floating - focus_drop_per_height * (h - 1.0)
	var focus_factor := 1.0
	if zoom < focus_full_zoom:
		focus_factor = focus_min_factor + (1.0 - focus_min_factor) * zoom / focus_full_zoom
	var distance := base_distance * (distance_zoom_base + distance_zoom_scale * zoom)
	var height := floating * (height_zoom_base + height_zoom_scale * zoom)
	# The drawn place of the body (interpolated), not the tick it simulates in.
	var origin := follow.get_global_transform_interpolated().origin
	var ahead := RtsSpace.ahead(yaw)
	var spot := origin - ahead * distance
	spot.y = origin.y - _ground_y(origin, origin.y) + _ground_y(spot, origin.y) + height
	var offset := atan2(
		spot.y - (origin.y + focus_height * focus_factor),
		Vector2(origin.x - spot.x, origin.z - spot.z).length()
	)
	var offset_deg := rad_to_deg(offset)
	look_pitch_deg = clampf(
		look_pitch_deg, -look_up_max_deg - offset_deg, look_down_max_deg - offset_deg
	)
	view_pitch_deg = clampf(offset_deg + look_pitch_deg, -look_up_max_deg, look_down_max_deg)
	var down := deg_to_rad(view_pitch_deg)
	var view := ahead * cos(down) + Vector3.DOWN * sin(down)
	var look := Basis.looking_at(view, Vector3.UP)
	var eye := spot + Vector3.UP * eye_lift
	eye.y = _above_ground(eye)
	_compose(look, eye)


## `eye.y`, raised to `ground_clearance` over the ground under it; unchanged when no ground is known
## there.
func _above_ground(eye: Vector3) -> float:
	var ground_y := _known_ground_y(eye, eye.y)
	return eye.y if is_nan(ground_y) else maxf(eye.y, ground_y + ground_clearance)


## The effect computes only; the camera composes it last, so it never feeds back.
func _compose(look: Basis, eye: Vector3) -> void:
	if effect != null and is_instance_valid(effect):
		eye += look * effect.offset()
		look = look.rotated(look.z.normalized(), effect.roll())
	global_transform = Transform3D(look, eye)


func _subject_height() -> float:
	if height_of.is_valid():
		return float(height_of.call(follow))
	return follow_height


## The highest of the live ground (`height_at`) and what a ray around `fallback` finds under `at`;
## `fallback` when neither is there.
func _ground_y(at: Vector3, fallback: float) -> float:
	var known := _known_ground_y(at, fallback)
	return fallback if is_nan(known) else known


## The same, NAN when neither is there. The ray runs 500 above and below `ray_y`.
func _known_ground_y(at: Vector3, ray_y: float) -> float:
	var land := float(height_at.call(at.x, at.z)) if height_at.is_valid() else NAN
	var hit := _ray_y(at, ray_y)
	if is_nan(land):
		return hit
	return land if is_nan(hit) else maxf(land, hit)


## NAN when the ray from above finds no ground under `at`.
func _ray_y(at: Vector3, fallback: float) -> float:
	var world := get_world_3d()
	if world == null:
		return NAN
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(at.x, fallback + 500.0, at.z), Vector3(at.x, fallback - 500.0, at.z)
	)
	query.collision_mask = ground_mask
	var skip: Array[RID] = []
	if follow is CollisionObject3D:
		skip.append((follow as CollisionObject3D).get_rid())
	for _attempt in 4:
		query.exclude = skip
		var hit := world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return NAN
		var body: Object = hit.get("collider")
		if (
			RtsUnit.of(body) == null
			and (ground == null or body == ground or (body is Node and ground.is_ancestor_of(body)))
		):
			return float(hit.position.y)
		skip.append(hit.get("rid"))
	return NAN
