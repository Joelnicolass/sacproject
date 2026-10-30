class_name RtsPointer
extends Node

## Screen -> world for the player's commands, in 2D and 3D: the ground point under a pixel, the unit
## or body there, what that body is to the local player, the camera's yaw and whether the camera is
## being dragged. 3D casts a ray from the viewport's Camera3D; 2D queries the physics point under the
## canvas position. A unit with no collider is still found by its projected center within `pick_px`.
## Points are kit points (RtsSpace). It arms, orders and says nothing.

enum Dimension { AUTO, D3, D2 }

## What a body that is no unit is (a building with no RtsUnit, a prop).
const OTHER := &"other"

## AUTO: 3D when the viewport has a Camera3D, else 2D.
@export var dimension := Dimension.AUTO
## The camera that steers the view (RtsCamera3D, RtsCamera2D or any node with `is_dragging()` and
## `debug_pointer`). Empty: the viewport's camera, with no drag and no forced pointer.
@export var camera: Node
## The player of this screen.
@export var local_slot := 1
## That player's team; -1 = `local_slot` (every player alone).
@export var local_team := -1
## 3D: the layers of the ground. 2D: unused (the ground is everywhere, or `ground_bounds_2d`).
@export_flags_3d_physics var ground_mask := 1
## The layers of the units' colliders.
@export_flags_3d_physics var unit_mask := 2
## The layers `body_under` looks at (units, buildings, anything to click).
@export_flags_3d_physics var pick_mask := 3
## Only this node (or its children) is ground; empty = anything on `ground_mask`.
@export var ground: Node
## A unit whose center projects within this many pixels of the pointer is under it, collider or not
## (0 = colliders only).
@export var pick_px := 14.0
## 2D: the ground ends at this world rectangle (a click outside has no ground); empty = everywhere.
@export var ground_bounds_2d := Rect2()
## 3D: how far a ray goes.
@export var ray_length := 10000.0


func is_3d() -> bool:
	if dimension == Dimension.D3:
		return true
	if dimension == Dimension.D2:
		return false
	return get_viewport() != null and get_viewport().get_camera_3d() != null


## The team of this screen's player.
func team() -> int:
	return local_slot if local_team < 0 else local_team


## True while the camera counts the pointer as dragged: a click that ends a drag is not an order.
func camera_dragged() -> bool:
	return camera != null and camera.has_method("is_dragging") and bool(camera.call("is_dragging"))


## Where a keyboard action aims: the camera's forced `debug_pointer` when set (a test flow), else the
## middle of the screen.
func action_pointer() -> Vector2:
	if camera != null and "debug_pointer" in camera:
		var forced: Vector2 = camera.get("debug_pointer")
		if forced.x >= 0.0:
			return forced
	return get_viewport().get_visible_rect().size * 0.5


## The pointer now: the forced one, else the mouse.
func pointer_now() -> Vector2:
	if camera != null and "debug_pointer" in camera:
		var forced: Vector2 = camera.get("debug_pointer")
		if forced.x >= 0.0:
			return forced
	return get_viewport().get_mouse_position()


## The kit yaw the view looks along (formations turn by it). 3D: the camera's forward; 2D: the
## screen's up, so a formation faces up the screen.
func camera_yaw() -> float:
	var viewport := get_viewport()
	if viewport == null:
		return 0.0
	if is_3d():
		var cam := viewport.get_camera_3d()
		if cam == null:
			return 0.0
		var ahead := -cam.global_basis.z
		return atan2(ahead.x, ahead.z)
	var up := viewport.get_canvas_transform().affine_inverse().basis_xform(Vector2(0.0, -1.0))
	return atan2(up.x, up.y)


## The ground point under `screen` (a kit point), or null (the sky, off the map).
func ground_at(screen: Vector2) -> Variant:
	if is_3d():
		var hit := _ground_hit(screen)
		return null if hit.is_empty() else hit.get("position")
	var world := RtsSpace.world_2d_at(get_viewport(), screen)
	if ground_bounds_2d.has_area() and not ground_bounds_2d.has_point(world):
		return null
	return RtsSpace.from_2d(world)


## The unit under `screen` (anyone's), or null.
func unit_under(screen: Vector2, skip: Array = []) -> RtsUnit:
	var body := _first_body(screen, unit_mask, skip, true)
	var unit := RtsUnit.of(body)
	if unit != null:
		return unit
	return _unit_near(screen, skip)


## The first body under `screen` that is not ground (a unit, a building), or null. `skip` lists
## bodies to see through (the player's own hero when a keyboard order aims through it).
func body_under(screen: Vector2, skip: Array = []) -> Node:
	var body := _first_body(screen, pick_mask, skip, false)
	if body != null:
		return body
	var unit := _unit_near(screen, skip)
	return unit.body if unit else null


