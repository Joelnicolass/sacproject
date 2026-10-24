@tool
class_name ZoneEmitter
extends SpriteEmitter

## The sprites of a zone: a SpriteEmitter that emits from the phase `from_phase` of its zone to the phase `to_phase` (inclusive), on every
## peer, from the zone's replicated phase. The ParticleType says what and how many; this only says when. It does not hurt anyone.

@export var zone: GroundZone
@export var from_phase := GroundZone.Phase.CASTING
@export var to_phase := GroundZone.Phase.ACTIVE


func _ready() -> void:
	super()
	if Engine.is_editor_hint() or zone == null:
		return
	zone.phase_changed.connect(_on_phase)
	_on_phase(zone.phase)


func _on_phase(phase: int) -> void:
	set_active(phase >= from_phase and phase <= to_phase)
