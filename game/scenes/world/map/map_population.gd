class_name MapPopulation
extends Node3D

## What the map's NTTS puts on the field besides the player starts and the founts (RFC-024 addendum 1,
## 024b2): the neutral buildings (houses, fences, decorations) and the creatures of the sides the players do
## not take (26 Farmers of side 2 = slot 3 and 6 Taurocks of side 3 = slot 4). The rows come from
## `assets/original/maps/high_noon/ntts.json` (tools/import_map.py).
## Buildings first (they block the nav grid and peasants look for them), then the creatures. Every peer
## places the buildings (scene nodes with fixed names, health through MapBuilding's synchronizer); only the
## server or a solo game spawns the creatures, through the UnitSpawner (they replicate). Nothing respawns.
## Prints one line: `npc farmer 26 slot 3 · taurock 6 slot 4 · edificios 69 · refugios 11`.

signal populated(report: Dictionary)

@export_file("*.json") var ntts_path := OriginalAssets.HIGH_NOON_NTTS
## Off in scenes that want an empty field; high_noon.tscn turns it on.
@export var spawn_creatures := false
## Structures the scene already places by hand (the founts and the altars).
@export var skip_tags: PackedStringArray = PackedStringArray(["jfnt", "jaal"])
@export var building_scene: PackedScene
@export var buildings_root: Node3D
@export var unit_spawner: UnitSpawner
## Meters above the land where a creature is put; its feet settle on the ground by themselves.
@export var spawn_lift := 0.2

## {npc_spawned: {name: {count, slot}}, buildings_placed, shelters}
var report: Dictionary = {}


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if building_scene == null or buildings_root == null:
		warnings.append("Asigná `building_scene` y `buildings_root`.")
	if spawn_creatures and unit_spawner == null:
		warnings.append("Asigná `unit_spawner` para poner las criaturas.")
	return warnings


func _ready() -> void:
	populate()


func populate() -> void:
	report = {"npc_spawned": {}, "buildings_placed": 0, "shelters": 0}
	var rows := _read()
	if rows.is_empty():
		print("poblados: falta %s; el campo queda sin habitantes ni casas" % ntts_path)
		return
	_place_buildings(rows.get("structures", []))
	if spawn_creatures and _simulates():
		_place_creatures(rows.get("creatures", []))
	print(_line())
	populated.emit(report)


func _simulates() -> bool:
	return not MpKit.is_networked() or MpKit.is_server()


func _place_buildings(structures: Array) -> void:
	var terrain := GroundGuard.terrain_of(self)
	var index := 0
	for row: Dictionary in structures:
		var tag := str(row["tag"])
		index += 1
		if skip_tags.has(tag):
			continue
		var x := float(row["x"])
		var z := float(row["z"])
		var ground := NAN
		if terrain != null and terrain.call("is_on_ground", x, z):
			ground = float(terrain.call("ground_height", x, z))
		if is_nan(ground):
			push_warning("poblados: %s (%.0f, %.0f) cae fuera del terreno; no se pone" % [tag, x, z])
			continue
		var building := building_scene.instantiate() as MapBuilding
		building.name = "Bld%03d_%s" % [index, tag]
		building.tag = tag
		building.owner_slot = SideRelations.slot_of(int(row.get("side", SideRelations.NEUTRAL_SIDE)))
		buildings_root.add_child(building)
		building.global_position = Vector3(x, ground, z)
		building.rotation.y = -deg_to_rad(float(row.get("facing", 0.0)))
		report["buildings_placed"] += 1
		if building.shelter:
			report["shelters"] += 1


func _place_creatures(creatures: Array) -> void:
	var terrain := GroundGuard.terrain_of(self)
	var counts: Dictionary = report["npc_spawned"]
	for row: Dictionary in creatures:
		var tag := str(row["tag"])
		var x := float(row["x"])
		var z := float(row["z"])
		var ground := float(terrain.call("ground_height", x, z)) if terrain != null else NAN
		var slot := SideRelations.slot_of(int(row["side"]))
		var at := Vector3(x, (0.0 if is_nan(ground) else ground) + spawn_lift, z)
		var unit := unit_spawner.spawn_map_creature(tag, slot, at, -float(row.get("facing", 0.0)))
		if unit == null:
			continue
		var type := GameData.creature(tag)
		var key := (type.display_name if type else tag).to_lower()
		var entry: Dictionary = counts.get(key, {"count": 0, "slot": slot})
		entry["count"] = int(entry["count"]) + 1
		counts[key] = entry


func _line() -> String:
	var parts := PackedStringArray()
	var counts: Dictionary = report["npc_spawned"]
	var keys := counts.keys()
	keys.sort()
	for key in keys:
		parts.append("%s %d slot %d" % [key, int(counts[key]["count"]), int(counts[key]["slot"])])
	if parts.is_empty():
		parts.append("npc 0")
	else:
		parts[0] = "npc " + parts[0]
	parts.append("edificios %d" % int(report["buildings_placed"]))
	parts.append("refugios %d" % int(report["shelters"]))
	return " · ".join(parts)


func _read() -> Dictionary:
	if not FileAccess.file_exists(ntts_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ntts_path))
	return parsed if parsed is Dictionary else {}
