class_name StructureSpawner
extends MpSpawner

## Puts the towers wizards cast into the match: on the server (replicated to every peer) or in solo. The ten tower scenes are
## listed in `scenes`; the spawn message carries the index of the scene, the fount and the side, so every peer builds the same
## tower. Does not decide where a tower may stand: StructureAction does.

const GROUP := &"structure_spawner"

@export var scenes: Array[PackedScene] = []

var _serial := 0


func _ready() -> void:
	add_to_group(GROUP)
	spawn_function = _make
	super._ready()


## Raises `scene` (one of `scenes`) over `fount` for `slot`. `rising`: it is born at build_progress 0 (a cast that starts; the cast
## raises it), else standing. Returns the tower, or null on a client or an unknown scene.
func spawn_tower(scene: PackedScene, fount: ManafountBody, slot: int, yaw: float, rising := false) -> CastTower:
	var index := scenes.find(scene)
	if index < 0 or fount == null:
		return null
	_serial += 1
	var at := fount.anchor()
	var data := {
		"name": "Tower%d" % _serial, "scene": index, "slot": slot, "yaw": yaw,
		"x": at.x, "y": at.y, "z": at.z, "fount": str(fount.get_path()), "rising": rising,
	}
	var tower := spawn_here(data) as CastTower
	if tower != null and not tower.is_rising():
		tower.clear_footprint()
	return tower


func _make(data: Variant) -> Node:
	var info: Dictionary = data
	var tower := scenes[int(info["scene"])].instantiate() as CastTower
	tower.name = str(info["name"])
	tower.position = Vector3(float(info["x"]), float(info["y"]), float(info["z"]))
	tower.rotation.y = float(info["yaw"])
	tower.owner_slot = int(info["slot"])
	tower.fount = get_node_or_null(NodePath(str(info["fount"]))) as ManafountBody
	tower.build_progress = 0.0 if bool(info.get("rising", false)) else 1.0
	return tower
