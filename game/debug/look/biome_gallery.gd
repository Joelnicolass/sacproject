extends Node

## check_tick cycles the gods' looks over the High Noon world.

@export var world_path: NodePath = ^"HighNoon"
@export var start_god: StringName = &"persephone"
@export var camera_path: NodePath = ^"ViewCamera"
## When x >= 0 the camera looks at the ground under (x, z) from view_offset instead of its own transform.
@export var close_at := Vector2(-1.0, -1.0)
@export var view_offset := Vector3(-45.0, 40.0, -20.0)

var _index := 0


func _ready() -> void:
	_index = maxi(0, GameData.gods().find(start_god))
	_show.call_deferred()
	if close_at.x >= 0.0:
		_frame_close.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick"):
		_index = (_index + 1) % GameData.gods().size()
		_show()


func _frame_close() -> void:
	var camera := get_node(camera_path) as Camera3D
	var terrain := TerrainShape.of(self)
	var height := 0.0
	if terrain:
		var found: float = terrain.height_at(close_at.x, close_at.y)
		if not is_nan(found):
			height = found
	var target := Vector3(close_at.x, height, close_at.y)
	camera.global_position = target + view_offset
	camera.look_at(target)


func _show() -> void:
	var god := GameData.gods()[_index]
	var type := GameCatalog.shared().god(String(god))
	var rig := (get_node(world_path) as MatchWorld).map.look
	if type == null or type.look == null or rig == null:
		print("bioma %s sin look" % god)
		return
	rig.apply_profile(type.look)
	print("bioma %s" % god)
