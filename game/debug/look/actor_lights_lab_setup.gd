class_name ActorLightsLabSetup
extends Resource

## RFC-055 055b-3: one shortcut of debug/look/actor_lights_lab.tscn: the preset and how many lights to throw at the budget.

@export var quality: LookQuality
## ActorLights spread over the square (units, wizards and spells in the mix of a big battle).
@export_range(1, 1000) var light_count := 200
## Side of the square the lights are spread on.
@export_range(10.0, 500.0, 1.0, "suffix:m") var side_m := 120.0
## Meters the camera circles at, over the ground.
@export_range(5.0, 200.0, 1.0, "suffix:m") var camera_height_m := 30.0
