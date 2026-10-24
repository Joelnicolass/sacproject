class_name TerrainCollision
extends StaticBody3D

## The ground to stand on: the map's triangles (land and cliff walls) cut in chunks of `chunk_cells` x `chunk_cells` cells,
## one collision shape each, all on this one body. When the ground moves (TerrainShape.changed) only the chunks it touched
## are made again, at most every `refresh_ticks` ticks, with the corners moved as the shape says; a triangle with a taken
## away corner is left out. So a ray from above (GroundRay) finds the same ground TerrainShape.height_at answers, a
## few ticks late. It does not decide how the ground moves (TerrainDeformer) and draws nothing.

## An empty shape every chunk copies, so no shape is built in code.
const CHUNK_SHAPE := preload("res://scenes/map/terrain/terrain_chunk.tres")

@export var shape: TerrainShape
@export_range(1, 32) var chunk_cells := 8
## Ticks between two remakes of the chunks that moved.
@export_range(1, 30) var refresh_ticks := 3

var _vertices := PackedVector3Array()
var _indices := PackedInt32Array()
## The lattice vertex under each entry of `_vertices`.
var _lattice := PackedInt32Array()
## Chunk -> Array of the first index (into `_indices`) of each of its triangles.
var _triangles := {}
## Chunk -> {owner, shape}. Only chunks with triangles.
var _chunks := {}
var _dirty := {}
var _tick := 0


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if shape != null else PackedStringArray(["Falta el socket `shape` (el TerrainShape del mapa)."])


func _ready() -> void:
	set_physics_process(false)
	if Engine.is_editor_hint() or shape == null or shape.data == null or not shape.data.is_valid():
		return
	_vertices = shape.data.vertices
	_indices = shape.data.indices
	_split_in_chunks()
	for chunk: Vector2i in _triangles:
		_remake(chunk)
	shape.changed.connect(_on_shape_changed)
	set_physics_process(true)


## How many chunks hold triangles, and how many wait to be remade.
func chunk_count() -> int:
	return _chunks.size()


func pending_count() -> int:
	return _dirty.size()


## Remakes the chunks that moved now, without waiting for the next refresh.
func flush() -> void:
	for chunk: Vector2i in _dirty:
		_remake(chunk)
	_dirty.clear()


func _split_in_chunks() -> void:
	_lattice.resize(_vertices.size())
	for i in _vertices.size():
		_lattice[i] = TerrainRules.vertex_id(_vertices[i].x, _vertices[i].z)
	for first in range(0, _indices.size(), 3):
		var a := _vertices[_indices[first]]
		var b := _vertices[_indices[first + 1]]
		var c := _vertices[_indices[first + 2]]
		var cell := Vector2i(floori(minf(a.x, minf(b.x, c.x)) / TerrainRules.CELL), floori(minf(a.z, minf(b.z, c.z)) / TerrainRules.CELL))
		var chunk := cell / chunk_cells
		if not _triangles.has(chunk):
			_triangles[chunk] = []
		(_triangles[chunk] as Array).append(first)


## The triangles of `chunk` with their corners where the ground is now.
func _faces_of(chunk: Vector2i) -> PackedVector3Array:
	var texels := shape.displacement().texels
	var faces := PackedVector3Array()
	for first: int in _triangles[chunk]:
		var ids := [_indices[first], _indices[first + 1], _indices[first + 2]]
		if texels[_lattice[ids[0]] * 2 + 1] > 0.5 or texels[_lattice[ids[1]] * 2 + 1] > 0.5 or texels[_lattice[ids[2]] * 2 + 1] > 0.5:
			continue
		for id: int in ids:
			faces.append(_vertices[id] + Vector3(0.0, texels[_lattice[id] * 2], 0.0))
	return faces


func _remake(chunk: Vector2i) -> void:
	var faces := _faces_of(chunk)
	if not _chunks.has(chunk):
		var made := CHUNK_SHAPE.duplicate() as ConcavePolygonShape3D
		var owner_id := create_shape_owner(self)
		shape_owner_add_shape(owner_id, made)
		_chunks[chunk] = {"owner": owner_id, "shape": made}
	(_chunks[chunk]["shape"] as ConcavePolygonShape3D).set_faces(faces)


func _on_shape_changed(area: Rect2) -> void:
	# A moved vertex is a corner of the four cells around it.
	var low := Vector2i((area.position / TerrainRules.CELL).floor()) - Vector2i.ONE
	var high := Vector2i(((area.position + area.size) / TerrainRules.CELL).ceil())
	for z in range(maxi(low.y, 0) / chunk_cells, high.y / chunk_cells + 1):
		for x in range(maxi(low.x, 0) / chunk_cells, high.x / chunk_cells + 1):
			if _triangles.has(Vector2i(x, z)):
				_dirty[Vector2i(x, z)] = true


func _physics_process(_delta: float) -> void:
	_tick += 1
	if _tick % refresh_ticks == 0 and not _dirty.is_empty():
		flush()
