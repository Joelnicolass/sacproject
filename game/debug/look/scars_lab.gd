extends Node3D

## Laboratory of the marks on the ground (RFC-061 061k-5): the flat test map with its own GroundScars, a camera over it and one
## ScarMark node that the clicks move. Left click: paint the current mark where the mouse points. Keys 1..9: the mark (the
## `textures` list: burn, rock cracks, oil, crater, blood, Firewall crack, ...). F: throw `burst_count` marks of the current
## kind at random places (watch the oldest tiles go when the count passes the limit of «Cantidad de marcas»). WASD / Q E move
## the camera, wheel zooms. The ground is the real classic shader: nothing of the lab is in the game.

@export var map: MapRoot
@export var camera: Camera3D
@export var mark: ScarMark
@export var info: Label
## The marks the keys 1..9 pick (the SCAR files of assets/original/scars/).
@export var textures: Array[Texture2D] = []
@export var burst_count := 60
@export var burst_radius_m := 120.0
@export var move_speed := 60.0
## Where the camera looks at first (the middle of the test map's land).
@export var look_target := Vector3(1250.0, 10.0, 1300.0)

var _current := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 6105
	camera.look_at(look_target)
	_pick(0)


func _process(delta: float) -> void:
	var axis := Vector3(Input.get_axis(&"ui_left", &"ui_right"), 0.0, Input.get_axis(&"ui_up", &"ui_down"))
	axis.y = float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q))
	axis.x += float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	axis.z += float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	camera.global_position += axis * move_speed * delta
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_paint_at(button.position)
		elif button.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.global_position += -camera.global_basis.z * 8.0
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.global_position += camera.global_basis.z * 8.0
	elif event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		if key.keycode >= KEY_1 and key.keycode <= KEY_9:
			_pick(key.keycode - KEY_1)
		elif key.keycode == KEY_F:
			_burst()


func _pick(index: int) -> void:
	if index < textures.size():
		_current = index
		mark.texture = textures[index]


func _paint_at(screen: Vector2) -> void:
	var from := camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(screen) * 4000.0)
	query.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		mark.global_position = hit["position"]
		mark.mark()


func _burst() -> void:
	var center := mark.global_position
	for i in burst_count:
		var offset := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * burst_radius_m
		mark.global_position = center + offset
		mark.mark()
	mark.global_position = center


func _refresh() -> void:
	var scars := GroundScars.of(mark)
	var painted := scars.painted_tiles() if scars != null else 0
	var limit := scars.capacity() if scars != null else 0
	info.text = "Mark %d/%d (%s)  tiles %d/%d\nClick paint - 1..9 mark - F burst x%d - WASD Q E move - wheel zoom" % [
		_current + 1, textures.size(), mark.texture.resource_path.get_file() if mark.texture else "-", painted, limit, burst_count]
