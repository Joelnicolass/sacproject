class_name ShotSpawner
extends MpSpawner

## Spawns creature ranged shots under spawn_path: on the server (replicated) or in solo. A packet names its look by the
## resource path of the scene (`"look"`: FxWire.id_of of the ShotLook scene the caller holds, "" = a plain ball) and its ability
## by `"tag"`; only here, on each peer, do they turn back into the resources.
## Not: what a shot does (RangedShot, ShotLook), when a creature shoots (RangedWeapon), which look a shot has (AbilityType.shot_look).

const _SHOT := preload("res://scenes/units/attacks/ranged_shot.gd")
const GROUP := &"shot_spawner"

var _serial := 0


## The spawner of shots in the world, or null.
static func of(tree: SceneTree) -> ShotSpawner:
	return tree.get_first_node_in_group(GROUP) as ShotSpawner


## The node the shots are spawned into.
func container() -> Node:
	return get_node_or_null(spawn_path)


func _ready() -> void:
	add_to_group(GROUP)
	spawn_function = _make
	super._ready()


## `data` = ranged_shot.setup() keys without `name`. Returns the shot (null on a client, which spawns nothing).
func spawn_shot(data: Dictionary) -> RangedShot:
	_serial += 1
	data["name"] = "Shot%d" % _serial
	return spawn_here(data) as RangedShot


## A scene that is not a RangedShot but flies in the same container and replicates the same way (the Divine Sight eye).
## `data["scene"]` is its resource path, `data["name"]` is set here; the scene's root has setup(data). Returns it (null on a
## client).
func spawn_scene(data: Dictionary) -> Node3D:
	_serial += 1
	if not data.has("name"):
		data["name"] = "%s%d" % [str(data.get("prefix", "Node")), _serial]
	return spawn_here(data) as Node3D


func _make(data: Variant) -> Node:
	if data is Dictionary and (data as Dictionary).has("scene"):
		var scene := _scene_of(str(data["scene"]))
		if scene == null:
			push_error("ShotSpawner: cannot make %s" % [data])
			# The spawn function must return a node: an empty one that leaves at once.
			var empty := Node3D.new()
			empty.name = str(data.get("name", "Missing"))
			empty.queue_free.call_deferred()
			return empty
		var node := scene.instantiate()
		node.call("setup", data, GameCatalog.shared().ability(str(data.get("tag", ""))))  # dynamic: the root of any spawnable scene answers setup(data, ability)
		return node
	var shot: RangedShot = _SHOT.new()
	shot.setup(data, GameCatalog.shared().ability(str(data.get("tag", ""))), FxWire.resource(str(data.get("look", ""))) as PackedScene)
	return shot


## The scene a packet names by its resource path, or null when the path is not a scene of this build.
func _scene_of(path: String) -> PackedScene:
	if not path.begins_with("res://") or not ResourceLoader.exists(path, "PackedScene"):
		return null
	return ResourceLoader.load(path, "PackedScene") as PackedScene
