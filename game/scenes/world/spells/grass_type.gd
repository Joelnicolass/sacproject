@tool
class_name GrassType
extends Resource

## One kind of grass: blade shape, colors, where it grows, how tall it gets in each zone, wind and
## light. A new look is a new `.tres` of this type dragged into a `GrassSet`; no code changes.
## Edit it in the inspector with the world open and the preview shows it live. The root of every
## blade takes the exact color of the ground under it, so only the body and tip colors live here.

@export var label: String = ""

@export_group("Blade")
## Width of the blade at its base.
@export_range(0.01, 0.3, 0.005, "suffix:m") var width_m := 0.09
## Width near the tip as a fraction of the base width (the very tip is always a point).
@export_range(0.0, 1.0, 0.01) var tip_width := 0.07
## Far from the camera each blade is this many times wider and taller than a near one. Width and
## density use the SAME parameter of the distance (see `Density`), so the ground coverage never has a
## gap between the near field and the far one: at the far end the blades read as masses, not threads.
@export_range(1.0, 6.0, 0.05) var far_width_scale := 3.0
@export_range(1.0, 3.0, 0.05) var far_height_scale := 1.5
## How much each blade differs in height from its neighbors (fraction of its height).
@export_range(0.0, 0.8, 0.01) var height_variation := 0.3
## Natural lean of the blades (fraction of the height the tip leans over).
@export_range(0.0, 1.0, 0.01) var lean := 0.3
## Turns edge-on blades toward the camera so the field does not thin out at low angles.
@export_range(0.0, 1.0, 0.01) var view_thicken := 0.6

@export_group("Height by zone")
## Height where the ground is a path, a clearing's rim or near the camera.
@export_range(0.05, 2.0, 0.01, "suffix:m") var short_height_m := 0.3
## Height in open meadow. The game camera must still see the units: keep it under a third of
## the smallest one.
@export_range(0.05, 3.0, 0.01, "suffix:m") var tall_height_m := 0.7
## Height multiplier per ground layer slot (x..w = layers 0..3 of the GroundSet): 1 = tall.
@export var height_by_layer := Vector4(1.0, 0.0, 0.5, 0.0)
## Size of the patches of taller and shorter grass in the open meadow.
@export_range(5.0, 300.0, 1.0, "suffix:m") var open_scale_m := 70.0
## How far from a clearing's edge the grass takes to reach its full height.
@export_range(0.0, 60.0, 0.5, "suffix:m") var clear_falloff_m := 10.0
## Inside this distance of the camera the grass lowers to nothing, so it does not hide the view.
@export_range(0.0, 20.0, 0.1, "suffix:m") var near_fade_m := 2.5

@export_group("Density")
## Blades per square meter near the center of the field (the preset scales it: detail) and far from
## it. The far density is the type's and the preset does NOT lower it: it is the floor that keeps the
## ground covered (see `far_coverage()`); what a preset saves is the radius.
@export_range(1.0, 120.0, 0.5, "suffix:/m2") var density_near := 32.0
@export_range(0.5, 60.0, 0.5, "suffix:/m2") var density_far := 12.0
## Density multiplier per ground layer slot: 0 = nothing grows there.
@export var density_by_layer := Vector4(1.0, 0.0, 0.35, 0.3)

@export_group("Color")
@export var color_mid := Color(0.12, 0.42, 0.06)
@export var color_tip := Color(0.42, 0.62, 0.14)
## How much the body takes the color of the ground below (0 = only `color_mid`).
@export_range(0.0, 1.0, 0.01) var ground_mix := 0.3
## Size of a tuft: color and height change from tuft to tuft (medium and high presets).
@export_range(0.3, 8.0, 0.1, "suffix:m") var clump_scale_m := 1.6
@export_range(0.0, 1.0, 0.01) var clump_tint := 0.5
@export_range(0.0, 1.0, 0.01) var clump_height := 0.35

@export_group("Hillsides")
## On a slope the blades take the color of the ground under them (valley green -> hill soil, no
## second layer). 0 = the blades keep their color, 1 = body fully the ground's.
@export_range(0.0, 1.0, 0.01) var slope_color_mix := 0.7
## How much green the tips keep on a slope (0 = tips also take the ground's color).
@export_range(0.0, 1.0, 0.01) var slope_tip_keep := 0.4
## The slope never takes the grass away, it only makes it shorter: the height goes from 1 on flat
## ground to `slope_height_floor` from `slope_full_deg` up (smooth, no noise, no islands).
@export_range(0.0, 45.0, 0.5, "suffix:deg") var slope_start_deg := 10.0
@export_range(1.0, 80.0, 0.5, "suffix:deg") var slope_full_deg := 40.0
@export_range(0.2, 1.0, 0.01) var slope_height_floor := 0.55
## Width of the blades on a steep slope, as a fraction of the flat ones (1 = the slope keeps its coverage).
@export_range(0.2, 1.0, 0.01) var slope_width_scale := 1.0
## Extra lean of the blades on a slope (less rigid).
@export_range(0.0, 2.0, 0.01) var slope_lean_gain := 0.8

