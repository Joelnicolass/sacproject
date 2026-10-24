@tool
class_name ZoneSound
extends SoundEmitter3D

## The sound of a zone, on every peer, from its phase: a loop from the phase `from_phase` to the phase `to_phase` (the balls of Explosion burn
## from the cast to the blast), or one shot when the zone enters `from_phase`. It names a key of the sound table (SoundEmitter3D) and plays it
## at this node; it does not decide when a zone changes phase (GroundZone). A dedicated server or a headless run plays nothing.

enum When { WHILE_PHASES, WHEN_ENTERS }

@export var zone: GroundZone
@export var when := When.WHILE_PHASES
@export var from_phase := GroundZone.Phase.CASTING
## The last phase of a loop (inclusive).
@export var to_phase := GroundZone.Phase.ARMING


func _ready() -> void:
	play_on_ready = false
	loop = when == When.WHILE_PHASES
	active = false
	super()
	if Engine.is_editor_hint() or zone == null:
		return
	zone.phase_changed.connect(_on_phase)
	_on_phase(zone.phase)


func _on_phase(phase: int) -> void:
	if when == When.WHEN_ENTERS:
		if phase == from_phase:
			play_once()
	else:
		set_active(phase >= from_phase and phase <= to_phase)
