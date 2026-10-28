class_name NavZones
extends RefCounted

## The map's navmesh as a fixed grid of zone pieces (from (0, 0), `zone_m` squares over the map's footprint). `baked` returns a new
## NavZones that shares the pieces it did not touch and bakes the others; `stitched` joins every piece into the one navmesh the
## game uses. The pieces meet exactly on the zone lines, so a re-bake of the touched zones gives the navmesh of baking them all.
## Not: when to bake or what changed (NavRebake, NavChanges), the swap (NavMeshBackend). Pieces are never changed once made.
## Ref: Godot demo navigation_mesh_chunks (filter_baking_aabb + border_size + rounded vertices).

var _settings: NavBakeSettings
## Zones per side.
var _side: int
## One NavigationMesh per zone, row by row (null while not baked).
var _pieces: Array = []


func _init(settings: NavBakeSettings) -> void:
	_settings = settings
	_side = ceili(TerrainGrid.SIZE_M / settings.zone_m)
	_pieces.resize(_side * _side)


func zone_count() -> int:
	return _side * _side


## The zones (indexes, ascending) whose bake box (the zone grown by `zone_border_m`) overlaps `rect` (x, z in metres), cut to the grid.
func zones_touching(rect: Rect2) -> PackedInt32Array:
	var out := PackedInt32Array()
	var grown := rect.grow(_settings.zone_border_m)
	var low := _cell_of(grown.position)
	var high := _cell_of(grown.end)
	for z in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			if _zone_rect(z * _side + x).grow(_settings.zone_border_m).intersects(rect):
				out.append(z * _side + x)
	return out


## Cuts `navmesh` (the joined one, e.g. the saved nav.res) into pieces: each polygon goes to the zone of its centroid.
func split(navmesh: NavigationMesh) -> void:
	var source := navmesh.get_vertices()
	var polygons := []
	polygons.resize(zone_count())
	for p in navmesh.get_polygon_count():
		var polygon := navmesh.get_polygon(p)
		var sum := Vector2.ZERO
		for index in polygon:
			sum += Vector2(source[index].x, source[index].z)
		var cell := _cell_of(sum / polygon.size())
		var zone := cell.y * _side + cell.x
		if polygons[zone] == null:
			polygons[zone] = []
		polygons[zone].append(polygon)
	for zone in zone_count():
		_pieces[zone] = null
		if polygons[zone] == null:
			continue
		var piece := NavigationMesh.new()
		var local := PackedVector3Array()
		var remap := {}
		for polygon: PackedInt32Array in polygons[zone]:
			var mapped := PackedInt32Array()
			for index in polygon:
				if not remap.has(index):
					remap[index] = local.size()
					local.append(source[index])
				mapped.append(remap[index])
			piece.add_polygon(mapped)
		piece.set_vertices(local)
		_pieces[zone] = piece


## A NavZones with these pieces, the ones in `zones` baked again from `geometry` (several at once on the worker pool). Safe to call
## from a worker thread; `geometry` is only read.
func baked(geometry: NavigationMeshSourceGeometryData3D, zones: PackedInt32Array) -> NavZones:
	var out := NavZones.new(_settings)
	out._pieces = _pieces.duplicate()
	var fresh := []
	fresh.resize(zones.size())
	if zones.size() > 1:
		var group := WorkerThreadPool.add_group_task(
			_bake_slot.bind(geometry, zones, fresh), zones.size(), -1, true, "NavZones"
		)
		WorkerThreadPool.wait_for_group_task_completion(group)
	else:
		for slot in zones.size():
			_bake_slot(slot, geometry, zones, fresh)
	for slot in zones.size():
		out._pieces[zones[slot]] = fresh[slot]
	return out


func bake_all(geometry: NavigationMeshSourceGeometryData3D) -> NavZones:
	var all := PackedInt32Array()
	for zone in zone_count():
		all.append(zone)
	return baked(geometry, all)


## The pieces joined into one navmesh: vertices rounded to a tenth of a cell and shared by position, pieces in zone order, so the same
## pieces always give the same navmesh (same hash). The caller stamps the metadata it needs.
func stitched() -> NavigationMesh:
	var out := NavigationMesh.new()
	_settings.apply_to(out)
	var step := _settings.cell_size * 0.1
	var vertices := PackedVector3Array()
	var by_key := {}
	var polygons: Array[PackedInt32Array] = []
	for piece: NavigationMesh in _pieces:
		if piece == null:
			continue
		var source := piece.get_vertices()
		var mapped := PackedInt32Array()
		mapped.resize(source.size())
		for i in source.size():
			var key := Vector3i((source[i] / step).round())
			if not by_key.has(key):
				by_key[key] = vertices.size()
				vertices.append(Vector3(key) * step)
			mapped[i] = by_key[key]
		for p in piece.get_polygon_count():
			var polygon := PackedInt32Array()
			for index in piece.get_polygon(p):
				if polygon.is_empty() or polygon[polygon.size() - 1] != mapped[index]:
					polygon.append(mapped[index])
			if polygon.size() > 1 and polygon[0] == polygon[polygon.size() - 1]:
				polygon.remove_at(polygon.size() - 1)
			if polygon.size() >= 3:
				polygons.append(polygon)
	out.set_vertices(vertices)
	for polygon in polygons:
		out.add_polygon(polygon)
	return out


func _bake_slot(
	slot: int, geometry: NavigationMeshSourceGeometryData3D, zones: PackedInt32Array, fresh: Array
) -> void:
	var navmesh := NavigationMesh.new()
	_settings.apply_to(navmesh)
	_settings.apply_zone(navmesh, _zone_rect(zones[slot]))
	NavigationServer3D.bake_from_source_geometry_data(navmesh, geometry)
	fresh[slot] = navmesh if navmesh.get_polygon_count() > 0 else null


func _zone_rect(zone: int) -> Rect2:
	return Rect2(
		Vector2(zone % _side, zone / _side) * _settings.zone_m, Vector2.ONE * _settings.zone_m
	)


## The zone column and row of the point (x, z), cut to the grid.
func _cell_of(point: Vector2) -> Vector2i:
	var cell := Vector2i((point / _settings.zone_m).floor())
	return cell.clamp(Vector2i.ZERO, Vector2i(_side - 1, _side - 1))
