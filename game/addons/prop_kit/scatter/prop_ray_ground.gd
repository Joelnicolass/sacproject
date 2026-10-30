@tool
class_name PropRayGround
extends PropGround

## The ground is whatever the physics hits: a ray straight down at each point of `area`, against
## `collision_mask` (the terrain, floors, rocks...). Works with any collider, in the editor and in
## a running game (a collider is in the space one physics frame after it enters the tree). Keep
## the props' own layer out of the mask, or a scatter could stand props on other props.

## The area to scatter over (x, z), in global coordinates.
@export var area := Rect2(-50.0, -50.0, 100.0, 100.0):
	set(value):
		area = value
		emit_changed()
@export_flags_3d_physics var collision_mask := 1
## Steeper than this, no prop (degrees from flat).
@export_range(0.0, 90.0, 0.5, "suffix:°") var max_slope_deg := 40.0
## The rays go from this height down to `bottom`.
@export var top := 1000.0
@export var bottom := -1000.0

var _space: PhysicsDirectSpaceState3D
var _query := PhysicsRayQueryParameters3D.new()
var _at := Vector2.INF
var _hit_position := Vector3.ZERO
var _hit_normal := Vector3.UP
var _hit := false


func begin(scatter: Node) -> bool:
	_at = Vector2.INF
	var node := scatter as Node3D
	if node == null or not node.is_inside_tree():
		return false
	_space = node.get_world_3d().direct_space_state
	_query.collision_mask = collision_mask
	_query.hit_back_faces = false
	return _space != null


func bounds() -> Rect2:
	return area


func height_at(at: Vector2) -> float:
	_cast(at)
	return _hit_position.y if _hit else 0.0


func normal_at(at: Vector2) -> Vector3:
	_cast(at)
	return _hit_normal if _hit else Vector3.UP


func weight_at(at: Vector2) -> float:
	_cast(at)
	if not _hit:
		return 0.0
	var slope := rad_to_deg(acos(clampf(_hit_normal.dot(Vector3.UP), -1.0, 1.0)))
	return 0.0 if slope > max_slope_deg else 1.0


## One ray per point: the planner asks the weight, then the height and normal, of the same point.
func _cast(at: Vector2) -> void:
	if at == _at:
		return
	_at = at
	_hit = false
	if _space == null:
		return
	_query.from = Vector3(at.x, top, at.y)
	_query.to = Vector3(at.x, bottom, at.y)
	var result := _space.intersect_ray(_query)
	if result.is_empty():
		return
	_hit = true
	_hit_position = result["position"]
	_hit_normal = result["normal"]
