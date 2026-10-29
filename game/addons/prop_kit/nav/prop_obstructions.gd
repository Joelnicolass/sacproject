@tool
class_name PropObstructions
extends RefCounted

## The cheap way for props to cut a navmesh: each collision shape of a prop becomes a projected
## obstruction (an outline added to the bake's source geometry) instead of geometry the bake parses
## and rasterizes, so thousands of props cost the bake next to nothing. A prop is a node of GROUP
## (put the group in the prop's scene); its direct, enabled CollisionShape3D and CollisionPolygon3D
## children (3D), or CollisionShape2D and CollisionPolygon2D children (2D), are read with their
## global transforms. `merged` joins outlines closer than a gap into fewer ones (fewer navmesh
## polygons, faster paths) and never covers a passage wider than the gap. Keep the props' colliders
## out of the parsed geometry (their collision layer not in the navmesh's collision mask), or the
## bake pays for them twice.

## The group of the nodes whose shapes cut the navmesh.
const GROUP := &"prop_obstruction"


## The nodes of `group` under `root` (and `root` itself), in tree order. A node queued for
## deletion is already gone.
static func nodes_under(root: Node, group: StringName = GROUP) -> Array[Node]:
	var out: Array[Node] = []
	if root == null or not root.is_inside_tree():
		return out
	for node in root.get_tree().get_nodes_in_group(group):
		if node.is_queued_for_deletion():
			continue
		if node == root or root.is_ancestor_of(node):
			out.append(node)
	return out


## The obstructions of `node`'s 3D collision children. Round shapes get `sides` sides.
static func of_3d(node: Node, sides := 6) -> Array[PropObstruction]:
	var out: Array[PropObstruction] = []
	for child in node.get_children():
		var points := PackedVector3Array()
		var at := Transform3D.IDENTITY
		if child is CollisionShape3D:
			var shape := child as CollisionShape3D
			if shape.disabled or shape.shape == null:
				continue
			points = _shape_points_3d(shape.shape, sides)
			at = shape.global_transform
		elif child is CollisionPolygon3D:
			var polygon := child as CollisionPolygon3D
			if polygon.disabled:
				continue
			for point in polygon.polygon:
				points.append(Vector3(point.x, point.y, -polygon.depth * 0.5))
				points.append(Vector3(point.x, point.y, polygon.depth * 0.5))
			at = polygon.global_transform
		if points.is_empty():
			continue
		var flat := PackedVector2Array()
		var low := INF
		var high := -INF
		for point in points:
			var p := at * point
			flat.append(Vector2(p.x, p.z))
			low = minf(low, p.y)
			high = maxf(high, p.y)
		var obstruction := PropObstruction.new()
		obstruction.outline = _hull(flat)
		obstruction.bottom = low
		obstruction.top = high
		if obstruction.outline.size() >= 3:
			out.append(obstruction)
	return out


## The obstructions of `node`'s 2D collision children. Round shapes get `sides` sides; a
## CollisionPolygon2D keeps its own outline, concave or not.
static func of_2d(node: Node, sides := 8) -> Array[PropObstruction]:
	var out: Array[PropObstruction] = []
	for child in node.get_children():
		var outline := PackedVector2Array()
		if child is CollisionShape2D:
			var shape := child as CollisionShape2D
			if shape.disabled or shape.shape == null:
				continue
			var at := shape.global_transform
			var flat := PackedVector2Array()
			for point in _shape_points_2d(shape.shape, sides):
				flat.append(at * point)
			outline = _hull(flat)
		elif child is CollisionPolygon2D:
			var polygon := child as CollisionPolygon2D
			if polygon.disabled or polygon.polygon.size() < 3:
				continue
			outline = polygon.global_transform * polygon.polygon
		if outline.size() >= 3:
			var obstruction := PropObstruction.new()
			obstruction.outline = outline
			out.append(obstruction)
	return out


## The obstructions of every node in `nodes` (3D or 2D), keeping only those whose bounds touch one
## of `within` (empty = all of them): a re-bake of a few zones needs no more.
static func gather(
	nodes: Array[Node], is_3d: bool, sides: int, within: Array[Rect2] = []
) -> Array[PropObstruction]:
	var out: Array[PropObstruction] = []
	for node in nodes:
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		if node.is_queued_for_deletion():
			continue
		var list := of_3d(node, sides) if is_3d else of_2d(node, sides)
		for obstruction in list:
			if within.is_empty() or touches(obstruction.rect(), within):
				out.append(obstruction)
	return out


