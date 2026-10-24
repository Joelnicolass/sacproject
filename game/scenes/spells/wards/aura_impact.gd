@tool
class_name AuraImpact
extends Node

## The mark an aura leaves on a body it hurts: a burst of sprites on the victim (and the sound that goes with that burst in
## data/audio/fx_sounds.tres), at most once every `every_s` per victim. The server (or solo) decides when; FxBus draws it on every peer.
## It does not hurt anyone (BodyAura) nor draw the ward itself (WardEmitter).
## Ref: sacengine ignite (fire on the victim and ign1, every 1/3 s) and the swarm's sting sound (state.d:17254-17261, 17397-17420).

@export var aura: BodyAura
## What is drawn on the victim. Must live under data/fx/ (FxBus finds it by its file name there).
@export var type: ParticleType
@export_range(0.05, 5.0, 0.0001, "suffix:s") var every_s := 0.3333

## Victim instance id -> MatchClock tick before which it is not marked again.
var _next := {}


func _ready() -> void:
	if Engine.is_editor_hint() or aura == null or type == null:
		return
	aura.stung.connect(_on_stung)


func _on_stung(victim: Node3D) -> void:
	var id := victim.get_instance_id()
	var now := MatchClock.now()
	if now < int(_next.get(id, 0)):
		return
	if not _next.has(id):
		victim.tree_exited.connect(func() -> void: _next.erase(id), CONNECT_ONE_SHOT)
	_next[id] = now + roundi(every_s * MatchClock.TICKS_PER_SECOND_F)
	FxBus.broadcast(type.resource_path.trim_prefix(FxBus.TYPES_DIR).get_basename(), BodyNudge.center(victim))


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if aura == null:
		warnings.append("Falta el BodyAura.")
	if type == null:
		warnings.append("Falta el ParticleType (en data/fx/).")
	return warnings
