extends Node

## Measures where an effect really landed on screen (RFC-055 055x, criterion 7). A flow fires the effect at a socket of a body in
## debug/fx/fx_sockets_lab.tscn, waits a frame or two, and asks this node about the socket's world point:
##   - `centroid_px`: how far (in pixels) the centroid of the bright pixels around the socket's projection is from that projection; <= 16;
##   - `hue_diff_deg`: how far the mean hue of those bright pixels is from the color of the effect's light; <= 20;
##   - `ground_shift`: how much a ground point changed color between two samples (the ground under the wizard must not tint).
## Read-only: it only reads the viewport. The result is a Dictionary and also one `FX_SOCKET ...` line, so a flow can assert on either.
## Flows read it by `prop` of /root/AgentKit/fx_sockets_capture or call `measure`.

const BRIGHT_LUMINANCE := 0.8
const WINDOW_PX := 96
const MAX_CENTROID_PX := 16.0
const MAX_HUE_DIFF_DEG := 20.0
const MIN_PIXELS := 12
const MAX_GROUND_SHIFT := 0.04

## The last result of `measure`, for a flow that reads a property.
var last: Dictionary = {}


## The screen point of a world point under the current camera.
func project(at: Vector3) -> Vector2:
	var camera := get_viewport().get_camera_3d()
	return camera.unproject_position(at) if camera != null else Vector2(-1.0, -1.0)


## Looks at the bright pixels in a window around the projection of `at` (the socket asked for) and compares them with it and with `light`.
func measure(label: String, at: Vector3, light: Color) -> Dictionary:
	var image := get_viewport().get_texture().get_image()
	var center := project(at)
	var sum := Vector2.ZERO
	var hue_cos := 0.0
	var hue_sin := 0.0
	var count := 0
	var x_from := maxi(0, int(center.x) - WINDOW_PX)
	var x_to := mini(image.get_width(), int(center.x) + WINDOW_PX)
	var y_from := maxi(0, int(center.y) - WINDOW_PX)
	var y_to := mini(image.get_height(), int(center.y) + WINDOW_PX)
	for y in range(y_from, y_to):
		for x in range(x_from, x_to):
			var pixel := image.get_pixel(x, y)
			if pixel.get_luminance() < BRIGHT_LUMINANCE or pixel.s < 0.05:
				continue
			sum += Vector2(x, y)
			hue_cos += cos(pixel.h * TAU)
			hue_sin += sin(pixel.h * TAU)
			count += 1
	var centroid_px := INF
	var hue_diff_deg := INF
	if count >= MIN_PIXELS:
		centroid_px = (sum / float(count)).distance_to(center)
		var mean_hue := fposmod(atan2(hue_sin, hue_cos) / TAU, 1.0)
		var gap := absf(mean_hue - light.h)
		hue_diff_deg = minf(gap, 1.0 - gap) * 360.0
	var passed := centroid_px <= MAX_CENTROID_PX and hue_diff_deg <= MAX_HUE_DIFF_DEG
	last = {"label": label, "ok": passed, "pixels": count, "centroid_px": centroid_px, "hue_diff_deg": hue_diff_deg}
	print("FX_SOCKET %s ok=%s pixels=%d centroid_px=%.1f hue_diff_deg=%.1f" % [label, passed, count, centroid_px, hue_diff_deg])
	return last


## The color of the viewport at the projection of a ground point (a few pixels averaged), to compare before and after an effect.
func sample(at: Vector3) -> Color:
	var image := get_viewport().get_texture().get_image()
	var center := project(at)
	var total := Color(0.0, 0.0, 0.0, 0.0)
	var count := 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var x := clampi(int(center.x) + dx, 0, image.get_width() - 1)
			var y := clampi(int(center.y) + dy, 0, image.get_height() - 1)
			total += image.get_pixel(x, y)
			count += 1
	return total / float(count)


## How far two samples of the ground are (largest channel difference); <= 0.04 means the effect did not tint it.
func ground_shift(before: Color, after: Color) -> float:
	return maxf(absf(before.r - after.r), maxf(absf(before.g - after.g), absf(before.b - after.b)))


## True when `ground_shift` is within what a human does not see.
func ground_clean(before: Color, after: Color) -> bool:
	return ground_shift(before, after) <= MAX_GROUND_SHIFT
