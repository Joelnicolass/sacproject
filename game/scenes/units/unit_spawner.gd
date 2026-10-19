class_name UnitSpawner
extends MpSpawner

## Spawns creatures (unit_scene) under spawn_path: on the server (replicated) or in solo.
## Names are the creature name plus a count per name: Trogg1, Trogg2, Manahoar1…

@export var unit_scene: PackedScene
## The scene of the map's peasants (RFC-024 addendum 1, 024b2): unit.tscn plus PeasantBehavior.
@export var peasant_scene: PackedScene
@export var rules: MatchRules

var _serials: Dictionary = {}


func _ready() -> void:
	add_to_group("unit_spawner")
	spawn_function = _make
	super._ready()


## data: tag, label (display name), slot, x, y, z, yaw, summoning. Returns the unit, or
## null on a client.
func spawn_unit(data: Dictionary) -> Node3D:
	var label := str(data.get("label", data.get("tag", "Unit"))).replace(" ", "")
	_serials[label] = int(_serials.get(label, 0)) + 1
	data["name"] = "%s%d" % [label, _serials[label]]
	if MpKit.is_networked():
		if MpKit.is_server():
			return spawn(data) as Node3D
		return null
	var unit := _make(data)
	get_node(spawn_path).add_child(unit)
	return unit


## A creature the map puts on the field (MapPopulation): a peasant tag gets peasant_scene, and every one
## joins the group `npc` (SoulSystem and the ledger read it). `slot` is the side of the map plus one.
func spawn_map_creature(tag: String, slot: int, at: Vector3, yaw: float) -> Node3D:
	var type := GameData.creature(tag)
	return spawn_unit({
		"tag": tag, "label": type.display_name if type else tag, "slot": slot,
		"x": at.x, "y": at.y, "z": at.z, "yaw": yaw,
		"npc": true, "peasant": PeasantBehavior.is_peasant_tag(tag),
	})


func _make(data: Variant) -> Node3D:
	var info: Dictionary = data
	var scene := peasant_scene if bool(info.get("peasant", false)) and peasant_scene != null else unit_scene
	var unit: Node3D = scene.instantiate()
	if bool(info.get("npc", false)):
		unit.add_to_group(&"npc")
	unit.name = str(info["name"])
	unit.set("creature_tag", str(info["tag"]))
	unit.set("owner_slot", int(info.get("slot", 0)))
	unit.set("rules", rules)
	unit.position = Vector3(float(info["x"]), float(info["y"]), float(info["z"]))
	unit.rotation.y = float(info.get("yaw", 0.0))
	if bool(info.get("summoning", false)):
		(unit as UnitBody).begin_summon()
	return unit
