class_name ShotSpawner
extends MpSpawner

## Spawns creature ranged shots under spawn_path: on the server (replicated) or in solo.

const _SHOT := preload("res://scenes/world/units/ranged_shot.gd")

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


func _make(data: Variant) -> Node:
	var shot: Node3D = _SHOT.new()
	shot.call("setup", data)
	return shot
