class_name AfflictionCues
extends Node

## The sounds of a state: one when it goes on, one when it ends, and a loop while it lasts. Each is a SoundEmitter3D child of the state
## (the SoundCue lives in the emitter). It does not decide when the state is on (Affliction).
## Presentation only, on every peer, from the replicated mask; a dedicated server plays nothing (the emitters stay silent).

@export var affliction: Affliction
@export var on_start: SoundEmitter3D
@export var on_end: SoundEmitter3D
@export var loop: SoundEmitter3D


func _ready() -> void:
	if Engine.is_editor_hint() or affliction == null:
		return
	affliction.shown_changed.connect(_on_shown)
	if loop != null and affliction.is_on():
		loop.set_active(true)


func _on_shown(on: bool) -> void:
	var one_shot := on_start if on else on_end
	if one_shot != null:
		one_shot.play_once()
	if loop != null:
		loop.set_active(on)
