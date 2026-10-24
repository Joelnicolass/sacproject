@tool
class_name SkyLook
extends Resource

## The sky of one biome and what it gives the land besides pixels: ambient light, reflections and far fog.
## One `.tres` per god (`data/look/sky/<god>_sky.tres`). Everything the picture needs is in `material`
## (sacrifice_sky.gdshader: the background color, the two textured bands, the clouds, the aurora): open it
## in the inspector and the sky in the editor follows. EnvironmentLayer is the only one that applies this.

@export var label: String = ""
## A ShaderMaterial of `scenes/look/sky/sacrifice_sky.gdshader`.
@export var material: ShaderMaterial

## The god's picture under the world (themes/<god>/undr.png), seen through the void and the pits on the rig's
## `Underside` layer. Empty = nothing under the island but the sky's own colour.
@export var under_texture: Texture2D

@export_group("Ambient and reflections")
## 0 = the ambient is the light look's color alone, 1 = all of it comes from the sky.
@export_range(0.0, 1.0, 0.01) var ambient_sky_contribution: float = 0.5
## Size of the sky's reflection cubemap: 64 is plenty for a soft gradient.
@export var radiance_size: Sky.RadianceSize = Sky.RADIANCE_SIZE_64

@export_group("Fog")
@export var fog_enabled: bool = true
## Already mixed with the sky's horizon, so the far land fuses with the sky.
@export var fog_color: Color = Color(0.5, 0.55, 0.82)
@export_range(0.0, 4000.0, 1.0, "suffix:m") var fog_begin_m: float = 100.0
@export_range(0.0, 4000.0, 1.0, "suffix:m") var fog_end_m: float = 1600.0
## Most fog there is, at `fog_end_m`.
@export_range(0.0, 4.0, 0.01) var fog_density: float = 1.0
## How much far fog takes the color of the sky behind it.
@export_range(0.0, 1.0, 0.01) var fog_aerial_perspective: float = 0.0
## Tint of the volumetric haze. White = the engine default.
@export var haze_tint: Color = Color.WHITE
## Milky veil of the volumetric fog. The engine default (0.05) buries the game camera in white: keep it near 0.01.
@export_range(0.0, 0.1, 0.001) var volumetric_density: float = 0.01
@export_range(16.0, 512.0, 1.0, "suffix:m") var volumetric_length_m: float = 64.0
