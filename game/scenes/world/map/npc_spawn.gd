@tool
class_name NpcSpawn
extends Marker3D

## Where one creature of the map is born (RFC-035 035d). MapPopulation turns every NpcSpawn under NpcSpawns into a unit,
## in tree order, on the server or a solo game. The marker's own position is where the unit is put (its feet settle on
## the ground by themselves, so the stored y is a little above the land). It does not replicate: the UnitSpawner does.

## The creature type (CreatureType in data/catalog/creatures/); drag its .tres here. Its tag (zepe = Farmer, raeb = Taurock)
## is what the unit is spawned with.
@export var creature: CreatureType:
	set(value):
		creature = value
		_refresh_label()
		update_configuration_warnings()
## Side of the map (SIDS), not the slot: slot = side + 1 (SideRelations.slot_of).
@export var side := 0
## Id of the entity in the original NTTS, kept to trace an NPC back to the map file.
@export var ntts_id := 0

var _label: Label3D

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
		_show_label()


## Editor only and never saved (no owner): the tag over the marker.
func _show_label() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.05
	_label.position = Vector3(0.0, 3.0, 0.0)
	add_child(_label, false, Node.INTERNAL_MODE_FRONT)
	_refresh_label()


func _refresh_label() -> void:
	if _label != null:
		_label.text = tag
