extends Node

@export var order: TickOrder
@export var reference_path: String = "res://agent/fixtures/sacengine/tick.txt"
@export var subject: Node3D
## Used when subject is empty: the world's local wizard (spawned at runtime).
@export var world: Node

@onready var _verdict: Label = %Verdict


func _ready() -> void:
	_verdict.text = "Pendiente"


func _get_configuration_warnings() -> PackedStringArray:
	if order == null:
		return PackedStringArray(["Falta TickOrder."])
	return PackedStringArray()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick"):
		_compare()


func _compare() -> void:
	if not FileAccess.file_exists(reference_path):
		_verdict.text = "falta la referencia"
		return
	if order == null:
		_verdict.text = "no coincide"
		return
	var values := _parse_reference(FileAccess.get_file_as_string(reference_path))
	for key in ["n", "order", "x", "y", "z", "life"]:
		if not values.has(key):
			_verdict.text = "no coincide"
			return
	if str(values["order"]) != order.order_name:
		_verdict.text = "no coincide"
		return
	var position := order.start
	var life := order.life
	var step := order.step_axis * order.step_per_tick
	for _tick in int(values["n"]):
		position += step
	var reference_position := Vector3(float(values["x"]), float(values["y"]), float(values["z"]))
	var reference_life := float(values["life"])
	if position.is_equal_approx(reference_position) and is_equal_approx(life, reference_life):
		_verdict.text = "coincide"
		if _subject():
			subject.position += position - order.start
	else:
		_verdict.text = "no coincide"


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
