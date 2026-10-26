class_name GroundCollision
extends StaticBody3D

## The ground to stand on in a mesh map: every triangle of its MeshGroundData (land, cliff walls, roofs) cut in the data's
## chunks, one collision shape each, all on this one body. It is built once when the map loads, chunk by chunk in the order
## the data lists them, so every peer gets the same body; a ray from above (GroundRay) finds the same ground
## GroundSurface.height_at answers. It does not move with the ground yet (063-2b) and draws nothing.

## An empty shape every chunk copies, so no shape is built in code.
const CHUNK_SHAPE := preload("res://scenes/map/terrain/terrain_chunk.tres")

@export var surface: GroundSurface


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if surface != null else PackedStringArray(["Falta el socket `surface` (el GroundSurface del mapa)."])


func _ready() -> void:
	if not Engine.is_editor_hint() and surface != null and surface.mesh_data != null:
		build(surface.mesh_data)


## One shape per chunk of `data`, in its order. Called by _ready; a probe that has no map scene may call it on its own body.
func build(data: MeshGroundData) -> void:
	var vertices := data.vertices
	var indices := data.indices
	for row: int in range(data.chunk_count()):
		var first := data.chunks[row * 4 + 2] * 3
		var faces := PackedVector3Array()
		faces.resize(data.chunks[row * 4 + 3] * 3)
		for corner: int in range(faces.size()):
			faces[corner] = vertices[indices[first + corner]]
		var made := CHUNK_SHAPE.duplicate() as ConcavePolygonShape3D
		made.set_faces(faces)
		shape_owner_add_shape(create_shape_owner(self), made)


## How many chunk shapes the body holds.
func chunk_count() -> int:
	return get_shape_owners().size()
