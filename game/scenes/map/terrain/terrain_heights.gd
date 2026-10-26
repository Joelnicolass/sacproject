@tool
class_name TerrainHeights
extends Resource

## The shape of a map's ground, the one thing a human edits: a height in metres for every vertex of the 256 x 256 lattice
## (10 m apart, row by row: z * 256 + x) and which of those vertices are void (no land there). The height under a void
## is kept, so filling the void back brings the old ground. One `heights.res` per map; never changed during a match.
## Not: the triangles, the mesh or the collision (all derived from it, see TerrainFaces), the stamps and holes of a
## match (GroundField).

const COUNT := TerrainGrid.SIDE * TerrainGrid.SIDE

## Metres above the map's lowest land, one per lattice vertex (`COUNT` values, row by row).
@export var heights_m := PackedFloat32Array()
## 1 where the vertex is void, 0 where it is land (`COUNT` values, row by row).
@export var void_mask := PackedByteArray()


## True when both arrays cover the whole lattice.
func is_valid() -> bool:
	return heights_m.size() == COUNT and void_mask.size() == COUNT


## The height of lattice vertex `v` (see TerrainGrid.vertex_id), kept even when the vertex is void.
func height(v: int) -> float:
	return heights_m[v]


func is_void(v: int) -> bool:
	return void_mask[v] != 0


## A number that is equal for two resources only when their heights and voids are equal, bit for bit.
func checksum() -> int:
	return hash(heights_m.to_byte_array() + void_mask)
