class_name UnitSpawner
extends MpSpawner

## Spawns creatures (unit_scene) under spawn_path: on the server (replicated) or in solo.
## Names are the creature name plus a count per name: Trogg1, Trogg2, Manahoar1…

## The spawner of the match (one per world): the AI and the summons find it here.
const GROUP := &"unit_spawner"
## Creatures the map placed for the sides no player takes.
const NPC_GROUP := &"npc"

@export var unit_scene: PackedScene
## The scene of the map's villagers: unit.tscn plus a Brain (flee, cower, work) and the grudges.
@export var villager_scene: PackedScene
@export var rules: MatchRules

var _serials: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)
	spawn_function = _make
	super._ready()


## data: tag, label (display name), slot, x, y, z, yaw, summoning. Returns the unit, or
## null on a client.
func spawn_unit(data: Dictionary) -> Node3D:
	var label := str(data.get("label", data.get("tag", "Unit"))).replace(" ", "")
	_serials[label] = int(_serials.get(label, 0)) + 1
	data["name"] = "%s%d" % [label, _serials[label]]
	return spawn_here(data) as Node3D


## A creature the map puts on the field (MapPopulation): a type with `peasant` gets villager_scene, and every one
## joins the group `npc` (SoulSystem and the ledger read it). `slot` is the side of the map plus one.
func spawn_map_creature(type: CreatureType, slot: int, at: Vector3, yaw: float) -> Node3D:
	return spawn_unit(
		{
			"tag": type.id(),
			"label": type.display_name,
			"slot": slot,
			"x": at.x,
			"y": at.y,
			"z": at.z,
			"yaw": yaw,
			"npc": true,
			"peasant": type.peasant,
		}
	)


func _make(data: Variant) -> Node3D:
	var info: Dictionary = data
	var scene := (
		villager_scene
		if bool(info.get("peasant", false)) and villager_scene != null
		else unit_scene
	)
	var unit: Node3D = scene.instantiate()
	if bool(info.get("npc", false)):
		unit.add_to_group(NPC_GROUP)
	unit.name = str(info["name"])
	unit.set("type", GameCatalog.shared().creature(str(info["tag"])))
	unit.set("owner_slot", int(info.get("slot", 0)))
	unit.set("rules", rules)
	unit.position = Vector3(float(info["x"]), float(info["y"]), float(info["z"]))
	unit.rotation.y = float(info.get("yaw", 0.0))
	if bool(info.get("summoning", false)):
		(unit as UnitBody).begin_summon()
	return unit
