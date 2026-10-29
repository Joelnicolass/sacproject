@tool
extends RefCounted

## Where the editor camera's ray under the mouse meets a map's ground, found by marching along the ray and asking the
## lattice how high the land is (no physics: the editor has no collision for the ground). It reads the heights being
## edited, voids included (their kept height), so the cursor sits on the ground the preview shows and a void can be aimed
## at to fill it. Not: the brush, the camera, Terrain.height_at (that one answers the ground built last, NAN over a void).

## Metres between two samples along the ray; the crossing is then narrowed down by halves.
const STEP_M := 4.0
const HALVINGS := 10
## The ray is followed this far at most.
const REACH_M := 12000.0


## The ground point (x, height, z in the Terrain's frame) under the ray `origin` + t * `direction` (both in that frame),
## or null when the ray misses the lattice. `heights`: TerrainGrid.COUNT values, row by row.
static func march(origin: Vector3, direction: Vector3, heights: PackedFloat32Array) -> Variant:
	var ray := direction.normalized()
	var start := 0.0
	var top := BrushRules.MAX_HEIGHT_M
	if origin.y > top and ray.y < 0.0:
		start = (origin.y - top) / -ray.y
	var previous := start
	var t := start
	while t <= REACH_M:
		var at := origin + ray * t
		var ground := height_at(heights, at.x, at.z)
		if not is_nan(ground) and at.y <= ground:
			return _narrowed(origin, ray, heights, previous, t) if t > start else at
		previous = t
		t += STEP_M
	return null


## The height of the lattice at (x, z), bilinear between the four vertices around it; NAN off the lattice.
static func height_at(heights: PackedFloat32Array, x: float, z: float) -> float:
	var last := float(TerrainGrid.SIDE - 1)
	var u := x / TerrainGrid.CELL_M
	var v := z / TerrainGrid.CELL_M
	if u < 0.0 or v < 0.0 or u > last or v > last:
		return NAN
	var column := mini(int(u), TerrainGrid.SIDE - 2)
	var row := mini(int(v), TerrainGrid.SIDE - 2)
	var fu := u - column
	var fv := v - row
	var low := TerrainGrid.id_of(Vector2i(column, row))
	var high := low + TerrainGrid.SIDE
	var near := lerpf(heights[low], heights[low + 1], fu)
	var far := lerpf(heights[high], heights[high + 1], fu)
	return lerpf(near, far, fv)


static func _narrowed(origin: Vector3, ray: Vector3, heights: PackedFloat32Array, above: float, below: float) -> Vector3:
	for _step in HALVINGS:
		var middle := (above + below) * 0.5
		var at := origin + ray * middle
		var ground := height_at(heights, at.x, at.z)
		if not is_nan(ground) and at.y <= ground:
			below = middle
		else:
			above = middle
	return origin + ray * below
