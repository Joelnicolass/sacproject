class_name NavGrid
extends RefCounted

## The walking grid of RFC-024 (024b): 512x512 nodes 5 m apart, as sacengine PathFinder (state.d:675-880,
## directWalkDistance = 5). Node (i, j) stands at world (5i, 5j). A node is free when the land under it is
## whole and, with `erode_edges`, so is the land around it (sacengine isFree, state.d:684-702, asks the cells
## around the node). Altars and manafounts are discs that block the nodes under them plus `margin_m`
## (blockingTolerance 1.5, state.d:790). Components are 4-connected, the same moves the A* makes.
## Paths come from AStarGrid2D (octile, no corner cutting) and are pulled straight again over the grid.
## The grid only answers questions; moving is the body's job (CharacterBody3D / move_and_slide).
## F88 round 2: a 5 m node is free when its center clears a box blocker by `margin_m`, but line_clear takes the
## whole 5 m square around it as walkable, and a tipi's box can reach 1 m into such a square. The boxes are kept, and
## a line that crosses one (grown by `box_clearance_m`) is not clear (see crosses_box). Without it, a creature at the
## foot of a tipi was sent straight through the box and pressed on its face for good (debug/crowd_tipi.tscn).

const SIZE := 512
const CELL_M := 5.0
const TERRAIN_CELLS := 256
## How far (in nodes) a start or a goal looks for a free node when its own is blocked.
const SNAP_RADIUS := 6

var open := PackedByteArray()
var astar := AStarGrid2D.new()
var built := false
var free_count := 0
var component_count := 0
## Wall-clock cost of the last build, for the report (never read by the simulation).
var build_ms := 0.0

## Free nodes of the bare ground (no blockers), kept between builds. `land_builds` counts how many times it was worked out.
var _land := PackedByteArray()
var _land_eroded := true
var land_builds := 0

## The box blockers of the last build (RFC-035 035g: the maths is NavBoxBlockers, shared with the navmesh backend).
var box_blockers := NavBoxBlockers.new()

var _comp_of_run := PackedInt32Array()
var _run_row_start := PackedInt32Array()
var _run_x0 := PackedInt32Array()
var _run_x1 := PackedInt32Array()


## `terrain` answers ground_cell_counts(); `discs` are blockers: [Vector2 center (x, z), float radius] or, for a box,
## [Vector2 center, Vector2 half extents (x, z), float yaw].
## `box_clearance_m`: how far from a box a straight line must stay to be clear (about a body's half width).
func build(terrain: Node, discs: Array, margin_m := 1.5, erode_edges := true, box_clearance_m := 0.5) -> void:
	var started := Time.get_ticks_usec()
	## The land does not change while the match goes on: the free nodes of the ground are worked out once (40 ms) and every
	## later build (a Manalith went up, a house fell) only blocks the discs again and finds the components (RFC-024 024d: the
	## hitch of ~50 ms per structure that the review of 024c measured).
	if _land.is_empty() or _land_eroded != erode_edges:
		_land = _land_nodes(terrain.call("ground_cell_counts"), erode_edges)
		_land_eroded = erode_edges
		land_builds += 1
	open = _land.duplicate()
	box_blockers.reset(box_clearance_m)
	for disc in discs:
		if disc.size() >= 3:
			_block_box(disc[0], disc[1], float(disc[2]), margin_m)
			box_blockers.add(disc[0], disc[1], float(disc[2]))
		else:
			_block_disc(disc[0], float(disc[1]) + margin_m)
	_find_components()
	_build_astar()
	built = true
	build_ms = float(Time.get_ticks_usec() - started) / 1000.0


func is_free_node(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < SIZE and j < SIZE and open[j * SIZE + i] != 0


static func node_of(point: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi(point.x / CELL_M), 0, SIZE - 1), clampi(roundi(point.z / CELL_M), 0, SIZE - 1))


static func node_point(node: Vector2i) -> Vector3:
	return Vector3(float(node.x) * CELL_M, 0.0, float(node.y) * CELL_M)


func is_free_at(point: Vector3) -> bool:
	var node := node_of(point)
	return open[node.y * SIZE + node.x] != 0


## Component id of the node under `point` (the nearest free node when its own is blocked), -1 if none.
func component_at(point: Vector3) -> int:
	var node := nearest_free(node_of(point))
	if node.x < 0:
		return -1
	return _component_of(node)


