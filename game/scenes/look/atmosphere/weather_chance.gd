@tool
class_name WeatherChance
extends Resource

## One weather of a plan and how likely it is against the others (embedded in the WeatherPlan).

@export var state: WeatherState
## Relative weight: 2 is twice as likely as 1. 0 = never (kept in the list).
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
