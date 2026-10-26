@tool
class_name MapRoot
extends Node3D

## The root of a map scene (scenes/map/maps/<tag>/map.tscn): the ground, the buildings and the creature spawns, the
## navmesh region, the starts and founts, the sky and the look of one map, and nothing of the match. The match scene
## (scenes/match/match.tscn) instances it and binds its own systems to these sockets. A map you make in the editor
## fills the sockets it has; the required ones warn.

## The ground as numbers: heights, holes, size (the child `Shape` of `terrain`). Everyone asks it.
@export var ground: GroundSurface
## The node that holds the ground: a grid map's Terrain, or the root of a mesh map's ground.glb (Chunks, Surface, Collision).
@export var terrain: Node3D
@export var nav_region: NavigationRegion3D
## The PlayerStart nodes, one per seat.
@export var starts: Node3D
## The look rig of the map; empty in a map without one.
@export var look: LookRig
## Draws the ground seen from above for the minimap; empty = no minimap picture.
@export var minimap_bake: MinimapTerrainBake
## Holds the MapBuilding nodes (the building scenes you drag in); empty in a map without houses.
@export var buildings: Node3D
## Holds the NpcSpawn nodes; empty in a map without inhabitants.
@export var npcs: Node3D
## Holds the decoration scenes you drag in (scenes/props/<name>.tscn: arches, rocks, pillars that do not block and have no
## health); empty in a map without any.
@export var props: Node3D


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for pair in [["terrain", terrain], ["ground", ground], ["nav_region", nav_region], ["starts", starts]]:
		if pair[1] == null:
			warnings.append("Asigná `%s`." % pair[0])
	return warnings