@export_group("Distance fade")
## Where the height starts to go down, as a fraction of the preset's effective radius. The blades are
## not thinned out with the distance: all of them get shorter together and take the ground's color
## until the height is 0 at the radius.
@export_range(0.0, 0.95, 0.01) var fade_start := 0.35
## Safety net: a blade that would be thinner than this on the screen (pixels, before the resolution
## scale) is lowered, so sub-pixel blades never read as loose grains.
@export_range(0.0, 4.0, 0.05, "suffix:px") var min_blade_px := 1.0
@export_range(0.5, 8.0, 0.05, "suffix:px") var full_blade_px := 2.0

@export_group("Ground paint")
## How much the ground takes the field's average color where grass grows (far from the camera the
## ground is the grass, so the blades fade into it without an edge).
@export_range(0.0, 1.0, 0.01) var paint_amount := 0.9
## Brightness of that average against the plain mix of body and tip (blades are shaded, so ~0.8).
@export_range(0.3, 1.5, 0.01) var paint_tone := 1.7
## Strength of the pale wind bands on the painted ground (the same waves as the blades).
@export_range(0.0, 1.0, 0.01) var paint_waves := 0.12
## Share of the paint per ground layer slot (x..w = layers 0..3). Soil and path partly painted so the
## valley and its slopes keep one palette instead of a hard green/brown cut.
## Slope (degrees) where the paint starts to fade and where it is gone: the hills turn into soil gradually.
@export_range(0.0, 60.0, 0.5, "suffix:deg") var paint_slope_start_deg := 10.0
@export_range(1.0, 80.0, 0.5, "suffix:deg") var paint_slope_end_deg := 36.0
@export var paint_by_layer := Vector4(1.0, 0.0, 0.75, 0.65)

@export_group("Light")
## 0 = each blade lit by its own normal, 1 = lit like the ground (soft, round).
@export_range(0.0, 1.0, 0.01) var normal_roundness := 0.7
## Sheen of the blades: 0 = matte. Combined with the round normal it shines as a mass in low sun.
@export_range(0.0, 1.0, 0.01) var specular := 0.5
## 1 = broad dull sheen, low = sharp shine (plastic).
@export_range(0.05, 1.0, 0.01) var roughness := 0.55
## Light that goes through the blade toward the camera, in the color of the tip.
@export_range(0.0, 1.0, 0.01) var translucency := 0.5
## Darkness at the root (false occlusion).
@export_range(0.0, 1.0, 0.01) var root_ao := 0.45
## Height (m) from which the root darkness is full: shorter blades (the fade, slopes) are darkened less.
@export_range(0.05, 3.0, 0.05, "suffix:m") var root_ao_full_m := 0.5

@export_group("Wind")
@export_range(0.0, 360.0, 1.0, "suffix:deg") var wind_direction_deg := 35.0
## Lean of the tips with the wind, as a fraction of the blade height.
@export_range(0.0, 1.0, 0.01) var wind_strength := 0.22
@export_range(0.0, 8.0, 0.05, "suffix:m/s") var wind_speed := 2.2
## Size of the waves that cross the field.
@export_range(5.0, 200.0, 1.0, "suffix:m") var wind_scale_m := 55.0
## How much the gusts lighten the tips (the pale waves of BotW).
@export_range(0.0, 1.0, 0.01) var gust_lighten := 0.45

@export_group("Trample")
## Radius of the flattened area as a multiple of the body's radius.
@export_range(0.5, 4.0, 0.05) var trample_radius_scale := 1.5
## Seconds the grass takes to stand up after a unit moves on.
@export_range(0.2, 8.0, 0.1, "suffix:s") var trample_recover_s := 2.0


## Share of the blade's top view that counts as ground cover (a blade is a thin, tapered, bent shape).
const COVER_SHAPE := 0.55
## Where in its range of heights the far blades are measured (0 = the short ones, 1 = the tall ones).
const FAR_REFERENCE_OPENNESS := 0.3
## Under this the far field leaves bare ground between blades (1 - e^-C of the ground is covered).
const MIN_FAR_COVERAGE := 2.3


## Ground coverage of the far field: far density x far width x reference height x the blade shape.
## It does not depend on the preset. `GrassField` warns if it drops under `MIN_FAR_COVERAGE`.
func far_coverage() -> float:
	var height := lerpf(short_height_m, maxf(tall_height_m, short_height_m), FAR_REFERENCE_OPENNESS)
	return density_far * width_m * far_width_scale * height * COVER_SHAPE


## The color the painted ground takes: what the field looks like from far away.
func average_color() -> Color:
	var mixed := color_mid.lerp(color_tip, 0.42)
	return Color(mixed.r * paint_tone, mixed.g * paint_tone, mixed.b * paint_tone)
