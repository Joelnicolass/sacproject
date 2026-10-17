extends Node

@export var tick: StateTick
@export var reference_path: String = "res://agent/fixtures/sacengine/tick_state.txt"
@export var subject: Node3D
## Used when subject is empty: the world's local wizard (spawned at runtime).
@export var world: Node
@export var camera: Camera3D

@onready var _verdict: Label = %Verdict


func _ready() -> void:
	_verdict.text = "Pendiente"


func _get_configuration_warnings() -> PackedStringArray:
	if tick == null:
		return PackedStringArray(["Falta StateTick."])
	return PackedStringArray()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick"):
		_compare()


func _compare() -> void:
	if not FileAccess.file_exists(reference_path):
		_verdict.text = "falta la referencia"
		return
	if tick == null or _subject() == null:
		_verdict.text = "no coincide"
		return
	var values := _parse_reference(FileAccess.get_file_as_string(reference_path))
	for key in ["n", "order", "x", "y", "z"]:
		if not values.has(key):
			_verdict.text = "no coincide"
			return
	if str(values["order"]) != tick.order_name or int(values["n"]) != tick.frame_count:
		_verdict.text = "no coincide"
		return
	var placed := Vector3(float(values["x"]), float(values["z"]), float(values["y"]))
	if placed.is_equal_approx(subject.position):
		_verdict.text = "no coincide"
		return
	subject.position = placed
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
