@tool
extends RefCounted

## Step 2 of the ground import: cuts every walkable triangle whose edge is longer than `max_edge_m` so the displacement of a
## spell (a crater, a mound) has vertices to move. An edge is cut at its middle if and only if it is longer than the limit,
## whatever triangle it belongs to, so two triangles that share an edge always cut it the same way and no crack opens. The new
## points lie on the old edges, so the ground keeps its exact shape. Walls and undersides are left alone. Static helpers.
## A corner is a record [position, normal, uv]; a triangle is three records in Godot winding.

const MAX_DEPTH := 12


## `soup` (see ground_soup.gd) with its walkable triangles cut; `min_up` is the cosine of the steepest walkable slope.
static func run(soup: Dictionary, max_edge_m: float, min_up: float) -> Dictionary:
	var out := {"pos": PackedVector3Array(), "nrm": PackedVector3Array(), "uv": PackedVector2Array(), "mat": PackedInt32Array(), "materials": soup["materials"]}
	var pos: PackedVector3Array = soup["pos"]
	var nrm: PackedVector3Array = soup["nrm"]
	var uv: PackedVector2Array = soup["uv"]
	var mat: PackedInt32Array = soup["mat"]
	var limit := max_edge_m * max_edge_m
	for t in mat.size():
		var c := t * 3
		var normal := (pos[c + 2] - pos[c]).cross(pos[c + 1] - pos[c])
		var walkable := normal.y > 0.0 and normal.y / maxf(normal.length(), 1e-12) >= min_up
		var corners: Array = [[pos[c], nrm[c], uv[c]], [pos[c + 1], nrm[c + 1], uv[c + 1]], [pos[c + 2], nrm[c + 2], uv[c + 2]]]
		_refine(corners, mat[t], limit if walkable else INF, out, 0)
	return out


## Emits the triangle or, if some edge is over the limit, the pieces it is cut in.
static func _refine(v: Array, material: int, limit: float, out: Dictionary, depth: int) -> void:
	var cut: Array[bool] = [false, false, false]  # edge i runs from corner i to corner i + 1
	var count := 0
	for i in 3:
		var from: Vector3 = (v[i] as Array)[0]
		var to: Vector3 = (v[(i + 1) % 3] as Array)[0]
		cut[i] = depth < MAX_DEPTH and from.distance_squared_to(to) > limit
		count += int(cut[i])
	if count == 0:
		_emit(v, material, out)
	elif count == 3:
		var ab := _mid(v[0], v[1])
		var bc := _mid(v[1], v[2])
		var ca := _mid(v[2], v[0])
		_refine([v[0], ab, ca], material, limit, out, depth + 1)
		_refine([ab, v[1], bc], material, limit, out, depth + 1)
		_refine([ca, bc, v[2]], material, limit, out, depth + 1)
		_refine([ab, bc, ca], material, limit, out, depth + 1)
	elif count == 1:
		var i := cut.find(true)
		var middle := _mid(v[i], v[(i + 1) % 3])
		_refine([v[i], middle, v[(i + 2) % 3]], material, limit, out, depth + 1)
		_refine([middle, v[(i + 1) % 3], v[(i + 2) % 3]], material, limit, out, depth + 1)
	else:
		# Two cuts: B is the corner the two cut edges share, A comes before it and C after it (the uncut edge is C to A).
		var uncut := cut.find(false)
		var a: Array = v[(uncut + 1) % 3]
		var b: Array = v[(uncut + 2) % 3]
		var c: Array = v[uncut]
		var m1 := _mid(a, b)
		var m2 := _mid(b, c)
		_refine([m1, b, m2], material, limit, out, depth + 1)
		# The quad A, M1, M2, C is split along its shorter diagonal (A to M2 when they tie).
		if (a[0] as Vector3).distance_squared_to(m2[0]) <= (m1[0] as Vector3).distance_squared_to(c[0]):
			_refine([a, m1, m2], material, limit, out, depth + 1)
			_refine([a, m2, c], material, limit, out, depth + 1)
		else:
			_refine([a, m1, c], material, limit, out, depth + 1)
			_refine([m1, m2, c], material, limit, out, depth + 1)


## The middle of the edge between two corners (adding is commutative, so both sides of an edge get the same bits).
static func _mid(first: Array, second: Array) -> Array:
	return [((first[0] as Vector3) + (second[0] as Vector3)) * 0.5, (((first[1] as Vector3) + (second[1] as Vector3)) * 0.5).normalized(),
			((first[2] as Vector2) + (second[2] as Vector2)) * 0.5]


static func _emit(v: Array, material: int, out: Dictionary) -> void:
	var pos: PackedVector3Array = out["pos"]
	var nrm: PackedVector3Array = out["nrm"]
	var uv: PackedVector2Array = out["uv"]
	var mat: PackedInt32Array = out["mat"]
	for corner: Array in v:
		pos.append(corner[0])
		nrm.append(corner[1])
		uv.append(corner[2])
	mat.append(material)
	out["pos"] = pos
	out["nrm"] = nrm
	out["uv"] = uv
	out["mat"] = mat
