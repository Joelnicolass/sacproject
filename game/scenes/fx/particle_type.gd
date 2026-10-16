class_name ParticleType
extends Resource

## Key in res://cache/look/fx/fx.json. The atlas itself stays in the cache.
@export var atlas_key: String = ""
@export var h_frames: int = 4
@export var v_frames: int = 4
## Quad width and height in meters.
@export var size: Vector2 = Vector2.ONE
## Color multiplier of the original shadeless material (HDR).
@export var energy: float = 1.0
## Seconds each atlas frame stays on screen (delay * 2 / 60 in sacengine).
@export var frame_s: float = 1.0 / 30.0
@export var lifetime_s: float = 1.0
## Downward acceleration in m/s². sacengine uses 15 when gravity is on.
@export var gravity: float = 0.0
@export var count: int = 16
@export var speed_min: float = 0.0
@export var speed_max: float = 0.0
## Cone half-angle in degrees around the play direction. 180 = any direction.
@export_range(0.0, 180.0) var spread: float = 180.0
@export var scale_min: float = 1.0
@export var scale_max: float = 1.0
@export var emission_radius: float = 0.0
## Play direction (the cone of `spread` is around it). UP by default; the Sac Doctor's vortex drops drops down.
@export var direction: Vector3 = Vector3.UP
## Start each particle on a random frame of the cycle.
@export var random_start_frame: bool = false
## Continuous emitters only (SpriteEmitter): particles per second. 0 = burst of `count`.
@export var rate_per_s: float = 0.0
## 0 = every particle lives `lifetime_s`; 1 = lifetime uniform in (0, lifetime_s].
@export_range(0.0, 1.0) var lifetime_randomness: float = 0.0
## Alpha follows min(alpha_max, (time_left / fade_s)^2) like sacengine getAlpha. 0 = no fade.
@export var fade_s: float = 0.0
@export_range(0.0, 1.0) var alpha_max: float = 1.0
## Scale follows min(1, time_left / scale_fade_s) like sacengine getScale. 0 = constant.
@export var scale_fade_s: float = 0.0
@export var billboard: bool = true
@export var additive: bool = true

@export_group("Modern look (029a)")
## Meters over which the sprite fades in front of the ground (no straight cut line). 0 = hard edge.
## Only drawn when the preset turns `fx_soft_particles` on.
@export_range(0.0, 4.0, 0.05, "suffix:m") var soft_distance_m: float = 0.6
## Frame n mixes into n + 1 over `frame_s` (same timing, no jump). Only with the preset's `fx_frame_blend`.
@export var frame_blend: bool = true
## Optional color over the normalized life (left = born), multiplies color and alpha: e.g. fire that cools.
@export var color_ramp: GradientTexture1D
## Mix sprites only (`additive` off): shaded and fogged like the ground (blood, dirt, dust).
## Off = the unshaded look of the original. The 11 mix types of data/fx turn it on.
@export var lit: bool = false

@export_group("Pool (029b)")
## Emitters FxBus keeps for this type: puffs per second × lifetime_s × bursts alive at once, plus
## ~25 % because an emitter frees a little after its life (e.g. a trail of 30 puffs/s living 0.517 s on
## 4 projectiles: 30 × 0.517 × 4 × 1.25 ≈ 80).
## 0 = FxBus.max_pooled_per_type.
@export_range(0, 512) var pool_max: int = 0

@export_group("Light (029c)")
## Light each burst gives off, from the rig's FxLightLayer pool (capped by the preset's
## `fx_max_lights`). Empty = no light.
@export var light: FxLightSpec


func cycle_s() -> float:
	return frame_s * float(h_frames * v_frames)


## The atlas loops within one life (more than one cycle, or a random start frame).
func frames_wrap() -> bool:
	return random_start_frame or lifetime_s > cycle_s() * 1.001
