class_name ZoneStampStop
extends Node

## When its zone is cut (the cast was interrupted) it tells the zone's stamps to take back, at once, the ground they were lifting, on every
## peer (the zone replicates `cancelled`). Without it a stamp keeps playing until the zone is freed. It does not decide when a zone is cut
## (GroundZone) nor what a stamp keeps (TerrainStamp). A zone that ends well keeps what its stamps kept.

@export var zone: GroundZone
@export var stamps: Array[TerrainStamp] = []


func _ready() -> void:
	set_physics_process(zone != null and not Engine.is_editor_hint())


func _physics_process(_delta: float) -> void:
	if not zone.cancelled:
		return
	for stamp in stamps:
		stamp.stop()
	set_physics_process(false)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if zone != null else PackedStringArray(["The zone (GroundZone) that can be cut is missing."])
