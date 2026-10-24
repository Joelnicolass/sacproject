@tool
class_name CarrierLanding
extends Node

## What happens where a falling SpellCarrier goes through the land (`landed`): the wave of earth that stuns what it crosses (a QuakeWave), the
## rocks it throws (a scene every peer plays) and the sprite bursts (rocks, dust, a flash with its light). It does not hurt anyone: the cow
## already gibbed its target on the way (TargetEffect). Server (or solo) only.
## Ref: sacengine cowExplosion, quake (state.d:21749-21786, 25716-25759).

@export var carrier: SpellCarrier
## The wave of earth (a QuakeWave scene; Bovine Intervention's stuns up to 25 m).
@export var wave_scene: PackedScene
## The thrown rocks (a scene with `play(params)`, played on every peer).
@export var burst_scene: PackedScene
## Bursts at the landing point (ParticleTypes under data/fx/).
@export var effects: Array[ParticleType] = []
## Marks the fall leaves on the ground (ScarMark scenes under spells/marks/, played on every peer).
@export var marks: Array[PackedScene] = []


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if carrier != null else PackedStringArray(["Falta el SpellCarrier."])


func _ready() -> void:
	if Engine.is_editor_hint() or carrier == null or not multiplayer.is_server():
		return
	carrier.landed.connect(_on_landed)


func _on_landed(at: Vector3) -> void:
	QuakeWave.launch(wave_scene, carrier, at, carrier.spell.tag if carrier.spell != null else "")
	if burst_scene != null:
		FxBus.broadcast_scene(burst_scene.resource_path, at, {})
	for type in effects:
		FxBus.broadcast(type.bus_name(), at)
	for mark in marks:
		ScarMark.broadcast(mark, at)
