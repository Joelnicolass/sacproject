@tool
class_name TimeOfDay
extends Node

## The day's part of the atmosphere: the hour at a match second and that hour's light, from the biome's DayCycle.
## It knows nothing of the weather and writes no light: Atmosphere asks it and mixes.

## The day's sample of `cycle` (the look's `day`; null = no cycle, neutral) at match second `t_s`; `frozen_hour` >= 0
## pins the hour.
func sample_at(cycle: DayCycle, t_s: float, frozen_hour: float) -> AtmosphereSample:
	if cycle == null:
		return AtmosphereSample.neutral()
	var hour := frozen_hour if frozen_hour >= 0.0 else AtmosphereRules.hour_at(cycle, t_s)
	return AtmosphereRules.day_sample(cycle, hour)
