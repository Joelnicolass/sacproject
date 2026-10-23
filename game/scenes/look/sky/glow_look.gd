@tool
class_name GlowLook
extends Resource

## How much the bright parts of a biome bleed light around them: magic, fountains, the sun on water.
## One `.tres` per god (`data/look/glow/<god>_glow.tres`); EnvironmentLayer is the only one that puts it on
## the Environment. The defaults are the engine's own, which is what the game drew before this existed.
## The low quality preset turns glow off whatever is set here.

@export var enabled: bool = true
## How strong the glow is when it is added (the overall volume knob).
@export_range(0.0, 8.0, 0.01) var intensity: float = 0.8
@export_range(0.0, 2.0, 0.01) var strength: float = 1.0
## Makes the glow take more from everything lit, not only from what passes `hdr_threshold`.
@export_range(0.0, 1.0, 0.01) var bloom: float = 0.0
## Only colors brighter than this glow (1.0 = only what is brighter than white).
@export_range(0.0, 4.0, 0.01) var hdr_threshold: float = 1.0
@export_range(0.0, 4.0, 0.01) var hdr_scale: float = 2.0
@export var blend_mode: Environment.GlowBlendMode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
## Weight of each of the 7 blur sizes, the tightest first and the widest last.
@export var levels: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0])
