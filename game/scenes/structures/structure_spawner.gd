extends MpSpawner

## Spawns built structures under spawn_path: on the server (replicated) or in solo.

@export var structure_scene: PackedScene
@export var rules: MatchRules

var _serial := 0


func _ready() -> void:
	add_to_group("structure_spawner")
	spawn_function = _make
	super._ready()


## data: model, spell_tag, slot, x, y, z, yaw, manafount_path. Returns the structure, or null on clients.
func spawn_structure(data: Dictionary) -> Node3D:
	_serial += 1
	data["name"] = "Structure%d" % _serial
	if MpKit.is_networked():
		if MpKit.is_server():
			return spawn(data) as Node3D
		return null
	var structure := _make(data)
	get_node(spawn_path).add_child(structure)
	return structure


func _make(data: Variant) -> Node3D:
	var info: Dictionary = data
	var structure: Node3D = structure_scene.instantiate()
	structure.name = str(info["name"])
	structure.position = Vector3(float(info["x"]), float(info["y"]), float(info["z"]))
	structure.rotation.y = float(info.get("yaw", 0.0))
	structure.set("owner_slot", int(info.get("slot", 0)))
	structure.set("model", str(info.get("model", "")))
	structure.set("spell_tag", str(info.get("spell_tag", "")))
	structure.set("manafount_path", NodePath(str(info.get("manafount_path", ""))))
	structure.set("rules", rules)
	return structure
