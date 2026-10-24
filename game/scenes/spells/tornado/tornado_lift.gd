class_name TornadoLift
extends Node

## What the tornado does to the bodies near it while it is active: every tick, each creature or wizard on the ground inside the reach of the
## funnel's wall is pulled a little towards a spiral around the axis and held up for that tick, so it climbs, turns, and is thrown by Tumbling.
## It does no damage (the fall does). It does not move the tornado (TornadoDrift) or draw it (TornadoLook). Server only.
## Ref: sacengine tornadoLift (state.d:22760-22801).

@export var zone: GroundZone
@export var drift: TornadoDrift
## The winds that bend the funnel (the same TornadoLook draws).
@export var winds: TornadoWinds

var _radii := TornadoRules.radii()


func _ready() -> void:
	process_physics_priority = -1
	set_physics_process(zone != null and zone.is_authority() and not Engine.is_editor_hint())


func _physics_process(_delta: float) -> void:
	if zone.cancelled or zone.phase != GroundZone.Phase.ACTIVE or drift.size <= 0.0:
		return
	var home := zone.points[0]
	var axis := TornadoRules.axis(home + Vector3.UP * TornadoRules.COLUMN_M, zone.position, drift.size, winds.phases(zone.age_ticks))
	var area := AABB(home - Vector3(350.0, 10.0, 350.0), Vector3(700.0, TornadoRules.COLUMN_M + 20.0, 700.0))
	for body in BodyNudge.bodies_in(get_tree(), area):
		_pull(body, axis)


func _pull(body: Node3D, axis: PackedVector3Array) -> void:
	var tumbling := BodyNudge.tumbling_of(body)
	if tumbling == null or BodyNudge.airborne(body) or BodyNudge.fixed(body):
		return
	var impulse := TornadoRules.pull(body.global_position, TornadoRules.centre(axis, _radii, body.global_position))
	if impulse == Vector3.INF:
		return
	if tumbling.is_on():
		tumbling.drive((tumbling.velocity + impulse).limit_length(TornadoRules.TOP_SPEED))
	else:
		tumbling.catapult(impulse.limit_length(TornadoRules.TOP_SPEED), zone.from_slot)
	tumbling.lift()
