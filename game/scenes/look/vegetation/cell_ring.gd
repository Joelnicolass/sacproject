class_name CellRing
extends RefCounted

## Which cells of a square grid exist around the camera and in which tier (level of detail), shared
## by the vegetation layers (GrassField now; FloraField later). Moved from GrassField with the same arithmetic (the
## golden debug/look/cell_ring_golden.txt was recorded before the move).
## - A cell appears when its rect is within `radius + 1` of the eye (the fade center) and goes away past
##   `radius + keep_margin_m`.
## - Its tier goes by the rect distance to the field center: tier i starts at `tier_starts[i]`, entered only
##   `tier_hysteresis_m` past it, so a cell does not flip back and forth.
## The ring owns only keys and tiers: `update` says what changed and the layer makes, moves or frees its own nodes.
## `field_center`, `fade_center` and `view_camera` are the centers and the camera (the editor viewport's or the game's).
## Ref: RFC-054 054b (F381).

## Side of a cell in meters.
var cell_m := 16.0
## Cells per side of the map (keys go from 0 to map_cells - 1).
var map_cells := 160
## A cell stays until its rect is this far past the radius; new cells start at `radius + 1`.
var keep_margin_m := 6.0
var tier_hysteresis_m := 4.0
## Distance (to the field center) where each tier starts; [0] is 0.
var tier_starts := PackedFloat32Array()

## Vector2i -> tier.
var _tiers := {}


func _init(cell_size_m := 16.0, cells := 160) -> void:
	cell_m = cell_size_m
	map_cells = cells


func has(key: Vector2i) -> bool:
	return _tiers.has(key)


func tier_of(key: Vector2i) -> int:
	return int(_tiers.get(key, -1))


func keys() -> Array:
	return _tiers.keys()


func size() -> int:
	return _tiers.size()


## Key -> tier (a copy).
func tiers() -> Dictionary:
	return _tiers.duplicate()


func clear() -> void:
	_tiers.clear()


## Brings the ring to a camera: cells within `radius` of `eye` (the fade center) exist, tiers by the distance to
## `center` (the field center). Returns {added, removed, retiered}: Arrays of Vector2i, in the order they happened.
func update(radius: float, eye: Vector2, center: Vector2) -> Dictionary:
	var added: Array[Vector2i] = []
	var removed: Array[Vector2i] = []
	var retiered: Array[Vector2i] = []
	var first := Vector2i((eye - Vector2.ONE * (radius + 2.0)) / cell_m)
	var last := Vector2i((eye + Vector2.ONE * (radius + 2.0)) / cell_m)
	for iz in range(maxi(first.y - 1, 0), mini(last.y + 1, map_cells - 1) + 1):
		for ix in range(maxi(first.x - 1, 0), mini(last.x + 1, map_cells - 1) + 1):
			var key := Vector2i(ix, iz)
			if _tiers.has(key):
				continue
			if rect_distance(key, eye) <= radius + 1.0:
				_tiers[key] = tier_for(rect_distance(key, center), 0)
				added.append(key)
	for key: Vector2i in _tiers.keys():
		var d := rect_distance(key, center)
		if rect_distance(key, eye) > radius + keep_margin_m:
			_tiers.erase(key)
			removed.append(key)
			continue
		var tier: int = _tiers[key]
		var wanted := tier_for(d, tier)
		if wanted != tier:
			_tiers[key] = wanted
			retiered.append(key)
	return {"added": added, "removed": removed, "retiered": retiered}


## Tier of a cell at rect distance `d` (0 = the nearest). `current` adds the hysteresis: a cell enters an outer tier
## only `tier_hysteresis_m` past its start.
func tier_for(d: float, current: int) -> int:
	var tier := 0
	for i in range(1, tier_starts.size()):
		var start := tier_starts[i] + (tier_hysteresis_m if current < i else 0.0)
		if d <= start:
			break
		tier = i
	return tier


## Distance from a point to the rect of a cell (0 inside it).
func rect_distance(key: Vector2i, from: Vector2) -> float:
	var low := Vector2(key) * cell_m
	var dx := maxf(maxf(low.x - from.x, from.x - (low.x + cell_m)), 0.0)
	var dz := maxf(maxf(low.y - from.y, from.y - (low.y + cell_m)), 0.0)
	return sqrt(dx * dx + dz * dz)


## The ground point the camera looks at, no farther than the field can use: low cameras get a center ahead of them (so
## the ring covers what they see), high ones look straight at it. `ground_y` is the land under the camera.
static func field_center(cam_local: Vector3, forward: Vector3, near_radius: float, ground_y: float) -> Vector2:
	var flat := Vector2(forward.x, forward.z)
	var above := maxf(cam_local.y - ground_y, 0.0)
	var reach := near_radius * 0.9 + above * 0.5
	if forward.y < -0.02 and flat.length() > 0.001:
		reach = minf(reach, above * flat.length() / -forward.y)
	var here := Vector2(cam_local.x, cam_local.z)
	return here + flat.normalized() * reach if flat.length() > 0.001 else here


## The point the distance fade is measured from: under the camera, led toward where it looks by the camera's height over
## the ground (never past the ground point it looks at). A game camera (a few meters up) fades around itself, so turning
## does not move the fade; a high RTS camera fades around what it looks at.
static func fade_center(cam_local: Vector3, forward: Vector3, ground_y: float) -> Vector2:
	var flat := Vector2(forward.x, forward.z)
	var here := Vector2(cam_local.x, cam_local.z)
	if flat.length() <= 0.001:
		return here
	var above := maxf(cam_local.y - ground_y, 0.0)
	var reach := above
	if forward.y < -0.02:
		reach = minf(reach, above * flat.length() / -forward.y)
	return here + flat.normalized() * reach


## The camera a layer follows: the 3D viewport's in the editor (null when `follow_editor` is off), the game's otherwise.
static func view_camera(node: Node, follow_editor: bool) -> Camera3D:
	if Engine.is_editor_hint():
		if not follow_editor or not Engine.has_singleton(&"EditorInterface"):
			return null
		var editor: Object = Engine.get_singleton(&"EditorInterface")
		var viewport: SubViewport = editor.call("get_editor_viewport_3d", 0)  # dynamic: EditorInterface does not exist in an exported game
		return viewport.get_camera_3d() if viewport else null
	return node.get_viewport().get_camera_3d()