## True when nothing but ground (or nothing at all) is under `screen`.
func is_empty_at(screen: Vector2) -> bool:
	return body_under(screen) == null


## What `body` is to this screen's player: RtsUnit.OWN / ALLY / NEUTRAL / ENEMY for a unit, OTHER for
## anything else.
func relation(body: Node) -> StringName:
	var unit := RtsUnit.of(body)
	if unit == null:
		return OTHER
	return unit.relation_to(local_slot, team())


## True when `body` is a unit that is a foe of this screen's player.
func is_enemy(body: Node) -> bool:
	return relation(body) == RtsUnit.ENEMY


## A 3D ray from the camera through `screen` on `mask`, skipping `exclude` (RIDs). {} when nothing is
## hit or there is no Camera3D.
func cast_3d(screen: Vector2, mask: int, exclude: Array[RID] = []) -> Dictionary:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam == null or cam.get_world_3d() == null:
		return {}
	var origin := cam.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + cam.project_ray_normal(screen) * ray_length
	)
	query.collision_mask = mask
	query.exclude = exclude
	return cam.get_world_3d().direct_space_state.intersect_ray(query)


func _ground_hit(screen: Vector2) -> Dictionary:
	var exclude: Array[RID] = []
	for _attempt in 8:
		var hit := cast_3d(screen, ground_mask, exclude)
		if hit.is_empty():
			return hit
		if _is_ground(hit.get("collider")):
			return hit
		exclude.append(hit.get("rid"))
	return {}


func _is_ground(collider: Object) -> bool:
	if not collider is Node:
		return false
	if RtsUnit.of(collider) != null:
		return false
	if ground == null:
		return true
	return collider == ground or ground.is_ancestor_of(collider as Node)


## The body the first collider on `mask` under `screen` belongs to (`skip` seen through). 3D: ground
## in front hides what is behind it (null). `units_only`: null unless it is a unit.
func _first_body(screen: Vector2, mask: int, skip: Array, units_only: bool) -> Node:
	if is_3d():
		var exclude: Array[RID] = []
		for node in skip:
			if node is CollisionObject3D and is_instance_valid(node):
				exclude.append((node as CollisionObject3D).get_rid())
		var hit := cast_3d(screen, mask, exclude)
		if hit.is_empty():
			return null
		var collider: Object = hit.get("collider")
		if not collider is Node:
			return null
		var hit_unit := RtsUnit.of(collider)
		if hit_unit != null:
			return hit_unit.body
		if units_only or _is_ground(collider):
			return null
		return collider as Node
	var space := _space_2d()
	if space == null:
		return null
	var query := PhysicsPointQueryParameters2D.new()
	query.position = RtsSpace.world_2d_at(get_viewport(), screen)
	query.collision_mask = mask
	query.collide_with_areas = true
	var exclude_2d: Array[RID] = []
	for node in skip:
		if node is CollisionObject2D and is_instance_valid(node):
			exclude_2d.append((node as CollisionObject2D).get_rid())
	query.exclude = exclude_2d
	var best: Node = null
	var best_index := -1
	for hit in space.intersect_point(query, 32):
		var collider: Object = hit.get("collider")
		if not collider is Node:
			continue
		var unit := RtsUnit.of(collider)
		if unit == null and _is_ground_2d(collider as Node):
			continue
		if units_only and unit == null:
			continue
		var node: Node = unit.body if unit else collider as Node
		if skip.has(node):
			continue
		# The one drawn on top wins (the latest in the tree).
		var index := node.get_index() if node.get_parent() else 0
		if best == null or index > best_index:
			best = node
			best_index = index
	return best


## 2D has no ground collider unless `ground` names one.
func _is_ground_2d(node: Node) -> bool:
	return ground != null and (node == ground or ground.is_ancestor_of(node))


## The unit whose projected center is nearest `screen` within `pick_px`, or null.
func _unit_near(screen: Vector2, skip: Array) -> RtsUnit:
	if pick_px <= 0.0:
		return null
	var best: RtsUnit = null
	var best_d := pick_px
	var viewport := get_viewport()
	for unit in RtsUnit.all(get_tree()):
		if skip.has(unit.body):
			continue
		var at: Variant = RtsSpace.screen_of(viewport, unit.center_point(), unit.is_2d())
		if at == null:
			continue
		var d := (at as Vector2).distance_to(screen)
		if d <= best_d:
			best_d = d
			best = unit
	return best


func _space_2d() -> PhysicsDirectSpaceState2D:
	var viewport := get_viewport()
	if viewport == null or viewport.world_2d == null:
		return null
	return viewport.world_2d.direct_space_state
