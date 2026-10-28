class_name PointerRay
extends Node

## Screen -> world for the player's commands: the ground point, the body, soul, corpse or building under a pixel, the
## body nearest a minimap point, and the facts about a body the commands ask (corpse? enemy?). It reads the physics
## space and the camera only; it arms, orders and says nothing. Layers: 1 ground and structures, 2 units, 4 souls,
## 8 corpses (mask 15 = all four).

const _WORLD := preload("res://scenes/match/match_world.gd")
const _CAMERA := preload("res://scenes/camera/world_camera.gd")

## A click on the minimap finds a body within this many minimap pixels of it (meters = pixels × the minimap zoom).
@export var minimap_pick_units := 3.6
## The minimap a click is found on. Empty (the minimap was removed): there is no minimap pick.
@export var minimap: Minimap
## Who looks at this screen: what is not this seat's is an enemy to the pointer.
@export var seat: MpLocalSeat

@onready var _camera: _CAMERA = get_node_or_null("%Camera")


func _ready() -> void:
	if seat == null:
		push_warning("PointerRay: assign `seat` (the MpLocalSeat); every body counts as an enemy without it")


## True while the world camera counts the pointer as dragged (a click that ends it is not an order).
func camera_dragged() -> bool:
	return _camera != null and _camera.is_dragging()


## The local wizard, or null.
func wizard() -> Node3D:
	var world := owner as _WORLD
	return world.local_wizard() if world else null


## The camera's debug pointer when set (AgentKit flows), else the crosshair.
func action_pointer() -> Vector2:
	if _camera != null and _camera.debug_pointer.x >= 0.0:
		return _camera.debug_pointer
	return get_viewport().get_visible_rect().size * 0.5


func camera_yaw() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	var ahead := -cam.global_basis.z
	return atan2(ahead.x, ahead.z)


func ground(screen: Vector2) -> Variant:
	var hit := cast(screen, 1, true)
	return null if hit.is_empty() else hit.get("position")


func unit_under(screen: Vector2) -> Node3D:
	var hit: Dictionary = cast(screen, 2, false)
	if hit.is_empty():
		return null
	var body: Object = hit.get("collider")
	if body is Node3D and (body as Node).is_in_group(UnitBody.GROUP):
		return body
	return null


## A wizard, creature or structure under the cursor, or null. `skip_own_wizard` ignores the local wizard.
func body_under(screen: Vector2, skip_own_wizard: bool) -> Node3D:
	var skip: Array[RID] = []
	var own := wizard()
	if skip_own_wizard and own is CollisionObject3D:
		skip.append((own as CollisionObject3D).get_rid())
	var hit: Dictionary = cast(screen, 3, false, skip)
	if hit.is_empty():
		return null
	var body: Object = hit.get("collider")
	if body is Node3D and Attackable.is_body(body as Node):
		return body as Node3D
	return null


func soul_under(screen: Vector2) -> Node3D:
	var hit: Dictionary = cast(screen, 4, false)
	if hit.is_empty():
		return null
	var body: Object = hit.get("collider")
	if body is Node and (body as Node).is_in_group(Soul.TARGET_GROUP):
		return (body as Node).get_parent() as Node3D
	return null


## A corpse under the cursor (layer 8, mask 8): the body itself, group «corpse».
func corpse_under(screen: Vector2) -> Node3D:
	var hit: Dictionary = cast(screen, 8, false)
	if hit.is_empty():
		return null
	var body: Object = hit.get("collider")
	if body is Node3D and (body as Node).is_in_group(Corpse.GROUP):
		return body as Node3D
	return null


func building_under(screen: Vector2) -> Node3D:
	return _building_of(cast(screen, 1, false))


## A structure or altar only when it is the first thing under the cursor (mask 15, as
## `is_empty_at`): a wizard, corpse or soul in front of a house keeps the click from inspecting it.
func building_first(screen: Vector2) -> Node3D:
	return _building_of(cast(screen, 15, false))


