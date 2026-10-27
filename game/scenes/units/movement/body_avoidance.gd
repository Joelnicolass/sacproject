@tool
class_name BodyAvoidance
extends NavigationAgent3D

## Server side separation of a body: the engine's avoidance (RVO) on a NavigationAgent3D, instead of the
## boxes and pushes of the original. The body calls steer() with the flat velocity it wants; the
## server answers in the same physics step (after every _physics_process) through `solved`, and the body moves with that
## velocity (move_and_slide). The radius is the body's box (BodyBox); the bodies do not collide by physics, only steer.
## Who gives way is the priority: a body that walks is above one that stands (the settled units of a formation make way
## for the walkers) and a wizard is above his creatures (his own army never pushes him back: debug/orders/escort_jam.tscn).
## Deterministic: the avoidance runs in the physics step on one thread (project.godot [navigation]) and the agents
## are stepped in the order they were registered.
## Ref: RFC-036 036f, sacengine positionAfterCollision.

## The safe velocity (flat, m/s) of this tick, or the wanted one for a fixed body (frozen, petrified, pinned: it is an
## obstacle that is never steered).
signal solved(flat_velocity: Vector3)

@export var body: CharacterBody3D
## Priority of a body that walks (0..1: the higher, the less it gives way).
@export_range(0.0, 1.0) var moving_priority := 0.5
## Priority of a body that stands still, so the walkers do not wait behind it.
@export_range(0.0, 1.0) var idle_priority := 0.25
## Top speed (m/s) at which a body that stands still is steered out of a walker's way.
@export var yield_speed := 2.5

var _wanted := Vector3.ZERO
var _fixed := false
## A velocity was handed to the server and its answer has not come.
var _pending := false
## steer() ran in this physics tick.
var _steered := false


func _get_configuration_warnings() -> PackedStringArray:
	if body == null:
		return PackedStringArray(["Asigná body (el CharacterBody3D que esquiva)."])
	return PackedStringArray()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	avoidance_enabled = false
	velocity_computed.connect(_on_velocity_computed)


## Server (or solo): `wanted` is the velocity the body would walk with (x, z; y is the body's own). True when the answer
## comes through `solved` this physics step; false when the body is not an obstacle (or this is a client): it moves with
## `wanted` itself.
func steer(wanted: Vector3, fixed := false) -> bool:
	if not _active():
		return false
	_wanted = wanted
	_fixed = fixed
	var flat := Vector3(wanted.x, 0.0, wanted.z)
	var speed := flat.length()
	_place(fixed, speed)
	NavigationServer3D.agent_set_velocity(get_rid(), flat)
	_pending = true
	_steered = true
	return true


## The agent's own tick (it runs after the body's): a body that did not steer (it is being seated, say) is still an
## obstacle that stands; one that is not an obstacle leaves the avoidance.
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _steered:
		_steered = false
		return
	_pending = false
	if _active():
		_place(false, 0.0)
		NavigationServer3D.agent_set_velocity(get_rid(), Vector3.ZERO)
	else:
		avoidance_enabled = false


func _place(fixed: bool, speed: float) -> void:
	var half := BodyBox.half_size(body)
	if not is_equal_approx(radius, half):
		radius = half
	var tall := BodyBox.body_height(body)
	if not is_equal_approx(height, tall):
		height = tall
	if fixed:
		avoidance_priority = 1.0
		max_speed = 0.001
	elif speed > 0.0:
		avoidance_priority = moving_priority
		max_speed = speed
	else:
		avoidance_priority = idle_priority
		max_speed = yield_speed
	avoidance_enabled = true
	NavigationServer3D.agent_set_position(get_rid(), body.global_position)


func _active() -> bool:
	if body == null or not body.is_inside_tree():
		return false
	if not is_multiplayer_authority():
		return false
	return BodyBox.is_obstacle(body)


func _on_velocity_computed(safe: Vector3) -> void:
	if not _pending:
		return
	_pending = false
	solved.emit(_wanted if _fixed else Vector3(safe.x, _wanted.y, safe.z))
