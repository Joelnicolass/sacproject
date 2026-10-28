@tool
class_name LookQuality
extends Resource

## One quality preset (low / medium / high): the single place that holds render scale and AA.
## It also holds shadows, SSAO, volumetric and scatter density.
## Defaults are the engine defaults: native resolution, no AA, no upscaler.
##
## Scale modes measured on Forward+ over Metal (4.7).
## Temporal modes (FSR2, MetalFX temporal) are listed to measure them, not to ship them:
## the animation swaps the whole mesh each frame and has no motion vectors, so they ghost.

@export var id: StringName = &"native"
@export var label: String = "Nativa"

@export_group("Render scale")
@export var scaling_mode: Viewport.Scaling3DMode = Viewport.SCALING_3D_MODE_BILINEAR
@export_range(0.25, 1.0, 0.01) var scale: float = 1.0
## FSR 1 sharpness: 0 is the sharpest, 2 the softest.
@export_range(0.0, 2.0, 0.05) var fsr_sharpness: float = 0.2

@export_group("Anti-aliasing")
@export var screen_space_aa: Viewport.ScreenSpaceAA = Viewport.SCREEN_SPACE_AA_DISABLED
@export var msaa_3d: Viewport.MSAA = Viewport.MSAA_DISABLED

@export_group("Sun shadows")
## 2 splits (low) or 4 (medium, high).
@export
var shadow_splits: DirectionalLight3D.ShadowMode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
## Resolution of the directional shadow atlas (global to the renderer).
@export_enum("1024:1024", "2048:2048", "4096:4096", "8192:8192") var shadow_atlas_size: int = 4096
@export var shadow_filter: RenderingServer.ShadowQuality = RenderingServer.SHADOW_QUALITY_SOFT_LOW
## Upper bound for the biome's shadow distance, in meters. 0 = no cap (the biome decides).
@export_range(0.0, 1000.0, 1.0, "suffix:m") var shadow_distance_cap: float = 0.0

@export_group("Screen-space light")
@export var ssao_enabled: bool = true
## Screen-space indirect light: high preset only.
@export var ssil_enabled: bool = false

@export_group("Glow")
## Bloom of the bright parts (the biome's GlowLook). Off in low: it is a full-screen blur chain.
@export var glow_enabled: bool = true

@export_group("Ground")
## 4 = the god's ground also reads its roles' normal and ORM maps; below 4 = colour only. All four
## roles always draw.
@export_range(1, 4) var ground_layers: int = 4
## Rock layers project the maps from three sides (stretch-free cliffs).
@export var ground_triplanar: bool = true
## Two offset taps per layer against visible repetition (high only).
@export var ground_stochastic: bool = false
## Macro drift of color and roughness over hundreds of meters.
@export var ground_macro: bool = true

@export_group("Grass")
@export var grass_enabled: bool = true
## Radius of the ring of grass around the point the camera looks at: where the grass has height 0 is
## 85 % of it. The radius is what a preset saves; the far density is the type's and does not change.
@export_range(10.0, 150.0, 1.0, "suffix:m") var grass_radius_m: float = 45.0
## Inside this radius the blades are at their densest and have the most vertices.
@export_range(5.0, 80.0, 1.0, "suffix:m") var grass_near_radius_m: float = 15.0
## Multiplies the NEAR density of the GrassType (detail inside the near radius); the far density
## is the type's own and no preset lowers it (it is what keeps the ground covered).
@export_range(0.1, 3.0, 0.05) var grass_density_scale: float = 1.0
## Segments of a near blade: 1 = 3 vertices, 2 = 5, 3 = 7.
@export_range(1, 3) var grass_near_segments: int = 2
## Tufts: color and height change from clump to clump.
@export var grass_clumps: bool = true
## Blades flatten under the nearby units and stand up again.
@export var grass_trample: bool = true

@export_group("VFX and weather")
## Sprites fade against the scene depth instead of cutting the ground (shader global
## `fx_soft_particles`).
@export var fx_soft_particles: bool = true
## Atlas frames blend into the next one (shader global `fx_frame_blend`).
@export var fx_frame_blend: bool = true
## Most effect lights on at once (FxLightLayer): shadowless OmniLight3D. 0 = none.
@export_range(0, 64) var fx_max_lights: int = 8

@export_group("Actor lights")
## Most lights of units, wizards and spells on at once (ActorLightBudget): shadowless OmniLight3D. 0
## = none.
@export_range(0, 64) var actor_max_lights: int = 12

@export_group("Ambience")
## Multiplies the drops of the rain (and the snow) of every weather state.
@export_range(0.0, 2.0, 0.05) var rain_density_scale: float = 1.0
## Multiplies the particles of the ambient life (pollen, fireflies...). 0 = no ambient life at all.
@export_range(0.0, 2.0, 0.05) var life_density_scale: float = 1.0

@export_group("Relief")
## The normal maps of the models (SurfaceReliefLayer). Off = every material draws as if it had none;
## the player's «Relieve» option can only turn them off on top of this.
@export var relief_maps: bool = true

@export_group("Vegetation")
## One entry per mesh vegetation layer (FloraField), by the layer's id. A layer without an entry is
## not drawn.
@export var vegetation: Array[VegetationQuality] = []


## The entry of vegetation layer `id`, or null (the layer is not drawn in this preset).
func vegetation_for(id: StringName) -> VegetationQuality:
	for entry in vegetation:
		if entry and entry.layer_id == id:
			return entry
	return null