func same_region(a: Vector3, b: Vector3) -> bool:
	var ca := component_at(a)
	return ca >= 0 and ca == component_at(b)


## sacengine closestUnblocked (state.d:757): the free node closest to `node` within SNAP_RADIUS, or (-1, -1).
## `component` >= 0 asks for a node of that component only.
func nearest_free(node: Vector2i, component := -1) -> Vector2i:
	if open[node.y * SIZE + node.x] != 0 and (component < 0 or _component_of(node) == component):
		return node
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for dj in range(-SNAP_RADIUS, SNAP_RADIUS + 1):
		var j := node.y + dj
		if j < 0 or j >= SIZE:
			continue
		for di in range(-SNAP_RADIUS, SNAP_RADIUS + 1):
			var i := node.x + di
			if i < 0 or i >= SIZE or open[j * SIZE + i] == 0:
				continue
			var d := di * di + dj * dj
			if d >= best_d:
				continue
			if component >= 0 and _component_of(Vector2i(i, j)) != component:
				continue
			best_d = d
			best = Vector2i(i, j)
	return best


## True when the straight line from `a` to `b` (x, z of world points) crosses only free nodes, each
## taken as the 5 m square around it, and no box blocker (crosses_box). Conservative: a line that grazes a blocked
## square is not clear.
func line_clear(a: Vector3, b: Vector3) -> bool:
	return _grid_line_clear(a, b) and not crosses_box(a, b)


## True when the segment from `a` to `b` (flat) passes through a box blocker of the last build grown by
## `box_clearance_m` on every side (NavBoxBlockers).
func crosses_box(a: Vector3, b: Vector3) -> bool:
	return box_blockers.crosses_box(a, b)


func _grid_line_clear(a: Vector3, b: Vector3) -> bool:
	var ax := a.x / CELL_M + 0.5
	var az := a.z / CELL_M + 0.5
	var bx := b.x / CELL_M + 0.5
	var bz := b.z / CELL_M + 0.5
	var ix := floori(ax)
	var iz := floori(az)
	var end_x := floori(bx)
	var end_z := floori(bz)
	if not _free_xy(ix, iz):
		return false
	var dx := bx - ax
	var dz := bz - az
	var step_x := 1 if dx > 0.0 else -1
	var step_z := 1 if dz > 0.0 else -1
	var t_max_x := INF if dx == 0.0 else ((float(ix + 1) - ax) / dx if dx > 0.0 else (float(ix) - ax) / dx)
	var t_max_z := INF if dz == 0.0 else ((float(iz + 1) - az) / dz if dz > 0.0 else (float(iz) - az) / dz)
	var t_delta_x := INF if dx == 0.0 else absf(1.0 / dx)
	var t_delta_z := INF if dz == 0.0 else absf(1.0 / dz)
	var guard := absi(end_x - ix) + absi(end_z - iz) + 2
	while (ix != end_x or iz != end_z) and guard > 0:
		guard -= 1
		if t_max_x < t_max_z:
			ix += step_x
			t_max_x += t_delta_x
		elif t_max_z < t_max_x:
			iz += step_z
			t_max_z += t_delta_z
		else:
			# Exactly through a corner: both squares beside the corner must be free too.
			if not _free_xy(ix + step_x, iz) or not _free_xy(ix, iz + step_z):
				return false
			ix += step_x
			iz += step_z
			t_max_x += t_delta_x
			t_max_z += t_delta_z
		if not _free_xy(ix, iz):
			return false
	return true


## Waypoints (world points, y from `heights` when given) from `from` (not included) to `to`, going around
## what blocks the way. [to] when the line is clear, [] when there is no grid. A goal on a blocked node
## ends on the nearest free node of the walker's component; a goal in another region ends at the
## closest free node of this one (sacengine walks to the closest approach, state.d:915-918).
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not built:
		return PackedVector3Array()
	if line_clear(from, to):
		return PackedVector3Array([to])
	var start := nearest_free(node_of(from))
	if start.x < 0:
		return PackedVector3Array([to])
	var wanted := _component_of(start)
	var goal_node := node_of(to)
	var goal := nearest_free(goal_node, wanted)
	if goal.x < 0:
		goal = _closest_of_component(goal_node, wanted)
	if goal.x < 0 or goal == start:
		return PackedVector3Array([to])
	var ids := astar.get_id_path(start, goal, true)
	if ids.size() < 2:
		return PackedVector3Array([to])
	var nodes := _straighten(ids)
	var out := PackedVector3Array()
	for k in range(1, nodes.size()):
		out.append(node_point(nodes[k]))
	# The real goal replaces the last node when its own node was free (no snap happened).
	if goal == goal_node:
		out[out.size() - 1] = to
	# The walker is not on the start node: when the line from where it stands to the first waypoint goes through a
	# box blocker, the start node comes first (F88 round 2: else the first leg runs into the tipi it stands by).
	if crosses_box(from, out[0]):
		out.insert(0, node_point(start))
	return out


