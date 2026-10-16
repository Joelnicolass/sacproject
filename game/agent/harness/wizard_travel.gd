extends Node

## Read-only: how far the local wizard moved on the ground since this peer first saw him.
## «quieto» under STILL_M, «caminó» past it. Online clients do not simulate, so a change
## here comes from the server's snapshots.

const STILL_M := 1.0

var text := "sin mago"
var _start := Vector2.INF


func _process(_delta: float) -> void:
	var wizard := get_tree().get_first_node_in_group("local_wizard") as Node3D
	if wizard == null:
		return
	var flat := Vector2(wizard.position.x, wizard.position.z)
	if _start == Vector2.INF:
		_start = flat
	var moved := flat.distance_to(_start)
	text = "%s %.1f m" % ["caminó" if moved >= STILL_M else "quieto", moved]


func set_pointer(x: float, y: float) -> void:
	var root := get_tree().current_scene
	var camera := root.get_node_or_null("HighNoon/Camera") if root else null
	if camera == null and root:
		camera = root.get_node_or_null("%Camera")
	if camera and "debug_pointer" in camera:
		camera.set("debug_pointer", Vector2(x, y))


func set_pointer_world(x: float, y: float, z: float) -> Variant:
	var root := get_tree().current_scene
	var camera := root.get_node_or_null("HighNoon/Camera") if root else null
	if camera == null and root:
		camera = root.get_node_or_null("%Camera")
	if camera == null or not ("debug_pointer" in camera):
		return null
	var screen: Vector2 = camera.unproject_position(Vector3(x, y, z))
	camera.set("debug_pointer", screen)
	return screen


func local_wizard_position() -> Variant:
	var wizard := get_tree().get_first_node_in_group("local_wizard") as Node3D
	return wizard.position if wizard else null


func walk_to(x: float, z: float) -> bool:
	var wizard := get_tree().get_first_node_in_group("local_wizard") as Node3D
	if wizard == null or not wizard.has_method("request_walk"):
		return false
	var y := wizard.position.y
	wizard.request_walk(Vector3(x, y, z))
	return true
