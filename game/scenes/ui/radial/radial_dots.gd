class_name RadialDots
extends RefCounted

## Drawing helpers of the radial center: a formation as dots and the two-line wrap of a name. Pure functions.


## `formation`'s slots for eight bodies as dots on `canvas`: forward is up, the group fitted in a `box` square around `center`.
static func draw(canvas: CanvasItem, formation: FormationType, center: Vector2, box: float, radius: float, color: Color, outline: Color) -> void:
	var slots := formation.slots(8, 1.0, 0.0, 0)
	if slots.is_empty():
		return
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for slot in slots:
		var flat := Vector2(slot.x, -slot.y)
		low = low.min(flat)
		high = high.max(flat)
	var span := high - low
	var fit_scale := box / maxf(maxf(span.x, span.y), 0.001)
	var mid := (low + high) * 0.5
	for slot in slots:
		var at := center + (Vector2(slot.x, -slot.y) - mid) * fit_scale
		canvas.draw_circle(at, radius + 1.1, outline)
		canvas.draw_circle(at, radius, color)


## The name in one line, or two when it is long and has a space.
static func wrap(text: String) -> PackedStringArray:
	if text.length() <= 9 or not text.contains(" "):
		return PackedStringArray([text])
	var cut := text.find(" ")
	return PackedStringArray([text.substr(0, cut), text.substr(cut + 1)])
