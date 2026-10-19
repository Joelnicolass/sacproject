@tool
class_name MapRoot
extends Node3D

## RFC-044 044a: the root of a map scene (scenes/map/maps/<tag>/map.tscn). It holds the ground, the layout, the
## navmesh region, the starts and founts, the sky and the look of one map, and nothing of the match: the match scene
## (scenes/match/match.tscn) instances it and binds its own systems to these sockets. A map you make in the editor
## fills the sockets it has; the required ones warn.

## The ground (a `terrain.gd` MeshInstance3D).
@export var terrain: MeshInstance3D
@export var nav_region: NavigationRegion3D
## The PlayerStart nodes, one per seat.
@export var starts: Node3D
## The look rig of the map; empty in a map without one.
@export var look: LookRig
## Draws the ground seen from above for the minimap; empty = no minimap picture.
@export var minimap_bake: MinimapTerrainBake
## The MapBuilding and NpcSpawn rows of the layout; empty in a map without houses or inhabitants.
@export var buildings_root: Node3D
@export var npc_spawns_root: Node3D


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for pair in [["terrain", terrain], ["nav_region", nav_region], ["starts", starts]]:
		if pair[1] == null:
			warnings.append("Asigná `%s`." % pair[0])
	return warnings
