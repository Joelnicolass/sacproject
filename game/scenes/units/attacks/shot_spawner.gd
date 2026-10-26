class_name ShotSpawner
extends MpSpawner

## Spawns creature ranged shots under spawn_path: on the server (replicated) or in solo. A packet names its look by path
## (`"look"`: FxWire.id_of of a data/shots/ scene, "" = a plain ball) and its ability by `"tag"`; only here, on each peer, do they turn
## back into the resources. Also the default look of a creature's attack (`default_look`), the one lookup of a look by tag.
## Not: what a shot does (RangedShot, ShotLook), when a creature shoots (RangedWeapon).

const _SHOT := preload("res://scenes/units/attacks/ranged_shot.gd")
const GROUP := &"shot_spawner"
const LOOKS_DIR := "res://data/shots/"

## The default look of each ability tag looked up so far (null = it has none): the lookup runs once per tag, not once per shot.
static var _looks: Dictionary[String, PackedScene] = {}

var _serial := 0


## The spawner of shots in the world, or null.
static func of(tree: SceneTree) -> ShotSpawner:
	return tree.get_first_node_in_group(GROUP) as ShotSpawner


## The look a creature's ranged `ability` flies with when nothing else names one: res://data/shots/<tag>.tscn, or null (a plain ball).
static func default_look(ability: AbilityType) -> PackedScene:
	if ability == null or ability.tag.is_empty():
		return null
	if not _looks.has(ability.tag):
		var path := LOOKS_DIR + ability.tag + ".tscn"
		_looks[ability.tag] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	return _looks[ability.tag]


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
		node.call("setup", data, GameData.ability(str(data.get("tag", ""))))  # dynamic: the root of any spawnable scene answers setup(data, ability) (F165)
		return node
	var shot: RangedShot = _SHOT.new()
	shot.setup(data, GameData.ability(str(data.get("tag", ""))), FxWire.resource(str(data.get("look", ""))) as PackedScene)
	return shot
