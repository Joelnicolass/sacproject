class_name MapTerrainData
extends RefCounted

## The triangles of a map's ground, derived in memory from its TerrainHeights by TerrainFaces and never saved: three
## unshared vertices per triangle with their flat normal (Godot axes), the indices, the lattice vertex under each vertex,
## and how many triangles are land (all the land comes first, the cliff walls after). The mesh, the collision and the
## per-cell index are made from it. Not: the source (TerrainHeights), anything that moves in a match (GroundField).

var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var indices := PackedInt32Array()
## The lattice vertex (TerrainGrid.vertex_id) each entry of `vertices` stands on; a wall's foot has the id of its top.
var lattice := PackedInt32Array()
## Triangles before the first wall: triangle t is land when t < land_triangles.
var land_triangles := 0


func is_valid() -> bool:
	return not vertices.is_empty() and not indices.is_empty() and normals.size() == vertices.size() \
			and lattice.size() == vertices.size()


## Appends one triangle with its flat normal. Godot's front face is the opposite of the right-hand normal: land keeps
## its corner order, so it faces up; a wall is flipped, so its face is the one seen from the void.
func add(a: Vector3, b: Vector3, c: Vector3, id_a: int, id_b: int, id_c: int, wall: bool) -> void:
	var start := vertices.size()
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	lattice.append(id_a)
	lattice.append(id_b)
	lattice.append(id_c)
	var right := (b - a).cross(c - a)
	var normal := right if wall else -right
	normal = Vector3.UP if normal == Vector3.ZERO else normal.normalized()
	normals.append(normal)
	normals.append(normal)
	normals.append(normal)
	indices.append(start)
	indices.append(start + 2 if wall else start + 1)
	indices.append(start + 1 if wall else start + 2)