## Length of a path from `from` through `points`, flat.
static func path_length(from: Vector3, points: PackedVector3Array) -> float:
	var total := 0.0
	var last := Vector2(from.x, from.z)
	for point in points:
		var here := Vector2(point.x, point.z)
		total += last.distance_to(here)
		last = here
	return total


func _free_xy(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < SIZE and j < SIZE and open[j * SIZE + i] != 0


## Greedy string pulling over the node path: from each anchor, jump to the farthest node still in a
## clear line. Keeps the A* detour and drops its staircase.
func _straighten(ids: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = [ids[0]]
	var anchor := 0
	while anchor < ids.size() - 1:
		var far := anchor + 1
		var probe := ids.size() - 1
		while probe > far:
			if line_clear(node_point(ids[anchor]), node_point(ids[probe])):
				far = probe
				break
			probe -= 1
		out.append(ids[far])
		anchor = far
	return out


## The free node of component `wanted` closest to `node`, looking out in square rings (<= 24 nodes).
func _closest_of_component(node: Vector2i, wanted: int) -> Vector2i:
	for ring in range(SNAP_RADIUS + 1, 25):
		var best := Vector2i(-1, -1)
		var best_d := 1 << 30
		for dj in range(-ring, ring + 1):
			var j := node.y + dj
			if j < 0 or j >= SIZE:
				continue
			var edge := absi(dj) == ring
			var di := -ring
			while di <= ring:
				var i := node.x + di
				if i >= 0 and i < SIZE and open[j * SIZE + i] != 0 and _component_of(Vector2i(i, j)) == wanted:
					var d := di * di + dj * dj
					if d < best_d:
						best_d = d
						best = Vector2i(i, j)
				di += 1 if edge else 2 * ring
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## Free nodes from the land cells. A node touches the cells that hold it (one inside a cell, two on an
## edge, four on a corner); with erosion it also needs every cell that holds a neighbor node. Counts of
## non-whole cells go through a prefix sum so each node is one rectangle query.
func _land_nodes(counts: PackedByteArray, erode_edges: bool) -> PackedByteArray:
	var n := TERRAIN_CELLS
	var stride := n + 1
	var bad := PackedInt32Array()
	bad.resize(stride * stride)
	for cz in n:
		var row := 0
		for cx in n:
			row += 1 if counts[cz * n + cx] < 2 else 0
			bad[(cz + 1) * stride + cx + 1] = bad[cz * stride + cx + 1] + row
	var out := PackedByteArray()
	out.resize(SIZE * SIZE)
	var grow := 1 if erode_edges else 0
	for j in SIZE:
		var cz := j >> 1
		var odd_z := (j & 1) == 1
		var z0 := cz - (grow if odd_z else 1)
		var z1 := cz + (grow if odd_z else 0)
		for i in SIZE:
			var cx := i >> 1
			var odd_x := (i & 1) == 1
			var x0 := cx - (grow if odd_x else 1)
			var x1 := cx + (grow if odd_x else 0)
			if x0 < 0 or z0 < 0 or x1 >= n or z1 >= n:
				continue
			var holes := bad[(z1 + 1) * stride + x1 + 1] - bad[z0 * stride + x1 + 1] - bad[(z1 + 1) * stride + x0] + bad[z0 * stride + x0]
			if holes == 0:
				out[j * SIZE + i] = 1
	return out


## Blocks the nodes whose center lies within `radius` of (x, z).
func _block_disc(center: Vector2, radius: float) -> void:
	var lo_x := maxi(0, floori((center.x - radius) / CELL_M))
	var hi_x := mini(SIZE - 1, ceili((center.x + radius) / CELL_M))
	var lo_z := maxi(0, floori((center.y - radius) / CELL_M))
	var hi_z := mini(SIZE - 1, ceili((center.y + radius) / CELL_M))
	var r2 := radius * radius
	for j in range(lo_z, hi_z + 1):
		for i in range(lo_x, hi_x + 1):
			var dx := float(i) * CELL_M - center.x
			var dz := float(j) * CELL_M - center.y
			if dx * dx + dz * dz <= r2:
				open[j * SIZE + i] = 0


## Blocks the nodes whose center lies within `margin` of the box (half extents `half`, turned `yaw` about Y).
func _block_box(center: Vector2, half: Vector2, yaw: float, margin: float) -> void:
	var reach := half.length() + margin
	var lo_x := maxi(0, floori((center.x - reach) / CELL_M))
	var hi_x := mini(SIZE - 1, ceili((center.x + reach) / CELL_M))
	var lo_z := maxi(0, floori((center.y - reach) / CELL_M))
	var hi_z := mini(SIZE - 1, ceili((center.y + reach) / CELL_M))
	var cos_y := cos(yaw)
	var sin_y := sin(yaw)
	for j in range(lo_z, hi_z + 1):
		for i in range(lo_x, hi_x + 1):
			var dx := float(i) * CELL_M - center.x
			var dz := float(j) * CELL_M - center.y
			## Into the box frame: Godot's yaw about +Y takes local +X to (cos, -sin) on (x, z).
			var local_x := dx * cos_y - dz * sin_y
			var local_z := dx * sin_y + dz * cos_y
			if absf(local_x) <= half.x + margin and absf(local_z) <= half.y + margin:
				open[j * SIZE + i] = 0


## Runs of free nodes per row, joined with the runs that touch them in the row above (4-connectivity),
## by union-find over run ids. A node's component is found by looking its row's runs up.
func _find_components() -> void:
	_run_row_start = PackedInt32Array()
	_run_row_start.resize(SIZE + 1)
	_run_x0 = PackedInt32Array()
	_run_x1 = PackedInt32Array()
	var parent := PackedInt32Array()
	free_count = 0
	for j in SIZE:
		_run_row_start[j] = _run_x0.size()
		var row_begin := j * SIZE
		var row_end := row_begin + SIZE
		var at := row_begin
		while true:
			var s := open.find(1, at)
			if s < 0 or s >= row_end:
				break
			var e := open.find(0, s)
			if e < 0 or e > row_end:
				e = row_end
			_run_x0.append(s - row_begin)
			_run_x1.append(e - row_begin)
			parent.append(parent.size())
			free_count += e - s
			at = e
			if at >= row_end:
				break
	_run_row_start[SIZE] = _run_x0.size()
	for j in range(1, SIZE):
		var a := _run_row_start[j - 1]
		var a_end := _run_row_start[j]
		var b := _run_row_start[j]
		var b_end := _run_row_start[j + 1]
		while a < a_end and b < b_end:
			if _run_x0[a] < _run_x1[b] and _run_x0[b] < _run_x1[a]:
				_union(parent, a, b)
			if _run_x1[a] < _run_x1[b]:
				a += 1
			else:
				b += 1
	_comp_of_run = PackedInt32Array()
	_comp_of_run.resize(parent.size())
	var ids := {}
	component_count = 0
	for r in parent.size():
		var root := _find(parent, r)
		if not ids.has(root):
			ids[root] = component_count
			component_count += 1
		_comp_of_run[r] = ids[root]


static func _find(parent: PackedInt32Array, x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[maxi(ra, rb)] = mini(ra, rb)


func _component_of(node: Vector2i) -> int:
	if open[node.y * SIZE + node.x] == 0:
		return -1
	for r in range(_run_row_start[node.y], _run_row_start[node.y + 1]):
		if node.x >= _run_x0[r] and node.x < _run_x1[r]:
			return _comp_of_run[r]
	return -1


func _build_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, SIZE, SIZE)
	astar.cell_size = Vector2(CELL_M, CELL_M)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.jumping_enabled = false
	astar.update()
	astar.fill_solid_region(Rect2i(0, 0, SIZE, SIZE), true)
	for j in SIZE:
		for r in range(_run_row_start[j], _run_row_start[j + 1]):
			astar.fill_solid_region(Rect2i(_run_x0[r], j, _run_x1[r] - _run_x0[r], 1), false)
