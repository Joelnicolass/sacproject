@tool
class_name RtsRadialLayout
extends Resource

## What a radial menu holds and how big it is: a dead zone in the middle (releasing there cancels) and
## any number of rings around it, from the inside out. Entry 0 of a ring is at the top and the rest
## follow clockwise, each owning an equal sector centered on its icon. The pointer picks by angle and
## distance only: this class is pure math. Canvas pixels (Godot's stretch scales them).

@export var rings: Array[RtsRadialRing] = []
## The catalogs rings fill from (RtsRadialRing.fill).
@export var commands: RtsCommandCatalog
@export var formations: RtsFormationCatalog
## The picture in the dead zone; by context (what a right click would order where the menu opened:
## `ground`, `enemy`, `own`…) when `context_icons` has one.
@export var center_icon: Texture2D
@export var context_icons: Dictionary[StringName, Texture2D] = {}
@export var dead_zone_px := 41.0
@export var icon_px := 46.0

var _cache: Array = []
var _cache_key := ""


## The entries of every ring, inside out: Array of Array[RtsMenuEntry].
func ring_entries() -> Array:
	var key := signature()
	if key == _cache_key:
		return _cache
	var result: Array = []
	for ring in rings:
		var list: Array[RtsMenuEntry] = []
		if ring:
			list.append_array(ring.entries)
			if ring.fill == RtsRadialRing.Fill.COMMANDS:
				list.append_array(RtsMenuEntry.from_catalogs(commands, null, ring.commands))
			elif ring.fill == RtsRadialRing.Fill.FORMATIONS:
				list.append_array(RtsMenuEntry.from_catalogs(null, formations))
		result.append(list)
	_cache = result
	_cache_key = key
	return result


## The inner edge of ring `index` (0 = the first ring around the dead zone).
func ring_inner(index: int) -> float:
	var radius := dead_zone_px
	for i in mini(index, rings.size()):
		radius += rings[i].width_px if rings[i] else 0.0
	return radius


func ring_outer(index: int) -> float:
	return ring_inner(index) + (rings[index].width_px if index < rings.size() and rings[index] else 0.0)


## Radius at which the icons of ring `index` are centered.
func ring_mid(index: int) -> float:
	return 0.5 * (ring_inner(index) + ring_outer(index))


## The outer edge of the last ring.
func outer_radius() -> float:
	return ring_inner(rings.size())


## Where `offset` (canvas pixels from the menu center) falls: x = 0 in the dead zone, k + 1 in ring k,
## -1 outside; y = the index of the entry in that ring (-1 when there is none, 0 in the dead zone).
func locate(offset: Vector2) -> Vector2i:
	var distance := offset.length()
	if distance < dead_zone_px:
		return Vector2i(0, 0)
	var entries := ring_entries()
	for k in rings.size():
		if distance <= ring_outer(k):
			return Vector2i(k + 1, sector_index((entries[k] as Array).size(), offset))
	return Vector2i(-1, -1)


## The entry under `offset`, or null (the dead zone, outside, an empty ring).
func entry_at(offset: Vector2) -> RtsMenuEntry:
	return entry_of(locate(offset))


## The entry a `locate` result stands for (null for none).
func entry_of(spot: Vector2i) -> RtsMenuEntry:
	if spot.x < 1 or spot.y < 0:
		return null
	var entries: Array = ring_entries()[spot.x - 1]
	return entries[spot.y] if spot.y < entries.size() else null


## Index of the sector `offset` falls in, for a ring of `count` entries (entry 0 at the top,
## clockwise); -1 when empty.
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


## A string that changes whenever the entries would (the menu rebuilds its icons only then).
func signature() -> String:
	var parts := PackedStringArray()
	for ring in rings:
		parts.append(
			"%d:%d:%d" % [ring.get_instance_id() if ring else 0, ring.entries.size() if ring else 0, ring.fill if ring else 0]
		)
	parts.append(str(commands.get_instance_id() if commands else 0))
	parts.append(str(formations.get_instance_id() if formations else 0))
	parts.append(str(commands.commands.size() if commands else 0))
	parts.append(str(formations.formations.size() if formations else 0))
	return ",".join(parts)
