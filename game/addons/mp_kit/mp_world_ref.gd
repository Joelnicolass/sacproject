class_name MpWorldRef
extends Resource

## One selectable world for MpFlow. Id is the stable key (lobby toggle, snapshot).

@export var id: StringName = &"main"
@export var scene: PackedScene
@export var path: String = ""


func resolve_path() -> String:
	var p := path.strip_edges()
	if not p.is_empty():
		return p
	if scene != null:
		return scene.resource_path
	return ""
