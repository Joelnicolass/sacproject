@tool
class_name RitualSounds
extends BodySounds

## Child of sacrifice/ritual.tscn. A sacrifice's sounds from what every peer already has: the replicated `Ritual.phase`
## (phase_changed) and `outcome` (ended, emitted by its setter on every peer).
## - `round_cue` each time the phase becomes `round_phase` (SHOOT: the doctors torture the creature, once a round);
## - `finished_cue` (the creature bursts) when the ritual ends completed (a cancelled one lets the creature go alive);
## - `converted_cue` as well when a Convert ends completed: its souls go to the caster.
## The cues are assigned in ritual.tscn and sound at the ritual's center. No RPC, nothing written. With the AudioGate closed
## it connects nothing. Remove the node to silence every ritual.
## Ref: RFC-052 052h (F367).

@export var ritual: Ritual:
	set(value):
		ritual = value
		update_configuration_warnings()
@export var round_phase := Ritual.Phase.SHOOT
@export_group("Cues")
## One round of the sacrifice.
@export var round_cue: SoundCue
## The ritual ends completed.
@export var finished_cue: SoundCue
## A Convert ends completed (its souls reach the caster).
@export var converted_cue: SoundCue


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint() or not _open or ritual == null:
		return
	ritual.phase_changed.connect(_on_phase_changed)
	ritual.ended.connect(_on_ended)


func anchor() -> Node3D:
	return ritual


## The cue that answers `event`: one of the three exported here.
func default_cue(event: StringName) -> SoundCue:
	match event:
		SoundEvent.SACRIFICE_ROUND:
			return round_cue
		SoundEvent.SACRIFICE_END:
			return finished_cue
		SoundEvent.SOUL:
			return converted_cue
	return null


func _on_phase_changed(phase: Ritual.Phase) -> void:
	if phase == round_phase:
		play(SoundEvent.SACRIFICE_ROUND)


func _on_ended(completed: bool) -> void:
	if not completed:
		return
	play(SoundEvent.SACRIFICE_END)
	if ritual.kind == Ritual.Kind.CONVERT:
		play(SoundEvent.SOUL)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if ritual != null else PackedStringArray(["Asigná en `ritual` el Ritual que suena."])
