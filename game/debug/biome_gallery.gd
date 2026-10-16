extends Node

## check_tick cycles the god themes over the High Noon world.

const ThemeApplier := preload("res://scenes/world/theme_applier.gd")

@export var world_path: NodePath = ^"HighNoon"
@export var start_god: StringName = &"persephone"
@export var camera_path: NodePath = ^"ViewCamera"
## When x >= 0 the camera looks at the ground under (x, z) from view_offset instead of its own transform.
@export var close_at := Vector2(-1.0, -1.0)
@export var view_offset := Vector3(-45.0, 40.0, -20.0)

var _index := 0


func _ready() -> void:
	_index = maxi(0, ThemeApplier.GODS.find(start_god))
	_show.call_deferred()
	if close_at.x >= 0.0:
		_frame_close.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick"):
		_index = (_index + 1) % ThemeApplier.GODS.size()
		_show()


func _frame_close() -> void:
	var camera := get_node(camera_path) as Camera3D
	var terrain := get_tree().get_first_node_in_group("terrain")
	var height := 0.0
	if terrain and terrain.has_method("ground_height"):
		var found: float = terrain.ground_height(close_at.x, close_at.y)
		if not is_nan(found):
			height = found
	var target := Vector3(close_at.x, height, close_at.y)
	camera.global_position = target + view_offset
	camera.look_at(target)


func _show() -> void:
	var god := ThemeApplier.GODS[_index]
	var theme := ThemeApplier.theme_for(god)
	if theme == null:
		print("bioma %s sin tema" % god)
		return
	var applied: Resource = ThemeApplier.apply(theme, get_node(world_path))
	print("bioma %s" % god)
	if not applied.missing.is_empty():
		print("bioma %s falta %s" % [god, ", ".join(applied.missing)])
