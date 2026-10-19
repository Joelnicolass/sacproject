@tool
class_name TileLayerMap
extends Resource

## Which `GroundSet` slot paints each of the original map's 256 tile ids. It belongs to the map,
## not to a biome: the zones (open ground, paths, edges) are the original's. `tools/import/classify_ground_tiles.py`
## writes the first version from the average color of each tile; edit by hand to correct it.

## 255 = the tile paints nothing (the layer's own rules decide).
const NONE := 255

## One value per tile id (256): the index of a layer in the GroundSet.
@export var slots: PackedByteArray = PackedByteArray()


func slot_of(tile_id: int) -> int:
	if tile_id < 0 or tile_id >= slots.size():
		return NONE
	return slots[tile_id]
