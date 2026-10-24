class_name BeamType
extends Resource

## How a bolt between two points looks (RFC-029 029d): a ribbon of `segments` with the shape of
## sacengine's LightningBolt, drawn by `scene` (BeamFx). A template shared by every beam of the type,
## never edited at runtime. Another beam (the storm's far strikes, 029l) = another .tres.
## Numbers of sacengine: state.d:2815-2850 (shape and timing), sacobject.d:2281-2295 (ltn2 atlas, 4×4
## cells, 10 segments, fins of 0.3), renderer.d:264-272 (additive, energy 15) and renderer.d:1877-1905
## (pose, travel and brightness pulse).

## Drawing of the beam. Empty = no bolt: only the flash (`light`) at the end.
@export var scene: PackedScene
## Atlas tag of res://assets/original/fx/ (tools/import/import_ui.py). sacengine `ltn2`; `elec` also fits.
@export var atlas_tag := "ltn2"
@export_range(1, 8) var h_frames := 4
@export_range(1, 8) var v_frames := 4
## Seconds each atlas cell stays (sacengine 2 ticks: getFrame(i / updateAnimFactor)).
@export_range(0.005, 0.5, 0.001, "suffix:s") var frame_s := 2.0 / 60.0

@export_group("Shape")
enum Path { BOLT, ARC }
## BOLT: the jagged bolt of sacengine's Lightning. ARC: a vertical half circle from end to end, with no jitter (Rainbow).
@export var path := Path.BOLT
## ARC: the height of the middle of the arc as a share of the distance between the ends (0.5 = a half circle).
@export_range(0.0, 2.0, 0.05) var arc_height := 0.5
## Bolts drawn at once between the same ends, each with its own shape (sacengine `bolts[2]`).
@export_range(1, 4) var bolts := 2
## Straight pieces of a bolt (sacengine numLightningSegments 10: 11 points).
@export_range(2, 32) var segments := 10
## Distance from the axis to each of the 3 fins, meters (sacengine makeLineMeshes size 0.3).
@export_range(0.01, 2.0, 0.01, "suffix:m") var width_m := 0.3
## Side of the box each inner point is pushed within, meters (sacengine changeShape size 2.5).
@export_range(0.0, 10.0, 0.05, "suffix:m") var jitter_m := 2.5
## Seconds between two shapes (sacengine changeShapeDelay 6 ticks).
@export_range(0.01, 1.0, 0.001, "suffix:s") var change_s := 6.0 / 60.0

@export_group("Timing")
## Seconds the beam lasts (sacengine Lightning.totalFrames 64 ticks ≈ 1.07 s).
@export_range(0.05, 5.0, 0.001, "suffix:s") var life_s := 64.0 / 60.0
## Seconds the tip takes to reach the end, and the tail to leave the start at the close
## (sacengine travelDelay 12 ticks). The flash goes off when the tip arrives.
@export_range(0.0, 2.0, 0.001, "suffix:s") var travel_s := 12.0 / 60.0

@export_group("Look")
enum Blend { ADD, MIX }
## ADD: the atlas adds light (sacengine; the spell bolts). MIX: the atlas is a straight-alpha overlay (*_a.png of
## tools/import/import_ui.py) drawn over the scene, for a glow that has to keep its hue over the snow (the Gnome's
## flame, F124); its alpha times the brightness (clamped to 1) is the coverage.
@export var blend := Blend.ADD
## Brightness pulse 0.375 + 14.625 · (0.5 + 0.25 cos 7a + 0.25 sin 11a), a = π · t / life
## (renderer.d:1881-1882): between `energy_min` and `energy_max`.
@export var energy_min := 0.375
@export var energy_max := 15.0
## Multiplies the whole brightness. 1 = sacengine's numbers.
@export_range(0.0, 4.0, 0.01) var energy_scale := 1.0
## Meters over which the ribbon fades in front of the scene depth (with the preset's `fx_soft_particles`).
@export_range(0.0, 4.0, 0.05, "suffix:m") var soft_distance_m := 0.3

@export_group("Tip sparks")
## Sprites that stay behind the tip while it travels (Rainbow's glow). Optional: empty = none. A ParticleType under data/fx/.
@export var tip_type: ParticleType
@export_range(1.0, 240.0, 1.0, "suffix:/s") var tip_per_s := 60.0
## Radius of the ball around the tip they are born in.
@export_range(0.0, 3.0, 0.05, "suffix:m") var tip_spread_m := 0.7

@export_group("Flash and pool")
## Light at the end when the tip arrives, from the rig's FxLightLayer. Empty = no flash.
@export var light: FxLightSpec
## Beams of this type FxBus keeps; when all are playing, the oldest one starts over.
@export_range(1, 64) var pool_max := 6


## Brightness at `t` seconds of the beam's life.
func energy_at(t: float) -> float:
	var a := PI * t / maxf(life_s, 0.001)
	var wave := 0.5 + 0.25 * cos(7.0 * a) + 0.25 * sin(11.0 * a)
	return lerpf(energy_min, energy_max, wave) * energy_scale


## Drawn part of the bolt at `t`, as fractions of its length: the tip travels in over `travel_s`
## and the tail leaves over the last `travel_s` (renderer.d:1898-1903).
func span_at(t: float) -> Vector2:
	if travel_s <= 0.0:
		return Vector2(0.0, 1.0)
	if t < travel_s:
		return Vector2(0.0, t / travel_s)
	if t > life_s - travel_s:
		return Vector2(clampf((t - (life_s - travel_s)) / travel_s, 0.0, 1.0), 1.0)
	return Vector2(0.0, 1.0)


## The name FxBus plays this type by: its file under data/fx/beams/ without the extension.
func fx_name() -> String:
	return resource_path.trim_prefix("res://data/fx/beams/").get_basename()
