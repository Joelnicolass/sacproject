extends Node3D

## Every creature and wizard body in rows, fitted to one cell, feet on y = 0: the look each type's body scene wears (BodyLook), scaled by
## the height and reach its BodyFrame saves. Press check_tick to print how many drew a mesh.


@export var body_scene: PackedScene
@export var columns := 14
@export var cell := Vector2(3.4, 8.0)
@export var display_height := 2.4

var _bodies: Array[Node3D] = []


func _ready() -> void:
	var entries := _entries()
	for i in entries.size():
		var entry: Array = entries[i]
		var scene: PackedScene = entry[1]
		var body: Node3D = body_scene.instantiate()
		body.name = String(entry[0]).replace(" ", "_")
		body.get_node("Name").set("text", String(entry[0]))
		var row := i / columns
		var col := i % columns
		body.position = Vector3((col - (columns - 1) * 0.5) * cell.x, 0.0, -row * cell.y)
		%Bodies.add_child(body)
		_dress(body, scene)
		_bodies.append(body)
	call_deferred("_report")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick"):
		_report()
		get_viewport().set_input_as_handled()


## [display name, body scene] of every creature and wizard that has one, once per scene.
func _entries() -> Array:
	var out: Array = []
	var seen := {}
	for type: CreatureType in GameData.all_creatures():
		if type.body != null and not seen.has(type.body):
			seen[type.body] = true
			out.append([type.display_name, type.body])
	for wizard: WizardType in GameData.wizards():
		if wizard.body != null and not seen.has(wizard.body):
			seen[wizard.body] = true
			out.append([wizard.display_name, wizard.body])
	out.sort_custom(func(a: Array, b: Array) -> bool: return String(a[0]) < String(b[0]))
	return out


func _dress(body: Node3D, scene: PackedScene) -> void:
	var facts := BodyFacts.of(scene)
	var height := maxf(facts.height_m, 0.01)
	var reach := maxf(facts.reach_m, 0.01)
	var factor := minf(display_height / height, cell.x * 0.45 / reach)
	body.get_node("Name").position.y = height * factor + 0.5
	var packed := BodyLook.of_body(scene)
	var look := packed.instantiate() as BodyLook if packed != null else null
	if look == null:
		return
	if look.has_model():
		look.scale = Vector3.ONE * factor
		body.add_child(look)
		return
	var holder := MeshInstance3D.new()
	holder.mesh = look.static_mesh
	holder.transform = look.transform
	holder.scale = Vector3.ONE * factor
	holder.position.y *= factor
	body.add_child(holder)
	look.free()


func _report() -> void:
	if not BodyLook.loads_meshes():
		print("cuerpos %d sin mallas en headless" % _bodies.size())
		return
	var drawn := 0
	var empty := PackedStringArray()
	for body in _bodies:
		var has_mesh := false
		for node in body.find_children("*", "MeshInstance3D", true, false):
			if (node as MeshInstance3D).mesh != null:
				has_mesh = true
				break
		if has_mesh:
			drawn += 1
		else:
			empty.append(String(body.name))
	print("cuerpos %d con malla %d" % [_bodies.size(), drawn])
	if not empty.is_empty():
		print("revisar: ", ", ".join(empty))
