class_name SpellSpawner
extends MpSpawner

## Spawns what a spell puts into the world (projectiles, carriers, drops, zones, walls) under spawn_path: on the server
## (replicated) or in solo. The caller hands it the scene to make, dragged into the caller's own inspector; the wire carries
## that scene's resource path, which is the same file on every peer of the same build. Zones are the exception: see `zones`.

## The group the spawner joins, for whoever starts a spell that raises something (a zone).
const GROUP := &"spell_spawner"
## Spawn-data key with the resource path of the scene to make.
const _SCENE_KEY := "scene"
## Spawn-data key with the kind of a zone in `zones`.
const _ZONE_KEY := "zone"

## Zone and wall scenes by kind, assigned in match.tscn. A zone scene points at its SpellType, the SpellType at its action
## scene, so the action cannot point back at the zone scene: it names its kind here. Root extends SpellProjectile.
@export var zones: Dictionary[String, PackedScene] = {}

var _serial := 0


## The spawner of spell projectiles in the world, or null.
static func of(tree: SceneTree) -> SpellSpawner:
	return tree.get_first_node_in_group(GROUP) as SpellSpawner


func _ready() -> void:
	add_to_group(GROUP)
	spawn_function = _make
	super._ready()


## Makes `scene` (its root extends SpellProjectile) with `data`, the keys its `setup` reads. Returns the node on the server
## and in solo (a spell that must arm or cancel it keeps it), null on a client or when `scene` is missing.
func spawn_scene(scene: PackedScene, data: Dictionary) -> Node:
	if scene == null or scene.resource_path.is_empty():
		push_error("SpellSpawner: no scene file to spawn (data %s)" % [data])
		return null
	_serial += 1
	data["name"] = "%s%d" % [scene.resource_path.get_file().get_basename().to_pascal_case(), _serial]
	data[_SCENE_KEY] = scene.resource_path
	return spawn_here(data)


## Makes a guided projectile or a carrier from its typed launch.
func spawn_launch(scene: PackedScene, launch: ProjectileLaunch) -> Node:
	return spawn_scene(scene, launch.to_dict())


## Makes the zone or wall of `kind` (a key of `zones`) with `data`, the keys its `setup` reads.
func spawn_zone(kind: String, data: Dictionary) -> Node:
	if not zones.has(kind):
		push_error("SpellSpawner: no zone scene for kind «%s» in `zones`" % kind)
		return null
	_serial += 1
	data["name"] = "%s%d" % [kind, _serial]
	data[_ZONE_KEY] = kind
	return spawn_here(data)


func _make(data: Variant) -> Node:
	var info: Dictionary = data
	var scene := _scene_of(info)
	if scene == null:
		push_error("SpellSpawner: cannot make %s" % [info])
		# The spawn function must return a node: an empty one that leaves at once.
		var empty := SpellProjectile.new()
		empty.name = str(info.get("name", "Missing"))
		empty.queue_free.call_deferred()
		return empty
	var effect := scene.instantiate() as SpellProjectile
	effect.setup(info)
	return effect


func _scene_of(info: Dictionary) -> PackedScene:
	if info.has(_ZONE_KEY):
		return zones.get(str(info[_ZONE_KEY])) as PackedScene
	var path := str(info.get(_SCENE_KEY, ""))
	if not path.begins_with("res://") or not ResourceLoader.exists(path, "PackedScene"):
		return null
	return ResourceLoader.load(path, "PackedScene") as PackedScene
