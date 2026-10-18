@tool
class_name NpcSpawn
extends Marker3D

## Where one creature of the map is born (RFC-035 035d). MapPopulation turns every NpcSpawn under NpcSpawns into a unit,
## in tree order, on the server or a solo game. The marker's own position is where the unit is put (its feet settle on
## the ground by themselves, so the stored y is a little above the land). It does not replicate: the UnitSpawner does.

## Creature tag of the original (zepe = Farmer, raeb = Taurock).
@export var tag := "":
	set(value):
		tag = value
		_refresh_label()
## Side of the map (SIDS), not the slot: slot = side + 1 (SideRelations.slot_of).
@export var side := 0
## Turn about the vertical axis, degrees, positive counterclockwise seen from above.
@export var facing_deg := 0.0
## Id of the entity in the original NTTS, kept to trace an NPC back to the map file.
@export var ntts_id := 0

var _label: Label3D


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
