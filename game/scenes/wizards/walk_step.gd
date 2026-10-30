class_name WalkStep
extends Resource

## How far a walk clip moves the body: `plane_distance` over `frame_count` frames, played at
## `ticks_per_second`.

@export var plane_distance: float = 0.0
@export var frame_count: int = 0
@export var ticks_per_second: float = 0.0


func plane_step() -> float:
	if frame_count <= 0:
		return 0.0
	return plane_distance / float(frame_count)


func speed() -> float:
	return plane_step() * ticks_per_second
