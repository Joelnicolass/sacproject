class_name FxSounds
extends Node

## What the bursts and the beams of FxBus sound like: when one plays on this peer, this node plays the `sound` its
## ParticleType or BeamType carries, at the place of the effect. It decides nothing about the effect and sends nothing
## over the network: a broadcast FX reaches every peer through the RPC FxBus already has, and each peer hears its own.
## - A trail's puffs never sound (even when their type has a sound as a burst), and a scene FX sounds through the
##   SoundEmitter3D inside the scene, not here.
## - A type with no `sound`, or a silent one, is silence (no log entry).
## - With the AudioGate closed (dedicated server, room server, headless run) it connects to nothing.


func _ready() -> void:
	if AudioGate.is_open():
		FxBus.played.connect(_on_played)


## The sound of an FX of `kind` (the `sound` of its ParticleType or BeamType), or null when it has none.
func cue_of(kind: StringName, fx: Resource) -> SoundCue:
	var found: SoundCue = null
	if kind == FxBus.KIND_BURST and fx is ParticleType:
		found = (fx as ParticleType).sound
	elif kind == FxBus.KIND_BEAM and fx is BeamType:
		found = (fx as BeamType).sound
	return found if found != null and not found.is_silent() else null


func _on_played(kind: StringName, fx: Resource, at: Vector3) -> void:
	var found := cue_of(kind, fx)
	if found != null:
		SoundBus.play_3d(found, at, StringName(FxWire.label_of(fx)), SoundEvent.FX)
