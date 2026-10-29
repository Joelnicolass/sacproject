extends Node3D

## PropKit's 3D example: a forest scattered over a ground with collision, drawn in batches, cutting
## a navmesh baked in zones. Left click twice: a path between the two points. C: chop the props
## around the mouse (the navmesh follows its props: only their zones bake again). R: a new forest (another seed). Drag with the
## right button to turn, the wheel to zoom, WASD to move. A game presses «Scatter» and «Bake» in
## the editor instead; this example scatters when it starts, so its scene stays small.

## How far around the mouse C chops.
@export_range(0.5, 30.0, 0.5, "suffix:m") var chop_radius_m := 5.0

@export var scatter: PropScatter3D
@export var batch: PropBatch3D
@export var zones: PropNavZones3D
@export var camera: Camera3D
@export var hud: Label
@export var path_line: MeshInstance3D

var _start := Vector3.INF
var _path := PackedVector3Array()
var _yaw := 0.6
var _pitch := 0.9
var _distance := 110.0
var _focus := Vector3.ZERO
var _turning := false


func _ready() -> void:
	zones.updated.connect(_show)
	if scatter.get_child_count() == 0:
		scatter.scatter()
	batch.rebuild_all()
	_place_camera()
	_show()


func _process(delta: float) -> void:
	var move := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if move != Vector2.ZERO:
		var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
		var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
		_focus += (right * move.x - forward * move.y) * _distance * 0.8 * delta
		_place_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_turning = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(_distance * 0.9, 15.0)
			_place_camera()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(_distance * 1.1, 300.0)
			_place_camera()
		elif button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			_click(_ground_at(button.position))
	elif event is InputEventMouseMotion and _turning:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * 0.005
		_pitch = clampf(_pitch + motion.relative.y * 0.005, 0.2, 1.45)
		_place_camera()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_C:
			chop_at(_ground_at(get_viewport().get_mouse_position()))
		elif key == KEY_R:
			new_forest()


## Frees the props within `chop_radius_m` of `at`. The batches and the navmesh redo only where
## they stood, on their own.
func chop_at(at: Vector3) -> int:
	if at == Vector3.INF:
		return 0
	var chopped := 0
	for prop: Node3D in scatter.get_children():
		var offset := prop.global_position - at
		if Vector2(offset.x, offset.z).length() > chop_radius_m:
			continue
		prop.queue_free()
		chopped += 1
	return chopped


## Scatters a forest with the next seed, then draws it again (the navmesh follows).
func new_forest() -> void:
	scatter.rules.random_seed += 1
	scatter.scatter()
	batch.rebuild_all()
	_path.clear()
	_draw_path()


func _click(at: Vector3) -> void:
	if at == Vector3.INF:
		return
	if _start == Vector3.INF or not _path.is_empty():
		_start = at
		_path.clear()
	else:
		var map := get_world_3d().navigation_map
		_path = NavigationServer3D.map_get_path(map, _start, at, true)
		_start = Vector3.INF
	_draw_path()
	_show()


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


func _draw_path() -> void:
	var mesh := ImmediateMesh.new()
	if _path.size() >= 2:
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for point in _path:
			mesh.surface_add_vertex(point + Vector3.UP * 0.3)
		mesh.surface_end()
	path_line.mesh = mesh


func _show() -> void:
	var lines := PackedStringArray()
	lines.append("Props: %d   batches: %d" % [scatter.get_child_count(), batch.batch_count()])
	lines.append("Navmesh: %s" % zones.stats)
	if _path.size() >= 2:
		var length := 0.0
		for i in range(1, _path.size()):
			length += _path[i - 1].distance_to(_path[i])
		lines.append("Path: %.0f m" % length)
	elif _start != Vector3.INF:
		lines.append("Path: click where it ends")
	lines.append("Left click x2: path   C: chop   R: new forest   right drag: turn   wheel: zoom")
	hud.text = "\n".join(lines)
