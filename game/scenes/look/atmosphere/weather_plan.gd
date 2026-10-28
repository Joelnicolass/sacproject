@tool
class_name WeatherPlan
extends Resource

## How the weather goes over a match: the match is cut into segments of `segment_s`, the first is
## `first` and each next one draws a state from `chances` with the sky's seed (AtmosphereRules), so
## every peer gets the same; at the start of a segment the previous weather blends into the new one
## over `blend_s`. The five gods share one plan (`data/look/weather/plan.tres`): the same states
## with the same weights.

## The weather the match starts with (Clear keeps the approved look).
@export var first: WeatherState
@export var chances: Array[WeatherChance] = []
## Seconds of one weather.
@export_range(5.0, 3600.0, 1.0, "suffix:s") var segment_s: float = 240.0
## Seconds the change from one weather to the next takes (at the start of a segment).
@export_range(0.0, 600.0, 0.5, "suffix:s") var blend_s: float = 30.0
## Debug walks: play `chances` in their order (segment k = chances[k mod n]) instead of drawing.
@export var in_order: bool = false
