class_name ArcFormation
extends FormationType

## Semicircle and circle (state.d:455-466): the bodies stand on an arc of `arc_deg` degrees, behind the order point.

## 180 = semicircle, 360 = full circle.
@export_range(30.0, 360.0, 1.0) var arc_deg := 180.0


func slots(count: int, spacing: float, target_distance: float, _command: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var arc := deg_to_rad(arc_deg)
	var full := arc_deg >= 360.0
	var radius: float
	if full:
		radius = maxf(target_distance, count * spacing / arc)
	else:
		radius = maxf(maxf(target_distance, 0.5 * spacing), (count - 1) * spacing / arc)
	for i in count:
		var angle: float
		if full:
			angle = arc * i / count
		else:
			angle = 0.5 * PI if count == 1 else arc * i / (count - 1)
		result.append(radius * Vector2(-cos(angle), -sin(angle)))
	return result
