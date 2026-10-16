extends Node

@export var sky_path: NodePath = ^"../HighNoon/Sky"


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick"):
		report()


func report() -> void:
	var sky := get_node_or_null(sky_path)
	if sky == null or not sky.has_method("current_angle"):
		return
	print("cielo angulo %.3f" % sky.current_angle())
