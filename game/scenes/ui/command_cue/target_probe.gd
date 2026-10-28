class_name TargetProbe
extends Node

## Names what lies under the pointer, a few times a second. CursorSkin and CommandCue
## read it; it decides nothing and draws nothing. The pointer is the camera's `debug_pointer` when a
## flow set it (the same one the `select` action aims with), else the mouse. The classes are
## `none` (sky), `ground`, `corpse`, `own_unit`,
## `neutral_unit`, `enemy_unit`, `own_building`, `neutral_building`, `enemy_building`, `own_soul`,
## `soul`, plus `hud` when the pointer is over a control that is not the world view.
## It is also the one owner of «which body is under the pointer» (`hovered`): the soul, the corpse, the
## building, the altar, the manafount or the creature the ray found, or null (sky, plain ground, HUD). TargetInfoPanel reads it.

signal kind_changed(kind: StringName)
## The body under the pointer changed (null: none). Emitted on the sample that saw the change.
signal hovered_changed(node: Node)
## The local player's slot arrived (`bind`). CursorSkin measures the cursor again.
signal local_slot_changed(slot: int)

const NONE := &"none"
const GROUND := &"ground"
const HUD := &"hud"
## Mask 15 = layers 1-4: ground and structures, units, souls and corpses (same ray as MatchCommand).
const MASK := 15

## Where an order (attack, guard, advance, an ability) can land: anything but the sky.
const ORDER_TARGETS: PackedStringArray = [
	"ground",
	"corpse",
	"own_unit",
	"neutral_unit",
	"enemy_unit",
	"own_building",
	"neutral_building",
	"enemy_building",
	"own_soul",
	"soul",
]

## Samples per second.
@export var hover_hz := 30.0
## The Control that takes the clicks of the world (`%View`). Over any other control the pointer is on the HUD.
@export var world_view: Control
## Controls whose rectangle is HUD even where their own mouse filter ignores the pointer (the spell book
## and the roster frame leave gaps between their buttons).
@export var hud_controls: Array[Control] = []
## The world camera: its `debug_pointer` is where flows aim.
@export var camera: Camera3D

## Slot of the player of this process; 0 until `bind` (and for good on the dedicated server: it never binds).
var local_slot := 0
## Class under the pointer at the last sample.
var kind: StringName = NONE
## Where it was sampled (screen pixels).
var pointer := Vector2(-1.0, -1.0)
## Body under the pointer at the last sample (a Soul, not its target area), or null. Never a freed body: one that dies
## between samples reads as null at once.
var hovered: Node:
	get:
		if not is_instance_valid(hovered):
			hovered = null
		return hovered
var _since := 0.0
## What the last _classify found (its body), before `hovered` takes it.
var _picked: Node


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if world_view == null:
		warnings.append("Assign `world_view` (the Control that gets the world clicks).")
	return warnings


## The local wizard arrived (MatchWorld.local_wizard_changed): from now on the pointer is sampled for its side.
func bind(wizard: WizardBody) -> void:
	local_slot = wizard.owner_slot if wizard != null else 0
	local_slot_changed.emit(local_slot)


func _process(delta: float) -> void:
	# The dedicated server has no player (local_slot == 0): nothing to point at.
	if local_slot <= 0:
		return
	_since += delta
	if _since < 1.0 / maxf(hover_hz, 1.0):
		return
	_since = 0.0
	sample()


## Reads the pointer now (the cursor and the cue also call it when an order is armed).
func sample() -> void:
	pointer = pointer_now()
	_picked = null
	var next := _classify(pointer)
	if next != kind:
		kind = next
		kind_changed.emit(kind)
	if _picked != hovered:
		hovered = _picked
		hovered_changed.emit(hovered)


## The pointer right now: the camera's forced one, else the mouse.
func pointer_now() -> Vector2:
	var cam := _camera_node()
	if cam != null and "debug_pointer" in cam:
		var forced: Vector2 = cam.get("debug_pointer")
		if forced.x >= 0.0:
			return forced
	return get_viewport().get_mouse_position()


func _camera_node() -> Node:
	return camera


func _classify(screen: Vector2) -> StringName:
	if _over_hud(screen):
		return HUD
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return NONE
	var origin := cam.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + cam.project_ray_normal(screen) * 10000.0
	)
	query.collision_mask = MASK
	var world := cam.get_world_3d()
	if world == null:
		return NONE
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return NONE
	var body: Object = hit.get("collider")
	if not body is Node:
		return GROUND
	var node := body as Node
	if node.is_in_group(Soul.TARGET_GROUP):
		var soul := node.get_parent()
		_picked = soul
		return &"own_soul" if soul != null and _slot_of(soul) == local_slot else &"soul"
	if node.is_in_group(Corpse.GROUP):
		_picked = node
		return &"corpse"
	if node.is_in_group(MapBuilding.STRUCTURE_GROUP) or node.is_in_group(Altar.GROUP):
		_picked = node
		return _with_owner(node, "building")
	if Attackable.is_body(node):
		_picked = node
		if node is GameBody and (node as GameBody).is_dead():
			return &"corpse"
		return _with_owner(node, "unit")
	# A manafount is ground for the cursor (an order lands on it), but the info panel names it.
	if node is ManafountBody:
		_picked = node
	return GROUND


## The pointer is over the HUD when the control under it is not the world view, or it left the window.
## A flow's forced pointer is a coordinate of the world, so it never counts as HUD.
func _over_hud(screen: Vector2) -> bool:
	var cam := _camera_node()
	if cam != null and "debug_pointer" in cam and (cam.get("debug_pointer") as Vector2).x >= 0.0:
		return false
	if not get_viewport().get_visible_rect().has_point(screen):
		return true
	for control in hud_controls:
		if control != null and control.is_visible_in_tree():
			var local := control.get_global_transform().affine_inverse() * screen
			if Rect2(Vector2.ZERO, control.size).has_point(local):
				return true
	var under := get_viewport().gui_get_hovered_control()
	return under != null and under != world_view


static func _slot_of(node: Node) -> int:
	return int(node.get("owner_slot")) if "owner_slot" in node else 0


func _with_owner(node: Node, noun: String) -> StringName:
	var slot := _slot_of(node)
	if slot > 0 and slot == local_slot:
		return StringName("own_" + noun)
	if slot <= 0:
		return StringName("neutral_" + noun)
	return StringName("enemy_" + noun)
