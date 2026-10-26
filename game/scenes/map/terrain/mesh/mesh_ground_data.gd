@tool
class_name MeshGroundData
extends Resource

## The free ground of a map as numbers: its triangles in world metres (the map lives at x, z >= 0), cut in chunks, and the
## cache that finds the walkable triangle under a point. Written by the import of the map's ground.glb (tools/ground_import.gd)
## next to it as ground.res, and never changed at runtime: GroundSurface answers from it, GroundCollision and the drawn chunks
## are cut from it. What it does NOT do: any arithmetic (MeshGroundRules) or know how the ground moves (GroundField).

## Every triangle of the ground, cliff walls and roofs included, corners in world metres.
@export var vertices := PackedVector3Array()
## Three vertex ids per triangle, sorted by chunk (a chunk's triangles are one run, see `chunks`).
@export var indices := PackedInt32Array()
## The map's footprint on the ground (x, z in metres).
@export var bounds := Rect2()
@export_range(1.0, 1000.0, 0.1, "suffix:m") var chunk_m := 100.0
## Side of a cache bucket: the walkable triangles are filed under every bucket their footprint touches.
@export_range(1.0, 200.0, 0.1, "suffix:m") var bucket_m := 10.0
## Distance between two nodes of the displacement field (063-2b); written here so the map decides it once.
@export_range(1.0, 100.0, 0.1, "suffix:m") var deform_cell_m := 10.0
## A triangle whose normal leans more than this from straight up is a wall: it collides but gives no height.
@export_range(1.0, 89.0, 0.1, "suffix:degrees") var walkable_deg := 50.0
## Four numbers per chunk: chunk x, chunk z (in `chunk_m` steps), first triangle, triangle count.
@export var chunks := PackedInt32Array()
## Buckets along x and z. `bucket_start` has one more entry than buckets; the walkable triangles of bucket b are
## `bucket_tris[bucket_start[b]:bucket_start[b + 1]]` (triangle ids, row-major b = z * dims.x + x from `bounds.position`).
@export var bucket_dims := Vector2i.ZERO
@export var bucket_start := PackedInt32Array()
@export var bucket_tris := PackedInt32Array()
## The lowest vertex of a walkable triangle (0 without land).
@export var lowest_m := 0.0


func triangle_count() -> int:
	return indices.size() / 3


func chunk_count() -> int:
	return chunks.size() / 4


## True when the arrays agree with each other and there is some land to ask about.
func is_valid() -> bool:
	return not vertices.is_empty() and indices.size() % 3 == 0 and not bucket_tris.is_empty() \
			and bucket_dims.x > 0 and bucket_dims.y > 0 and bucket_start.size() == bucket_dims.x * bucket_dims.y + 1
