@tool
class_name LightLook
extends Resource

## Light of one biome: sun, shadows, fill, ambient, exposure and SSAO. One `.tres` per god
## (`data/look/light/<god>_light.tres`); a night is another `.tres`. Nothing here is score or copy.
## SunLayer reads the sun, shadow and fill parts; EnvironmentLayer reads the ambient, exposure and
## screen-space parts. Fog belongs to the SkyLook.

@export var label: String = ""

@export_group("Sun")
## Horizontal direction TOWARD the sun: 0 = +Z (behind the game camera), 90 = +X, 180 = -Z.
@export_range(-180.0, 180.0, 1.0, "degrees") var sun_azimuth_deg: float = 23.0
## Height of the sun above the horizon. Low = long shadows.
@export_range(5.0, 89.0, 1.0, "degrees") var sun_elevation_deg: float = 38.0
@export var sun_color: Color = Color(1.0, 0.93, 0.8)
@export_range(0.0, 8.0, 0.05) var sun_energy: float = 1.6
## Penumbra: angular size of the sun (0 = hard shadow edge).
@export_range(0.0, 3.0, 0.05) var sun_angular_distance: float = 0.7
## How much the sun lights the volumetric fog (1 = like any light). It only scales the
## in-scatter; the milky veil comes from `volumetric_density` (see Fog below).
@export_range(0.0, 4.0, 0.05) var sun_fog_energy: float = 0.3

@export_group("Shadows")
## 1 = black shadow, lower lets the ambient and fill through.
@export_range(0.0, 1.0, 0.01) var shadow_opacity: float = 0.8
## Far end of the sun shadows, in meters (the preset can only lower it).
@export_range(20.0, 1000.0, 1.0, "suffix:m") var shadow_max_distance: float = 220.0
@export_range(0.0, 1.0, 0.01) var split_1: float = 0.06
@export_range(0.0, 1.0, 0.01) var split_2: float = 0.2
@export_range(0.0, 1.0, 0.01) var split_3: float = 0.5
@export var blend_splits: bool = true
@export_range(0.0, 1.0, 0.01) var fade_start: float = 0.85
@export_range(0.0, 2.0, 0.01) var shadow_bias: float = 0.1
@export_range(0.0, 10.0, 0.05) var shadow_normal_bias: float = 1.5
@export_range(0.0, 4.0, 0.05) var shadow_blur: float = 1.2

@export_group("Fill (no shadow, no specular)")
@export var fill_color: Color = Color(0.75, 0.82, 1.0)
## Keep it at or below 0.3 or the scene goes flat.
@export_range(0.0, 1.0, 0.01) var fill_energy: float = 0.25
## Where the fill comes from, as an angle around the sun's azimuth (180 = from the opposite side).
@export_range(-180.0, 180.0, 1.0, "degrees") var fill_azimuth_offset_deg: float = 180.0
@export_range(5.0, 89.0, 1.0, "degrees") var fill_elevation_deg: float = 30.0

@export_group("Ambient")
@export var ambient_color: Color = Color(0.55, 0.65, 0.85)
@export_range(0.0, 3.0, 0.01) var ambient_energy: float = 0.7

@export_group("Exposure")
## The tonemapper of this biome. The default (AgX) is the one `env_base.tres` has; a biome whose ground must keep its
## saturation (Persephone's green) picks another. Only EnvironmentLayer writes it.
@export var tonemap_mode: Environment.ToneMapper = Environment.TONE_MAPPER_AGX
@export_range(0.1, 4.0, 0.01) var tonemap_exposure: float = 1.0
@export_range(0.5, 16.0, 0.1) var tonemap_white: float = 6.0
## 1.15 at most.
@export_range(0.0, 1.5, 0.01) var saturation: float = 1.05

@export_group("SSAO")
@export_range(0.1, 8.0, 0.05, "suffix:m") var ssao_radius: float = 1.2
@export_range(0.0, 8.0, 0.05) var ssao_intensity: float = 1.5
@export_range(0.1, 8.0, 0.05) var ssao_power: float = 1.5
@export_range(0.0, 1.0, 0.01) var ssao_detail: float = 0.5
## How much the occlusion also darkens direct light.
@export_range(0.0, 1.0, 0.01) var ssao_light_affect: float = 0.0

@export_group("SSIL (high preset only)")
@export_range(0.1, 16.0, 0.1, "suffix:m") var ssil_radius: float = 5.0
@export_range(0.0, 8.0, 0.05) var ssil_intensity: float = 1.0


## Unit vector from the ground toward the sun.
func sun_direction() -> Vector3:
	return direction_of(sun_azimuth_deg, sun_elevation_deg)


## Unit vector from the ground toward the fill.
func fill_direction() -> Vector3:
	return direction_of(sun_azimuth_deg + fill_azimuth_offset_deg, fill_elevation_deg)


## Unit vector from the ground toward a body at this compass azimuth (0 = +Z) and elevation, in degrees.
static func direction_of(azimuth_deg: float, elevation_deg: float) -> Vector3:
	var az := deg_to_rad(azimuth_deg)
	var el := deg_to_rad(elevation_deg)
	return Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))
