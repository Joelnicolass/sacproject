extends Node3D

## Every baked body in rows, fitted to one cell, feet on y = 0.


@export var body_scene: PackedScene
@export var columns := 14
@export var cell := Vector2(3.4, 8.0)
@export var display_height := 2.4

var _bodies: Array[Node3D] = []


func _ready() -> void:
	var names := _names()
	var models := BodyCatalog.models()
	models.sort()
	for i in models.size():
		var model := models[i]
		var body: Node3D = body_scene.instantiate()
		body.name = model
		body.get_node("Visual").set("model", model)
		body.get_node("Name").set("text", "%s\n%s" % [names.get(model, model), model])
		var row := i / columns
		var col := i % columns
		body.position = Vector3((col - (columns - 1) * 0.5) * cell.x, 0.0, -row * cell.y)
		%Bodies.add_child(body)
		_fit(body, model)
		_bodies.append(body)
	call_deferred("_report")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick"):
		_report()
		get_viewport().set_input_as_handled()


func _fit(body: Node3D, model: String) -> void:
	var info := BodyCatalog.info(model)
	var height := maxf(float(info.get("height", 1.0)), 0.01)
	var reach := maxf(float(info.get("reach", 0.5)), 0.01)
	var factor := minf(display_height / height, cell.x * 0.45 / reach)
	var visual: Node3D = body.get_node("Visual")
	visual.scale = Vector3.ONE * factor
	visual.position.y *= factor
	body.get_node("Name").position.y = height * factor + 0.5


func _report() -> void:
	if not BodyCatalog.loads_meshes():
		print("cuerpos %d sin mallas en headless" % _bodies.size())
		return
	var standing := 0
	var lying := PackedStringArray()
	for body in _bodies:
		var visual := body.get_node("Visual") as MeshInstance3D
		if visual.mesh == null:
			lying.append(body.name + " (sin malla)")
			continue
		var box := visual.global_transform * visual.mesh.get_aabb()
		var grounded := absf(box.position.y) < 0.05
		var checked := bool(BodyCatalog.info(String(body.name)).get("upright_checked", false))
		var upright := checked or box.size.y * 1.6 >= box.size.z
		if grounded and upright:
			standing += 1
		else:
			lying.append(String(body.name))
	print("cuerpos %d de pie %d" % [_bodies.size(), standing])
	if not lying.is_empty():
		print("revisar: ", ", ".join(lying))


func _names() -> Dictionary:
	var names := {}
	for wizard in GameData.wizards():
		names[wizard.model_id()] = wizard.display_name
	for type in GameData.all_creatures():
		if not names.has(type.model_id()):
			names[type.model_id()] = type.display_name
	return names