## `list` with the outlines closer than `gap` joined: each outline grows by gap / 2, the touching
## ones become one, and the result shrinks back by gap / 2 (a morphological closing). Gaps narrower
## than `gap` close; anything wider stays open, so set it near the agent's diameter. A clearing
## closed all around by gaps narrower than `gap` is filled: no agent could walk in or out of it
## (leave an opening wider than the gap where one must). `gap` 0 = `list` as it is.
static func merged(list: Array[PropObstruction], gap: float) -> Array[PropObstruction]:
	if gap <= 0.0 or list.size() < 2:
		return list
	var out: Array[PropObstruction] = []
	for group in _groups(list, gap):
		if group.size() == 1:
			out.append(list[group[0]])
			continue
		var grown: Array[PackedVector2Array] = []
		var low := INF
		var high := -INF
		for index in group:
			low = minf(low, list[index].bottom)
			high = maxf(high, list[index].top)
			for polygon in Geometry2D.offset_polygon(list[index].outline, gap * 0.5):
				if not Geometry2D.is_polygon_clockwise(polygon):
					grown.append(polygon)
		for joined in _union(grown):
			for polygon in Geometry2D.offset_polygon(joined, -gap * 0.5):
				if Geometry2D.is_polygon_clockwise(polygon) or polygon.size() < 3:
					continue
				var obstruction := PropObstruction.new()
				obstruction.outline = polygon
				obstruction.bottom = low
				obstruction.top = high
				out.append(obstruction)
	return out


## Adds `list` to a 3D bake's source geometry. `carve` = cut exactly the outline (no agent radius
## around it).
static func add_3d(
	source: NavigationMeshSourceGeometryData3D, list: Array[PropObstruction], carve := false
) -> void:
	for obstruction in list:
		var outline := PackedVector3Array()
		for point in obstruction.outline:
			outline.append(Vector3(point.x, 0.0, point.y))
		var height := maxf(obstruction.top - obstruction.bottom, 0.01)
		source.add_projected_obstruction(outline, obstruction.bottom, height, carve)


## Adds `list` to a 2D bake's source geometry.
static func add_2d(
	source: NavigationMeshSourceGeometryData2D, list: Array[PropObstruction], carve := false
) -> void:
	for obstruction in list:
		source.add_projected_obstruction(obstruction.outline, carve)


## A number that changes when any outline of `list` changes (to the centimetre), whatever their
## order: a saved bake whose fingerprint differs from the props' is stale.
static func fingerprint(list: Array[PropObstruction]) -> int:
	var total := list.size()
	for obstruction in list:
		var values := PackedInt64Array()
		for point in obstruction.outline:
			values.append(roundi(point.x * 100.0))
			values.append(roundi(point.y * 100.0))
		values.append(roundi(obstruction.bottom * 100.0))
		values.append(roundi(obstruction.top * 100.0))
		total = (total + hash(values)) & 0x7FFFFFFFFFFFFFFF
	return total


## The bounds of `node`'s obstructions on the ground plane (empty when it has no shape). Read it
## before freeing a prop, to re-bake where it stood.
static func area_of(node: Node, is_3d: bool, sides := 6) -> Rect2:
	var list := of_3d(node, sides) if is_3d else of_2d(node, sides)
	if list.is_empty():
		return Rect2()
	var out := list[0].rect()
	for obstruction in list:
		out = out.merge(obstruction.rect())
	return out


