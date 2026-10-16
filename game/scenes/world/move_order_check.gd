extends Node

@export var order: MoveOrder
@export var reference_path: String = "res://cache/tick_move_ref.txt"
@export var subject: Node3D
## Used when subject is empty: the world's local wizard (spawned at runtime).
@export var world: Node
@export var camera: Camera3D

@onready var _verdict: Label = %Verdict


func _ready() -> void:
	_verdict.text = "Pendiente"


func _get_configuration_warnings() -> PackedStringArray:
	if order == null:
		return PackedStringArray(["Falta MoveOrder."])
	return PackedStringArray()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick"):
		_compare()


func _compare() -> void:
	if not FileAccess.file_exists(reference_path):
		_verdict.text = "falta la referencia"
		return
	if order == null or _subject() == null:
		_verdict.text = "no coincide"
		return
	var values := _parse_reference(FileAccess.get_file_as_string(reference_path))
	for key in ["n", "order", "x", "y", "z"]:
		if not values.has(key):
			_verdict.text = "no coincide"
			return
	if str(values["order"]) != order.order_name:
		_verdict.text = "no coincide"
		return
	var sac_x := float(values["x"])
	var sac_y := float(values["y"])
	var plane := Vector2(sac_x - order.spawn_sac.x, sac_y - order.spawn_sac.y)
	if plane.length() <= order.min_plane_distance:
		_verdict.text = "no coincide"
		return
	subject.position = Vector3(sac_x, float(values["z"]), sac_y)
	if camera:
		camera.position = subject.position + Vector3(-14, 10, 14)
		camera.look_at(subject.position + Vector3(0, 1.2, 0))
	_verdict.text = "coincide"


func _parse_reference(text: String) -> Dictionary:
	var values := {}
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		var split_at := line.find("=")
		if split_at <= 0:
			continue
		values[line.substr(0, split_at).strip_edges()] = line.substr(split_at + 1).strip_edges()
	return values


func _subject() -> Node3D:
	if subject == null and world and world.has_method("local_wizard"):
		subject = world.call("local_wizard")
	return subject
