@tool
class_name PrecipitationLook
extends Resource

## What falls from the sky in one weather state (rain, snow): how a drop moves and looks, how many
## there are at full strength and what the bed of it sounds like. Embedded in the state's `.tres`
## (`scenes/look/weather/rain.tres`). PrecipitationFall shows it; the state says how much.

## How a drop moves (a ParticleProcessMaterial: emission box around the camera, speed, gravity).
@export var process_material: ParticleProcessMaterial
## What a drop looks like (a QuadMesh with its own material; placeholder art).
@export var mesh: Mesh
## Drops alive at once at full strength, before the quality preset scales them
## (`rain_density_scale`).
@export_range(0, 20000, 10) var amount: int = 4000
## Seconds a drop lives (time to fall through the box).
@export_range(0.2, 30.0, 0.1, "suffix:s") var lifetime_s: float = 1.6
## The loop that plays while it falls, louder the stronger it falls. Empty = silent (snow).
@export var sound: SoundCue
