extends RefCounted

## RFC-054 054b (F381): the camera poses of the CellRing golden (debug/look/cell_ring_golden.txt). The golden was recorded
## with GrassField's own ring code before it moved to CellRing; cell_ring_cases.gd replays the same poses through
## CellRing and must print the same lines. Flat ground at GROUND_Y (the grass reads its baked height map; the ring only
## gets the number).

const GROUND_Y := 12.0
## GrassField's numbers: 16 m cells, 160 per side, the TIER_BLEND list and the smoothstep of FAR_START_FACTOR.
const CELL_M := 16.0
const MAP_CELLS := 160
const KEEP_MARGIN_M := 6.0
const TIER_HYSTERESIS_M := 4.0
const TIER_BLEND := [0.0, 0.07, 0.18, 0.32, 0.48, 0.64, 0.8, 0.92]
const FAR_START_FACTOR := 2.2
const FOLLOW_RATE := 6.0
## (near radius, ring radius): the default preset (45 m x 0.85) and a wide one.
const SEQUENCES := [Vector2(15.0, 38.25), Vector2(40.0, 102.0)]


## Same arithmetic as GrassField._build_meshes: where every tier starts for a near radius.
static func tier_starts(near_r: float) -> PackedFloat32Array:
	var starts := PackedFloat32Array()
	for blend: float in TIER_BLEND:
		var x := 0.5 - sin(asin(1.0 - 2.0 * clampf(blend, 0.0, 1.0)) / 3.0)
		starts.append(0.0 if blend == 0.0 else near_r + (FAR_START_FACTOR - 1.0) * near_r * x)
	starts.append(near_r * FAR_START_FACTOR)
	return starts


## [{position: Vector3, forward: Vector3 (normalized), delta: float}], in map-local meters.
static func poses() -> Array:
	var out := []
	# A game camera a few meters up, walking +x and turning.
	var at := Vector3(1280.0, 18.0, 1280.0)
	for i in 40:
		var yaw := deg_to_rad(4.0 * i)
		out.append({"position": at, "forward": Vector3(sin(yaw), -0.35, -cos(yaw)).normalized(), "delta": 0.0 if i == 0 else 0.1})
		at += Vector3(2.5, 0.0, 0.0)
	# An RTS camera high up, sliding diagonally.
	for i in 12:
		out.append({"position": Vector3(1380.0 + 6.0 * i, 70.0, 1300.0 - 4.0 * i), "forward": Vector3(0.3, -0.9, -0.3).normalized(), "delta": 0.1})
	# A jump to the corner of the map and out of it (the grid clamps).
	for i in 10:
		out.append({"position": Vector3(40.0 - 9.0 * i, 15.0, 40.0 - 7.0 * i), "forward": Vector3(-1.0, -0.2, -1.0).normalized(), "delta": 0.1})
	# Straight down at the far corner (no flat direction).
	for i in 5:
		out.append({"position": Vector3(2540.0, 50.0 + 10.0 * i, 2540.0), "forward": Vector3(0.0, -1.0, 0.0), "delta": 0.1})
	# Level forward (the reach is not cut by the view ray) and then under the ground (nothing above it).
	for i in 5:
		out.append({"position": Vector3(900.0 + 12.0 * i, 5.0 + 4.0 * i, 700.0), "forward": Vector3(1.0, 0.0, 0.1).normalized(), "delta": 0.25})
	for i in 4:
		out.append({"position": Vector3(960.0, 2.0, 700.0 + 20.0 * i), "forward": Vector3(0.0, -0.5, 1.0).normalized(), "delta": 0.5})
	return out


## One golden line: step, the two centers and every cell with its tier, sorted.
static func line(sequence: int, step: int, field_center: Vector2, fade_center: Vector2, tiers: Dictionary) -> String:
	var keys := tiers.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var cells := PackedStringArray()
	for key: Vector2i in keys:
		cells.append("%d,%d:%d" % [key.x, key.y, tiers[key]])
	return "%d/%d field=%.6f,%.6f fade=%.6f,%.6f n=%d %s" % [
		sequence, step, field_center.x, field_center.y, fade_center.x, fade_center.y, keys.size(), " ".join(cells)]
