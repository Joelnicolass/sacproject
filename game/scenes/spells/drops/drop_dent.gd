@tool
class_name DropDent
extends Node

## When its drop ends (a meteorite hits the ground) it leaves the dent of its `manual` TerrainStamp under the drop for good: the server
## works the numbers out and commits them, and every client applies the same bytes. It does not fly the drop (ZoneDrop) nor shape the
## dent (the stamp's StampProfile and Reach cylinder). Server (or solo) only.
## Ref: sacengine bombardmentDent, dentDisplacement (state.d:4077-4083, 7303-7315).

@export var drop: ZoneDrop
@export var stamp: TerrainStamp


func _ready() -> void:
	if not Engine.is_editor_hint() and drop != null and stamp != null and multiplayer.is_server():
		drop.ended.connect(_leave_dent)


func _leave_dent(_body: Node3D, _at: Vector3) -> void:
	var deformer := TerrainDeformer.of(self)
	if deformer == null or not stamp.is_ready():
		return
	var rect := stamp.vertex_rect()
	deformer.commit(rect, stamp.values_at(stamp.profile.duration_s() - 1e-4, rect), String(stamp.get_path()))


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if drop != null and stamp != null else PackedStringArray(["Faltan la gota (ZoneDrop) y el sello (TerrainStamp con manual) de la abolladura."])
