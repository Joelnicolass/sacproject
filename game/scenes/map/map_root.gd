@tool
class_name MapRoot
extends Node3D

## The root of a map scene (scenes/map/maps/<tag>/map.tscn): the ground, the buildings and the
## creature spawns, the navmesh region, the starts and founts, the sky and the look of one map, and
## nothing of the match. The match scene (scenes/match/match.tscn) instances it and binds its own
## systems to these sockets. A map you make in the editor fills the sockets it has; the required
## ones warn.

## The map's ground: heights, holes, size, and the mesh that draws it (`terrain.mesh`). Everyone
## asks it.
@export var terrain: Terrain
## The map lies far from where the editor camera opens: in the editor only, the root is shifted so
## the map's centre shows at the origin (the shift is taken off while saving).
@export var editor_recenter := true:
	set(value):
		editor_recenter = value
		_recenter()
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
## Holds the decoration scenes you drag in (scenes/props/<name>.tscn: arches, rocks, pillars that do
## not block and have no health); empty in a map without any.
@export var props: Node3D


func _ready() -> void:
	_recenter()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE and Engine.is_editor_hint():
		position = Vector3.ZERO
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_recenter()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for pair in [["terrain", terrain], ["nav_region", nav_region], ["starts", starts]]:
		if pair[1] == null:
			warnings.append("Assign `%s`." % pair[0])
	return warnings


func _recenter() -> void:
	if Engine.is_editor_hint() and is_node_ready():
		var center := (
			terrain.bounds().get_center() if editor_recenter and terrain != null else Vector2.ZERO
		)
		position = Vector3(-center.x, 0.0, -center.y)
