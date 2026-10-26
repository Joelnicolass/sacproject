class_name TerrainCollision
extends StaticBody3D

## The ground to stand on: the map's triangles (land and cliff walls, Terrain.data) in chunks of `chunk_cells` x `chunk_cells`
## cells, one shape each on this one body. A chunk keeps its triangles as loaded and the lattice vertex under each corner:
## remaking it adds how far those vertices moved (no triangle with a taken away corner), and is skipped when none moved.
## Under playing stamps (Terrain.changed) a share of the touched chunks is remade each tick, each within `refresh_s`; when
## the ground settles (Terrain.settled) all at once. So GroundRay finds what Terrain.height_at answers. It moves no ground.

## An empty shape every chunk copies, so no shape is built in code.
const CHUNK_SHAPE := preload("res://scenes/map/terrain/terrain_chunk.tres")

@export var terrain: Terrain
@export_range(1, 32) var chunk_cells := 8
## How long a chunk under a playing stamp may wait to be remade (what settles is remade at once).
@export_range(0.0166, 0.5, 0.0001, "suffix:s") var refresh_s := 0.1


## One chunk: its triangles as loaded, the lattice vertex under each corner, the vertices it uses and their last shift.
class Chunk:
	var base := PackedVector3Array()
	var lattice := PackedInt32Array()
	var vertices := Rect2i()
	var shown := PackedFloat32Array()
	var shape: ConcavePolygonShape3D


var _chunks := {}  ## Vector2i -> Chunk, only chunks with triangles
var _dirty := {}  ## Vector2i -> true, in the order they were marked (the oldest is remade first)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if terrain != null else PackedStringArray(["Falta el socket `terrain` (el Terrain del mapa)."])


func _ready() -> void:
	set_physics_process(false)
	if Engine.is_editor_hint() or terrain == null or not terrain.data.is_valid():
		return
	_split_in_chunks(terrain.data)
	for key: Vector2i in _chunks:
		_remake(_chunks[key])
	terrain.changed.connect(_on_terrain_changed)
	terrain.settled.connect(flush.unbind(1))
	set_physics_process(true)


## How many chunks hold triangles, and how many wait to be remade.
func chunk_count() -> int:
	return _chunks.size()


func pending_count() -> int:
	return _dirty.size()


## Remakes the chunks that moved now, without waiting.
func flush() -> void:
	for key: Vector2i in _dirty:
		_remake(_chunks[key])
	_dirty.clear()


## Files each triangle of `data` (corners in index order, so a wall keeps its face) under the chunk of its lowest cell.
func _split_in_chunks(data: MapTerrainData) -> void:
	var vertices := data.vertices
	var indices := data.indices
	var lattice := data.lattice
	for first in range(0, indices.size(), 3):
		var a := indices[first]
		var b := indices[first + 1]
		var c := indices[first + 2]
		var column := mini(lattice[a] % TerrainGrid.SIDE, mini(lattice[b] % TerrainGrid.SIDE, lattice[c] % TerrainGrid.SIDE))
		var row := mini(lattice[a] / TerrainGrid.SIDE, mini(lattice[b] / TerrainGrid.SIDE, lattice[c] / TerrainGrid.SIDE))
		var key := Vector2i(column / chunk_cells, row / chunk_cells)
		var chunk: Chunk = _chunks.get(key)
		if chunk == null:
			chunk = Chunk.new()
			chunk.vertices = Rect2i(key * chunk_cells, Vector2i.ONE * (chunk_cells + 1)).intersection(Rect2i(0, 0, TerrainGrid.SIDE, TerrainGrid.SIDE))
			chunk.shape = CHUNK_SHAPE.duplicate() as ConcavePolygonShape3D
			shape_owner_add_shape(create_shape_owner(self), chunk.shape)
			_chunks[key] = chunk
		chunk.base.append(vertices[a])
		chunk.base.append(vertices[b])
		chunk.base.append(vertices[c])
		chunk.lattice.append(lattice[a])
		chunk.lattice.append(lattice[b])
		chunk.lattice.append(lattice[c])


## Makes the chunk's shape where the ground is now, unless none of its vertices moved since the last time.
func _remake(chunk: Chunk) -> void:
	var texels := terrain.field().texels
	var shown := PackedFloat32Array()
	for row in chunk.vertices.size.y:
		var first := TerrainGrid.id_of(chunk.vertices.position + Vector2i(0, row)) * 2
		shown.append_array(texels.slice(first, first + chunk.vertices.size.x * 2))
	if shown == chunk.shown:
		return
	chunk.shown = shown
	var still := PackedFloat32Array()
	still.resize(shown.size())
	chunk.shape.set_faces(chunk.base if shown == still else _faces_of(chunk, texels, _has_hole(shown)))


## The chunk's triangles with each corner raised by its vertex's shift; with `holed`, none that has a taken away corner.
static func _faces_of(chunk: Chunk, texels: PackedFloat32Array, holed: bool) -> PackedVector3Array:
	var lattice := chunk.lattice
	var faces := chunk.base.duplicate()
	if not holed:
		for i in faces.size():
			var corner := faces[i]
			corner.y += texels[lattice[i] * 2]
			faces[i] = corner
		return faces
	faces.clear()
	for first in range(0, lattice.size(), 3):
		if texels[lattice[first] * 2 + 1] > 0.5 or texels[lattice[first + 1] * 2 + 1] > 0.5 or texels[lattice[first + 2] * 2 + 1] > 0.5:
			continue
		for i in range(first, first + 3):
			faces.append(chunk.base[i] + Vector3(0.0, texels[lattice[i] * 2], 0.0))
	return faces


## True when a vertex of `shown` (two floats each: shift, taken away) was taken away.
static func _has_hole(shown: PackedFloat32Array) -> bool:
	for i in range(1, shown.size(), 2):
		if shown[i] > 0.5:
			return true
	return false


func _on_terrain_changed(area: Rect2) -> void:
	# A moved vertex is a corner of the cells around it: the chunks of those cells.
	var low := Vector2i((area.position / TerrainGrid.CELL_M).floor()) - Vector2i.ONE
	var high := Vector2i(((area.position + area.size) / TerrainGrid.CELL_M).ceil())
	for z in range(maxi(low.y, 0) / chunk_cells, high.y / chunk_cells + 1):
		for x in range(maxi(low.x, 0) / chunk_cells, high.x / chunk_cells + 1):
			if _chunks.has(Vector2i(x, z)):
				_dirty[Vector2i(x, z)] = true


## A share of the waiting chunks, the oldest first, so each waits at most `refresh_s` and no tick remakes them all.
func _physics_process(_delta: float) -> void:
	if _dirty.is_empty():
		return
	var share := ceili(float(_dirty.size()) / maxi(1, MatchClock.ticks_for(refresh_s)))
	for key: Vector2i in _dirty.keys().slice(0, share):
		_remake(_chunks[key])
		_dirty.erase(key)
