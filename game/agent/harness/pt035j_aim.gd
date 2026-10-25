extends Node

## RFC-035 cut 035j playtest: the player's cursor on the ground. aim_ground(x, z) puts the world camera's
## debug_pointer on the screen spot of a ground point, the same spot a right click there would hit, so the next
## order_units (InputMap action, a real right click through the product's match_command) moves the selection to it.
## It moves no actor. report() prints the Hunter's position and mode (UnitBody.Mode).

var _last := ""


func _ready() -> void:
	process_priority = 1000


func _root() -> Node:
	return get_tree().current_scene


func aim_ground(x: float, z: float) -> String:
	var root := _root()
	if root == null:
		return "sin escena"
	var cam := root.get_node_or_null("HighNoon/Camera") as Camera3D
	var terrain = GroundSurface.of(root)
	if cam == null or terrain == null:
		return "sin camara o terreno"
	var y: float = float(terrain.height_at(x, z))
	var spot := Vector3(x, 0.0 if is_nan(y) else y, z)
	var screen := cam.unproject_position(spot)
	cam.set("debug_pointer", screen)
	_last = "pointer (%d, %d) en suelo (%.0f, %.0f)" % [screen.x, screen.y, x, z]
	return _last


func report() -> String:
	var root := _root()
	if root == null:
		return "sin escena"
	var hunter := root.find_child("Hunter", true, false) as Node3D
	if hunter == null:
		return "sin Hunter"
	var p := hunter.global_transform.origin
	return "Hunter (%.1f, %.1f) modo %s" % [p.x, p.z, str(hunter.get("mode"))]
