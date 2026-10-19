@tool
class_name FloraMap
extends Resource

## RFC-054 054a (F380): how many original plants of each species stand in every 8 m cell of a map. Baked from the map's
## widgets.json by tools/bake/bake_flora_map.gd into scenes/map/maps/<tag>/flora.res (binary, compressed); only the
## bake writes it. The positions inside a cell are not kept: FloraPlacement scatters `count_at` plants in it.
## Presentation data: the simulation never reads it.

## Side of a cell, in meters.
@export var texel_m := 8.0
## Cells per side (texel_m x resolution covers the 2560 m map).
@export var resolution := 320
## Species tags (widget tags of the original: CAH1, PYA2...), sorted.
@export var tags := PackedStringArray()
## One grid per tag, row-major (index tz * resolution + tx), each value a count capped at MAX_COUNT.
@export var counts: Array[PackedByteArray] = []

const MAX_COUNT := 255


func cell_count() -> int:
	return resolution * resolution


## Plants of tag number `tag_index` in the cell (tx, tz); 0 outside the grid.
func count_at(tag_index: int, tx: int, tz: int) -> int:
	if tag_index < 0 or tag_index >= counts.size() or tx < 0 or tz < 0 or tx >= resolution or tz >= resolution:
		return 0
	return counts[tag_index][tz * resolution + tx]


## Index of a tag in `tags`, or -1.
func tag_index(tag: String) -> int:
	return tags.find(tag)


## The cell that holds the map point (x, z) (not clamped).
func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / texel_m), floori(z / texel_m))


## Plants of one tag over the whole map.
func tag_total(tag_index: int) -> int:
	if tag_index < 0 or tag_index >= counts.size():
		return 0
	var sum := 0
	for value in counts[tag_index]:
		sum += value
	return sum


## Plants of every tag over the whole map.
func total() -> int:
	var sum := 0
	for i in counts.size():
		sum += tag_total(i)
	return sum

