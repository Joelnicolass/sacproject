@tool
class_name RadialLayout
extends Resource

## What a radial menu holds and how big it is. All sizes are canvas pixels of the 1280×720 base (Godot's stretch
## scales them). Two rings around a dead zone: `inner` between `dead_zone_px` and `inner_radius_px`, `outer` between
## `inner_radius_px` and `outer_radius_px`. Entry 0 of a ring is at the top and the rest follow clockwise, each one owning
## an equal sector centered on its icon. The pointer picks by angle and distance only; this class is pure math.
## Ref: RFC-038 038c.

## What the dead zone stands for: releasing there cancels (the menu shows the hovered name in it).
@export var center: RadialEntry
## Center icon by what was under the pointer when the menu opened (`ground`, `enemy`, `own`, `corpse`); `center.icon` otherwise.
@export var center_icons: Dictionary = {}
@export var inner: Array[RadialEntry] = []
@export var outer: Array[RadialEntry] = []
@export_group("Size (canvas pixels)")
@export var dead_zone_px := 41.0
@export var inner_radius_px := 106.0
@export var outer_radius_px := 168.0
@export var icon_px := 46.0
@export_group("Opening")
## Seconds the right button (or Tab) is held before the menu opens (15 frames at 60 Hz in the original).
## Ref: sacengine xmenuTime.
@export var hold_s := 0.25


## Where `offset` (canvas pixels from the menu center) falls: x = ring (0 the dead zone, 1 inner, 2 outer, -1 outside), y = the
## index of the entry in that ring (0 for the dead zone, -1 when there is none).
func locate(offset: Vector2) -> Vector2i:
	var distance := offset.length()
	if distance < dead_zone_px:
		return Vector2i(0, 0)
	if distance <= inner_radius_px:
		return Vector2i(1, sector_index(inner.size(), offset))
	if distance <= outer_radius_px:
		return Vector2i(2, sector_index(outer.size(), offset))
	return Vector2i(-1, -1)


## The entry under `offset`: the center in the dead zone, a ring entry, or null outside the outer ring or on an empty ring
## (releasing there aborts).
func entry_at(offset: Vector2) -> RadialEntry:
	return entry_of(locate(offset))


## The entry a `locate` result stands for (null for none).
func entry_of(spot: Vector2i) -> RadialEntry:
	match spot.x:
		0:
			return center
		1:
			return inner[spot.y] if spot.y >= 0 else null
		2:
			return outer[spot.y] if spot.y >= 0 else null
	return null


## Radius at which the icons of the inner / outer ring are centered.
func inner_mid() -> float:
	return 0.5 * (dead_zone_px + inner_radius_px)


func outer_mid() -> float:
	return 0.5 * (inner_radius_px + outer_radius_px)


## Index of the sector `offset` falls in, for a ring of `count` entries (entry 0 at the top, clockwise); -1 when empty.
static func sector_index(count: int, offset: Vector2) -> int:
	if count <= 0:
		return -1
	var step := TAU / count
	var angle := fposmod(atan2(offset.x, -offset.y), TAU)
	return int(floor((angle + 0.5 * step) / step)) % count


## Center of entry `index` of a ring of `count` entries at `radius`, from the menu center.
static func slot_offset(count: int, index: int, radius: float) -> Vector2:
	var angle := TAU * index / maxf(count, 1)
	return Vector2(sin(angle), -cos(angle)) * radius