static func _shape_points_3d(shape: Shape3D, sides: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		points = _rings(cylinder.radius, -cylinder.height * 0.5, cylinder.height * 0.5, sides)
	elif shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		var half := maxf(capsule.height * 0.5 - capsule.radius, 0.0)
		points = _rings(capsule.radius, -half, half, sides)
		points.append(Vector3(0.0, -capsule.height * 0.5, 0.0))
		points.append(Vector3(0.0, capsule.height * 0.5, 0.0))
	elif shape is SphereShape3D:
		var sphere := shape as SphereShape3D
		points = _rings(sphere.radius, 0.0, 0.0, sides)
		points.append(Vector3(0.0, -sphere.radius, 0.0))
		points.append(Vector3(0.0, sphere.radius, 0.0))
	elif shape is BoxShape3D:
		var half := (shape as BoxShape3D).size * 0.5
		for x: float in [-1.0, 1.0]:
			for y: float in [-1.0, 1.0]:
				for z: float in [-1.0, 1.0]:
					points.append(Vector3(x * half.x, y * half.y, z * half.z))
	elif shape is ConvexPolygonShape3D:
		points = (shape as ConvexPolygonShape3D).points
	return points


static func _shape_points_2d(shape: Shape2D, sides: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	if shape is CircleShape2D:
		var radius := (shape as CircleShape2D).radius
		for side in sides:
			points.append(Vector2.from_angle(TAU * side / sides) * radius)
	elif shape is RectangleShape2D:
		var half := (shape as RectangleShape2D).size * 0.5
		points = PackedVector2Array(
			[-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]
		)
	elif shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var half := maxf(capsule.height * 0.5 - capsule.radius, 0.0)
		for side in sides:
			var rim := Vector2.from_angle(TAU * side / sides) * capsule.radius
			points.append(rim + Vector2(0.0, half if rim.y > 0.0 else -half))
	elif shape is ConvexPolygonShape2D:
		points = (shape as ConvexPolygonShape2D).points
	return points


## Two rings of `sides` points at heights `low` and `high`.
static func _rings(radius: float, low: float, high: float, sides: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for side in sides:
		var angle := TAU * side / sides
		var around := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		out.append(around + Vector3(0.0, low, 0.0))
		if high != low:
			out.append(around + Vector3(0.0, high, 0.0))
	return out


## The convex hull of `points`, without the closing point Geometry2D repeats.
static func _hull(points: PackedVector2Array) -> PackedVector2Array:
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.remove_at(hull.size() - 1)
	return hull


## True when `rect` overlaps one of `within`.
static func touches(rect: Rect2, within: Array[Rect2]) -> bool:
	for area in within:
		if area.intersects(rect, true):
			return true
	return false


## The indexes of `list` in groups whose bounds come within `gap` of each other (a coarse first
## pass: the closing decides what really joins).
static func _groups(list: Array[PropObstruction], gap: float) -> Array[PackedInt32Array]:
	var rects: Array[Rect2] = []
	var largest := gap
	for obstruction in list:
		var rect := obstruction.rect()
		rects.append(rect)
		largest = maxf(largest, maxf(rect.size.x, rect.size.y) + gap)
	var parent := PackedInt32Array()
	parent.resize(list.size())
	for index in list.size():
		parent[index] = index
	var grid: Dictionary[Vector2i, PackedInt32Array] = {}
	for index in rects.size():
		var grown := rects[index].grow(gap)
		var corner := rects[index].position
		var key := Vector2i(floori(corner.x / largest), floori(corner.y / largest))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for other in grid.get(key + Vector2i(dx, dy), PackedInt32Array()):
					if grown.intersects(rects[other], true):
						_join(parent, index, other)
		var cell: PackedInt32Array = grid.get(key, PackedInt32Array())
		cell.append(index)
		grid[key] = cell
	var by_root: Dictionary[int, PackedInt32Array] = {}
	for index in list.size():
		var top := _root(parent, index)
		var members: PackedInt32Array = by_root.get(top, PackedInt32Array())
		members.append(index)
		by_root[top] = members
	var out: Array[PackedInt32Array] = []
	for top in by_root:
		out.append(by_root[top])
	return out


static func _root(parent: PackedInt32Array, index: int) -> int:
	var at := index
	while parent[at] != at:
		parent[at] = parent[parent[at]]
		at = parent[at]
	return at


static func _join(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _root(parent, a)
	var rb := _root(parent, b)
	if ra != rb:
		parent[maxi(ra, rb)] = mini(ra, rb)


## The union of `polygons` (outer outlines only; holes dropped). A polygon that joins one keeps
## looking: it may now reach another that it did not touch before.
static func _union(polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var joined: Array[PackedVector2Array] = []
	for polygon in polygons:
		var current := polygon
		var grew := true
		while grew:
			grew = false
			var current_rect := _bounds(current)
			for index in joined.size():
				if not current_rect.intersects(_bounds(joined[index]), true):
					continue
				var outer: Array[PackedVector2Array] = []
				for result in Geometry2D.merge_polygons(current, joined[index]):
					if not Geometry2D.is_polygon_clockwise(result):
						outer.append(result)
				if outer.size() == 1:
					current = outer[0]
					joined.remove_at(index)
					grew = true
					break
		joined.append(current)
	return joined


static func _bounds(polygon: PackedVector2Array) -> Rect2:
	var out := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		out = out.expand(point)
	return out
