class_name MapTerrainData
extends Resource

## The raw ground of a map as the original stores it (RFC-033): vertices and flat normals in Godot axes, and the
## triangle indices (ground first, cliff walls mixed in; Terrain tells them apart). One .res per map in
## assets/original/maps/<map>/terrain.res, written by tools/import_terrain.gd. Never mutated at runtime: Terrain
## derives the mesh, the smooth normals and the cell grid from it on load.

@export var vertices := PackedVector3Array()
@export var normals := PackedVector3Array()
@export var indices := PackedInt32Array()


func is_valid() -> bool:
	return not vertices.is_empty() and not indices.is_empty() and normals.size() == vertices.size()
