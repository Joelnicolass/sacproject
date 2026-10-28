class_name GroundSumRules
extends RefCounted

## How the ground's visible shift is added up from what stays and the stamps that play, over a rect of lattice vertices:
## the plain loops GroundField runs on its arrays (`texels` two floats per vertex, `permanent` one). Pure and static.
## Not: which stamps play or what stays (GroundField), what a stamp's shift is (StampRules).


## Writes over `rect` what stays plus every stamp of `stamps` ([rect, values] each, values row by row), in their order.
static func sum(
	texels: PackedFloat32Array, permanent: PackedFloat32Array, stamps: Array, rect: Rect2i
) -> void:
	for row in rect.size.y:
		var first := TerrainGrid.id_of(rect.position + Vector2i(0, row))
		for id in range(first, first + rect.size.x):
			texels[id * 2] = permanent[id]
	for stamp: Array in stamps:
		var area: Rect2i = stamp[0]
		var values: PackedFloat32Array = stamp[1]
		var cut := rect.intersection(area)
		for row in cut.size.y:
			var first := TerrainGrid.id_of(cut.position + Vector2i(0, row))
			var at := (
				(cut.position.y + row - area.position.y) * area.size.x
				+ cut.position.x
				- area.position.x
				- first
			)
			for id in range(first, first + cut.size.x):
				texels[id * 2] += values[at + id]


## One stamp's new shift `values` over the same `rect` as its old one `before`: with no other stamp over the rect (`alone`)
## it writes what stays plus `values` exactly; otherwise it adds the difference.
static func replace(
	texels: PackedFloat32Array,
	permanent: PackedFloat32Array,
	rect: Rect2i,
	values: PackedFloat32Array,
	before: PackedFloat32Array,
	alone: bool
) -> void:
	for row in rect.size.y:
		var first := TerrainGrid.id_of(rect.position + Vector2i(0, row))
		var at := row * rect.size.x - first
		if alone:
			for id in range(first, first + rect.size.x):
				texels[id * 2] = permanent[id] + values[at + id]
		else:
			for id in range(first, first + rect.size.x):
				texels[id * 2] += values[at + id] - before[at + id]


## Adds `delta` (row by row over `rect`) to `permanent`.
static func add(permanent: PackedFloat32Array, rect: Rect2i, delta: PackedFloat32Array) -> void:
	for row in rect.size.y:
		var first := TerrainGrid.id_of(rect.position + Vector2i(0, row))
		var at := row * rect.size.x - first
		for id in range(first, first + rect.size.x):
			permanent[id] += delta[at + id]
