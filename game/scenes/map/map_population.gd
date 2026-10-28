class_name MapPopulation
extends Node3D

## What the map puts on the field besides the player starts and the founts: the neutral
## buildings (houses, fences, decorations) and the creatures of the sides the players do not take (26 Farmers of side 2 =
## slot 3 and 6 Taurocks of side 3 = slot 4). They are nodes of the map scene: every MapBuilding
## under `buildings` and every NpcSpawn under `npcs`. This node counts the buildings, which every peer has
## (scene nodes with fixed names, health through MapBuilding's synchronizer), and turns the spawns into units through the
## UnitSpawner, in tree order, on the server or a solo game only (they replicate). Nothing respawns.
## The map comes before this node in the tree, so the buildings are ready (and in their groups) when this runs.
## Prints one line: `npc farmer 26 slot 3 · taurock 6 slot 4 · edificios 69 · refugios 11`.

signal populated(report: Dictionary)

## Off in scenes that want an empty field; match.tscn turns it on.
@export var spawn_creatures := false
@export var buildings: Node3D
@export var npcs: Node3D
@export var unit_spawner: UnitSpawner

## {npc_spawned: {name: {count, slot}}, buildings_placed, shelters}
var report: Dictionary = {}


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if buildings == null or npcs == null:
		warnings.append("Assign `buildings` and `npcs`.")
	if spawn_creatures and unit_spawner == null:
		warnings.append("Assign `unit_spawner` to place the creatures.")
	return warnings


func _ready() -> void:
	populate()


func populate() -> void:
	report = {"npc_spawned": {}, "buildings_placed": 0, "shelters": 0}
	if buildings == null or npcs == null:
		print("villages: buildings or npcs missing; the field stays without people or houses")
		return
	_count_buildings()
	if spawn_creatures and is_multiplayer_authority():
		_place_creatures()
	print(_line())
	populated.emit(report)


func _count_buildings() -> void:
	for node in buildings.get_children():
		var building := node as MapBuilding
		if building == null:
			continue
		report["buildings_placed"] += 1
		if building.shelter:
			report["shelters"] += 1


func _place_creatures() -> void:
	var counts: Dictionary = report["npc_spawned"]
	for node in npcs.get_children():
		var spawn := node as NpcSpawn
		if spawn == null:
			continue
		var slot := SideRelations.slot_of(spawn.side)
		if spawn.creature == null:
			continue
		var unit := unit_spawner.spawn_map_creature(spawn.creature, slot, spawn.global_position, spawn.yaw())
		if unit == null:
			continue
		var key := spawn.creature.display_name.to_lower()
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
