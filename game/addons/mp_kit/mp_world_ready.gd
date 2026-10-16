class_name MpWorldReady
extends Node

## Optional leftover. MpSpawner already requests world_ready on clients.
## Keep this node only in old scenes; new matches do not need it.

func _ready() -> void:
	if not MpKit.is_networked() or MpKit.is_server():
		return
	if _has_mp_spawner():
		return
	call_deferred("_request")


func _has_mp_spawner() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return _find_spawner(scene)


func _find_spawner(node: Node) -> bool:
	if node is MpSpawner:
		return true
	for child in node.get_children():
		if _find_spawner(child):
			return true
	return false


func _request() -> void:
	if not is_inside_tree():
		return
	if not MpKit.is_networked() or MpKit.is_server():
		return
	MpKit.request_world_ready()
