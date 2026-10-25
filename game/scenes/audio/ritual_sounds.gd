@tool
class_name RitualSounds
extends BodySounds

## RFC-052 052h (F367): child of sacrifice/ritual.tscn. A sacrifice's sounds from what every peer already has: the replicated
## `Ritual.phase` (phase_changed) and `outcome` (ended, emitted by its setter on every peer).
## - `sacrifice_round` (the original's Xsac) each time the phase becomes `round_phase` (SHOOT: the doctors torture the
##   creature, once a round);
## - `sacrifice_end` (Xgib: the creature bursts) when the ritual ends completed (a cancelled one lets the creature go alive);
## - `soul` (spir) as well when a Convert ends completed: its souls go to the caster.
## The cues come from the world set (`world.tres`), at the ritual's center. No RPC, nothing
## written. With the AudioGate closed it connects nothing. Remove the node to silence every ritual.

@export var ritual: Ritual:
	set(value):
		ritual = value
		update_configuration_warnings()
@export var round_phase := Ritual.Phase.SHOOT


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint() or not _open or ritual == null:
		return
	ritual.phase_changed.connect(_on_phase_changed)
	ritual.ended.connect(_on_ended)


func anchor() -> Node3D:
	return ritual


## WORKAROUND: the cue comes from the world set (`world.tres`, found by its text key) until 055o-c gives this node typed cues.
func default_cue(event: StringName) -> SoundCue:
	return SoundBus.lookup("world", event)


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
