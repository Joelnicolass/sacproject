class_name ShotSpawner
extends MpSpawner

## Spawns creature ranged shots under spawn_path: on the server (replicated) or in solo.

const _SHOT := preload("res://scenes/units/attacks/ranged_shot.gd")

var _serial := 0


func _ready() -> void:
	add_to_group("shot_spawner")
	spawn_function = _make
	super._ready()


## `data` = ranged_shot.setup() keys without `name`. Returns the shot (null on a client, which spawns nothing).
func spawn_shot(data: Dictionary) -> RangedShot:
	_serial += 1
	data["name"] = "Shot%d" % _serial
	if MpKit.is_networked():
		if MpKit.is_server():
			return spawn(data) as RangedShot
		return null
	var shot := _make(data) as RangedShot
	get_node(spawn_path).add_child(shot)
	return shot


## F165: a scene that is not a RangedShot but flies in the same container and replicates the same way (the Divine Sight eye).
## `data["scene"]` is its path, `data["name"]` is set here; the scene's root has setup(data). Returns it (null on a client).
func spawn_scene(data: Dictionary) -> Node3D:
	_serial += 1
	if not data.has("name"):
		data["name"] = "%s%d" % [str(data.get("prefix", "Node")), _serial]
	if MpKit.is_networked():
		if MpKit.is_server():
			return spawn(data) as Node3D
		return null
	var node := _make(data) as Node3D
	get_node(spawn_path).add_child(node)
	return node


func _make(data: Variant) -> Node:
	if data is Dictionary and (data as Dictionary).has("scene"):
		var scene := load(str(data["scene"])) as PackedScene
		var node := scene.instantiate()
		node.call("setup", data)
		return node
	var shot: Node3D = _SHOT.new()
	shot.call("setup", data)
	return shot
