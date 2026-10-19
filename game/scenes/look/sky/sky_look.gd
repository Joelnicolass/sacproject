@tool
class_name SkyLook
extends Resource

## Sky of one biome, as layers over the ORIGINAL sky (cylinder, ring and clouds of sky.tscn stay
## visible in every mode) plus an invisible source for ambient, reflections and fog. One `.tres`
## per god (`data/look/sky/<god>_sky.tres`). Applied by `SkyLayer`; nothing here is score or copy.
## Every field is neutral at its default (no new sun, no new clouds, ambient from the color alone).
## Directions are NOT here: the sun disc follows the map's `Sun` (the light layer aims it).

@export var label: String = ""

@export_group("Source (invisible: ambient, reflections, fog)")
## A procedural gradient that no camera sees (the background stays the original color). It feeds
## the ambient of shaded ground, the reflections and the far fog.
@export var top_color: Color = Color(0.38, 0.45, 0.55)
@export var horizon_color: Color = Color(0.65, 0.65, 0.7)
## Below the horizon: the tint ground bounce gives to the ambient from below.
@export var ground_color: Color = Color(0.2, 0.17, 0.13)
@export_range(0.0, 4.0, 0.01) var source_energy: float = 1.0
## 0 = the ambient is the light layer's color alone (classic), 1 = all from this gradient.
@export_range(0.0, 1.0, 0.01) var ambient_sky_contribution: float = 0.0
## Glow of the sun inside the source (what it adds to ambient and reflections on the sun's side).
@export_range(0.0, 90.0, 1.0, "degrees") var sun_glow_angle: float = 25.0
@export_range(0.01, 1.0, 0.01) var sun_glow_curve: float = 0.15

@export_group("Fog seam")
## How much far fog takes the color of the source's horizon (0 = the fog's own color).
@export_range(0.0, 1.0, 0.01) var fog_aerial_perspective: float = 0.0
## Tint of the volumetric haze (albedo). White = the engine default.
@export var haze_tint: Color = Color.WHITE
## How much far fog takes the sky's horizon color (the far land fuses with the sky, as in the
## original). 0 = the theme's own fog color.
@export_range(0.0, 1.0, 0.01) var fog_horizon_mix: float = 0.0

@export_group("Sun and moon discs")
@export var sun_color: Color = Color(1.0, 0.9, 0.7)
@export_range(0.0, 20.0, 0.05) var sun_intensity: float = 0.0
@export_range(0.1, 15.0, 0.1, "degrees") var sun_radius_deg: float = 2.2
@export var halo_color: Color = Color(1.0, 0.7, 0.4)
@export_range(0.0, 4.0, 0.01) var halo_strength: float = 0.0
## Higher = tighter halo around the disc.
@export_range(2.0, 400.0, 1.0) var halo_power: float = 24.0
@export var moon_color: Color = Color(0.75, 0.82, 1.0)
## 0 = no moon.
@export_range(0.0, 20.0, 0.05) var moon_intensity: float = 0.0
@export_range(0.1, 15.0, 0.1, "degrees") var moon_radius_deg: float = 3.0
## Horizontal direction toward the moon: 0 = +Z, 90 = +X (same convention as the sun).
@export_range(-180.0, 180.0, 1.0, "degrees") var moon_azimuth_deg: float = -40.0
@export_range(-10.0, 89.0, 1.0, "degrees") var moon_elevation_deg: float = 40.0

@export_group("Sky mode")
## LEGACY: the original sky (cylinder, ring, clouds of sky.tscn) untouched. SWIRL: a shader sky
## built from the original's own textures and palette, with more depth (see sky_swirl.gdshader).
@export_enum("Legacy", "Swirl") var sky_mode: int = 0

@export_group("Swirl (only in Swirl mode)")
## Number of the original cloud texture repeats across the sky of each layer: bigger = smaller clouds.
@export_range(0.1, 4.0, 0.05) var swirl_scale: float = 0.9
## Drift of the near layer (the far one is slower: parallax).
@export_range(0.0, 0.1, 0.001) var swirl_speed: float = 0.012
@export_range(-180.0, 180.0, 1.0, "degrees") var swirl_wind_deg: float = 60.0
## How much the clouds are stretched and curled by a slow warp.
@export_range(0.0, 1.0, 0.01) var swirl_warp: float = 0.25
## Cloud brightness: 1 is the original's (texture x its energy).
@export_range(0.2, 2.0, 0.01) var swirl_energy: float = 1.0
@export_range(0.0, 1.0, 0.01) var swirl_far_opacity: float = 0.6
## Darkens the underside of the near layer where it overlaps the far one (depth).
@export_range(0.0, 1.0, 0.01) var swirl_depth_shade: float = 0.25
## Warm glow around the sun inside the swirl sky.
@export_range(0.0, 2.0, 0.01) var swirl_sun_glow: float = 0.35


func moon_direction() -> Vector3:
	var az := deg_to_rad(moon_azimuth_deg)
	var el := deg_to_rad(moon_elevation_deg)
	return Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))


## The invisible source. A new material each call: Resources are never mutated at runtime.
func make_sky() -> Sky:
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = top_color
	material.sky_horizon_color = horizon_color
	material.ground_horizon_color = horizon_color.lerp(ground_color, 0.5)
	material.ground_bottom_color = ground_color
	material.sky_energy_multiplier = source_energy
	material.sun_angle_max = sun_glow_angle
	material.sun_curve = sun_glow_curve
	var sky := Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	return sky
