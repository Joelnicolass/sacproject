@tool
class_name WeatherState
extends Resource

## One kind of weather (clear, fog, rain, storm, snow), a type template: `data/look/weather/<state>.tres`, never written
## at runtime. Its numbers bend the biome's approved look: multipliers (1 = as approved) and amounts (0 = nothing).
## Clear is all neutral. A new weather = duplicate one of these and add a WeatherChance to the plan.

@export var display_name: String = ""

@export_group("Light")
@export_range(0.0, 2.0, 0.01) var sun_energy_mul: float = 1.0
@export_range(0.0, 2.0, 0.01) var ambient_mul: float = 1.0

@export_group("Sky")
## Multiplies the whole sky and the fog color.
@export var sky_tint: Color = Color.WHITE
## 0 = the sky's colors, 1 = grey.
@export_range(0.0, 1.0, 0.01) var sky_grey: float = 0.0
## Extra cloud cover over the sky's own clouds (0..1), how much darker they are, and how much faster they drift.
@export_range(0.0, 1.0, 0.01) var cloud_cover: float = 0.0
@export_range(0.0, 1.0, 0.01) var cloud_darken: float = 0.0
@export_range(0.0, 8.0, 0.01) var cloud_speed_mul: float = 1.0

@export_group("Fog")
@export_range(0.0, 4.0, 0.01) var fog_density_mul: float = 1.0
## Multiplies where the fog is thickest: below 1 brings it closer.
@export_range(0.1, 2.0, 0.01) var fog_end_mul: float = 1.0

@export_group("Precipitation")
## How strong it falls (0..1): the drops and the sound of `precipitation`.
@export_range(0.0, 1.0, 0.01) var rain: float = 0.0
## What falls. Empty = nothing.
@export var precipitation: PrecipitationLook

@export_group("Storm (058-3)")
## Lightning strikes a minute (0 = none) and how bright a flash is (sky and ambient, never the glow).
@export_range(0.0, 20.0, 0.1) var strikes_per_min: float = 0.0
@export_range(0.0, 1.0, 0.01) var flash_strength: float = 0.0


## This weather's numbers as an atmosphere sample (multipliers and amounts).
func to_sample() -> AtmosphereSample:
	var out := AtmosphereSample.neutral()
	out.weather = self
	out.light_energy = sun_energy_mul
	out.ambient_energy = ambient_mul
	out.sky_tint = sky_tint
	out.sky_grey = sky_grey
	out.fog_density = fog_density_mul
	out.fog_end = fog_end_mul
	out.rain = rain
	out.cloud_cover = cloud_cover
	out.cloud_darken = cloud_darken
	out.cloud_speed_mul = cloud_speed_mul
	return out