## True when the first thing under the cursor is ground or nothing: not a creature, wizard,
## structure, altar, corpse or soul.
func is_empty_at(screen: Vector2) -> bool:
	var hit: Dictionary = cast(screen, 15, false)
	if hit.is_empty():
		return true
	var body: Object = hit.get("collider")
	if body is Node:
		var node := body as Node
		if Attackable.is_body(node) or node.is_in_group(Corpse.GROUP) or node.is_in_group(Soul.TARGET_GROUP) \
				or node.is_in_group(MapBuilding.STRUCTURE_GROUP) or node.is_in_group(Altar.GROUP):
			return false
	return true


## The body (wizard or creature, not a corpse) closest to a world point and within `minimap_pick_units` minimap pixels of the
## minimap at its current zoom; an enemy that cannot be targeted (stealth) is not found. `own_only`: only the local side's.
func body_near(point: Vector3, own_only := false) -> Node3D:
	if minimap == null:
		return null
	var reach := minimap_pick_units * float(minimap.zoom)
	var best: Node3D = null
	var best_distance := reach
	for node in get_tree().get_nodes_in_group(UnitBody.GROUP) + get_tree().get_nodes_in_group(WizardBody.GROUP):
		var body := node as Node3D
		if body == null or not Attackable.is_body(body) or is_corpse(body):
			continue
		var enemy := is_enemy(body)
		if own_only and enemy:
			continue
		if enemy and not _targetable(body):
			continue
		var distance := Vector2(body.global_position.x - point.x, body.global_position.z - point.z).length()
		if distance < best_distance:
			best_distance = distance
			best = body
	return best


func cast(screen: Vector2, mask: int, skip_wizards: bool, skip: Array[RID] = []) -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var origin := cam.project_ray_origin(screen)
	var normal := cam.project_ray_normal(screen)
	var world := cam.get_world_3d()
	if world == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(origin, origin + normal * 10000.0)
	query.collision_mask = mask
	var exclude := skip.duplicate()
	if skip_wizards:
		for wizard_node in get_tree().get_nodes_in_group(WizardBody.GROUP):
			if wizard_node is CollisionObject3D:
				exclude.append((wizard_node as CollisionObject3D).get_rid())
	query.exclude = exclude
	return world.direct_space_state.intersect_ray(query)


static func is_corpse(body: Node3D) -> bool:
	if body.is_in_group(Corpse.GROUP):
		return true
	if body is UnitBody:
		return (body as UnitBody).is_dead()
	if body is DoctorBody:
		return (body as DoctorBody).is_dead()
	if body is CastTower:
		return (body as CastTower).is_destroyed()
	return false


## True when the body is not this seat's (a corpse, a neutral and a stranger count; with no seat, everything does).
func is_enemy(body: Node3D) -> bool:
	return seat == null or owner_slot_of(body) != seat.slot


## The side a body belongs to (0 for anything that is not a creature, wizard, doctor or structure).
static func owner_slot_of(body: Node3D) -> int:
	if body is UnitBody:
		return (body as UnitBody).owner_slot
	if body is WizardBody:
		return (body as WizardBody).owner_slot
	if body is DoctorBody:
		return (body as DoctorBody).owner_slot
	if body is CastTower:
		return (body as CastTower).owner_slot
	return 0


static func _targetable(body: Node3D) -> bool:
	if body is UnitBody:
		return (body as UnitBody).is_targetable()
	if body is WizardBody:
		return (body as WizardBody).is_targetable()
	return true


static func _building_of(hit: Dictionary) -> Node3D:
	var body: Object = null if hit.is_empty() else hit.get("collider")
	if body is Node3D and ((body as Node).is_in_group(MapBuilding.STRUCTURE_GROUP) or (body as Node).is_in_group(Altar.GROUP)):
		return body as Node3D
	return null
