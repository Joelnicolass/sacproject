@tool
class_name NpcSpawn
extends Marker3D

## Where one creature of the map is born. MapPopulation turns every NpcSpawn under the map's `Npcs` into a unit, in tree
## order, on the server or a solo game. The marker's own position and turn are where the unit is put (its feet settle on
## the ground by themselves, so the stored y is a little above the land). In the editor a ghost of the creature and its
## name show over the marker (never saved). It does not replicate: the UnitSpawner does.

const SCENE_PATH := "res://scenes/map/npc_spawn.tscn"

## The creature type (CreatureType in data/catalog/creatures/); drag its .tres here. Its tag (zepe = Farmer, raeb = Taurock)
## is what the unit is spawned with.
@export var creature: CreatureType:
	set(value):
		creature = value
		_refresh_preview()
		update_configuration_warnings()
## The side of the map (not the slot) these creatures belong to: Farmers and Taurocks are sides of their own, apart from the
## players' seats (side = slot - 1). SideRelations puts them in the slots after the seats. MapSides reads it.
@export var side := 0

var _label: Label3D
var _ghost: BodyVisual

## Creature tag, derived from `creature` ("" when none). Setting it looks the type up (TypeRef), for code and old scenes
## that still name a tag; the reference is what is saved.
var tag: String:
	get:
		return creature.tag if creature != null else ""
	set(value):
		creature = TypeRef.creature(value)


## Turn about the vertical axis, radians, as the creature is put (the unit's yaw): read from the marker's own rotation, so
## the gizmo is the truth. Not Basis.get_euler().y, which flips for a turn past a quarter of a circle.
func yaw() -> float:
	var turned := (global_basis if is_inside_tree() else basis).orthonormalized()
	return atan2(turned.z.x, turned.z.z)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if creature == null:
		warnings.append("Elegí una criatura en `creature`: sin ella este punto no genera nada.")
	return warnings


func _ready() -> void:
	if Engine.is_editor_hint():
		_show_preview()


## Editor only and never saved (internal children): the creature's ghost, and its name over the marker.
func _show_preview() -> void:
	var holder := Node3D.new()
	add_child(holder, false, Node.INTERNAL_MODE_FRONT)
	_ghost = BodyVisual.new()
	_ghost.transparency = 0.5
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(_ghost)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.05
	_label.position = Vector3(0.0, 3.0, 0.0)
	add_child(_label, false, Node.INTERNAL_MODE_FRONT)
	_refresh_preview()


func _refresh_preview() -> void:
	if _label != null:
		_label.text = "%s\n%s" % [creature.display_name, tag] if creature != null else ""
	if _ghost != null:
		_ghost.show_model(creature.model if creature != null else "")
