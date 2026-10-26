@tool
class_name AmbientSwarm
extends Resource

## One kind of ambient life (pollen, fireflies, gnats, dust, embers, ash, spores), a type template:
## `data/look/life/<name>.tres`, never written at runtime. How its motes move and look, how many there are, and when
## they show. A god's AmbientLifeSet says where (in the air around the camera, or in which habitat of the map).

## How a mote moves (a ParticleProcessMaterial; a LifeSpot fits its emission box to the spot's box).
@export var process_material: ParticleProcessMaterial
## What a mote looks like (a small mesh with its own material; placeholder art).
@export var mesh: Mesh
## Motes alive at once at full quality (the preset's `life_density_scale` multiplies it).
@export_range(1, 2000, 1) var amount: int = 100
@export_range(0.5, 60.0, 0.1, "suffix:s") var lifetime_s: float = 6.0

@export_group("When")
@export var by_day: bool = true
@export var by_night: bool = false
## False: gone while it rains or snows.
@export var in_rain: bool = false


## True when this swarm shows in `sample` (day or night, rain).
func shows_in(sample: AtmosphereSample) -> bool:
	var is_night := sample.night >= 0.5
	if (is_night and not by_night) or (not is_night and not by_day):
		return false
	return in_rain or sample.rain < 0.1
