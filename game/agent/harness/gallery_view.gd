extends Node

## Observation only: hides the debug HUD panel and frames the gallery camera, so the models
## are not covered by the text. Does not touch any actor.

func hide_hud() -> void:
	var root := get_tree().current_scene
	var hud := root.get_node_or_null("Hud") if root else null
	if hud:
		hud.set("visible", false)


func show_hud() -> void:
	var root := get_tree().current_scene
	var hud := root.get_node_or_null("Hud") if root else null
	if hud:
		hud.set("visible", true)


func look(x: float, y: float, z: float, tx: float, ty: float, tz: float) -> void:
	var root := get_tree().current_scene
	var camera := root.get_node_or_null("Camera") as Camera3D if root else null
	if camera:
		camera.position = Vector3(x, y, z)
		camera.look_at(Vector3(tx, ty, tz), Vector3.UP)
