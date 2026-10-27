class_name SnowballFlight
extends Node3D

## The snowball of Frozen Ground, from the wizard's hands to the ground: while he casts it grows in front of him and rises to over his head,
## spinning; when the cast ends it flies a parabola to the point of the click in the zone's arming time, leaving a trail; when it lands it
## bursts into shards. Presentation only, on every peer, from the zone's phase. It freezes nobody (ZoneFreeze).
## Ref: sacengine frozenGroundSnowballCastingPosition, updateFrozenGroundSnowball (state.d:11097-11102, 19773-19828).

@export var zone: GroundZone
## The ball: a mesh child (it holds the mesh).
@export var ball: MeshInstance3D
## What the ball leaves behind it every tick, two puffs, and what it bursts into on landing.
@export var trail: ParticleType
@export var shards: Array[ParticleType] = []
## Metres in front of the wizard's box the ball hangs while it grows, and over his head it ends.
@export_range(0.0, 3.0, 0.05, "suffix:m") var in_front_m := 0.75
@export_range(0.0, 3.0, 0.05, "suffix:m") var over_head_m := 0.5
## The flight's downward pull, m/s².
@export_range(1.0, 60.0, 0.5, "suffix:m/s²") var gravity := 25.0
## The ball turns this many turns a second, at most and at least.
@export var spin_turns := Vector2(0.5, 1.5)

var _from := Vector3.ZERO
var _axis := Vector3.UP
var _turn := 0.0


func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ready() -> void:
	set_process(false)
	visible = false
	if Engine.is_editor_hint() or zone == null:
		return
	var rng := MatchSeed.rng(["snowball", String(zone.name)])
	_axis = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
	_turn = TAU * rng.randf_range(spin_turns.x, spin_turns.y)
	zone.phase_changed.connect(_on_phase)
	_on_phase(zone.phase)


func _on_phase(phase: int) -> void:
	visible = phase <= GroundZone.Phase.ARMING
	set_process(visible)
	if phase == GroundZone.Phase.ARMING:
		_from = global_position
	elif phase == GroundZone.Phase.ACTIVE:
		for type in shards:
			FxBus.play(type, zone.points[0])


func _process(delta: float) -> void:
	ball.rotate(_axis, _turn * delta)
	if zone.phase == GroundZone.Phase.CASTING:
		_follow_wizard()
	else:
		_fly()
	if trail != null and zone.phase == GroundZone.Phase.ARMING:
		FxBus.puff(trail, global_position)
		FxBus.puff(trail, global_position)


## In front of the wizard, rising from his feet to over his head as it grows from nothing to its size.
func _follow_wizard() -> void:
	var wizard := zone.caster() as WizardBody
	if wizard == null:
		return
	var progress := clampf(float(zone.phase_ticks) / float(maxi(zone.cast_ticks, 1)), 0.0, 1.0)
	var box := DrawnPose.box(wizard)
	var front := wizard.facing_flat() * (maxf(box.size.x, box.size.z) * 0.5 + in_front_m)
	global_position = Vector3(box.get_center().x, lerpf(box.position.y, box.end.y + over_head_m, progress), box.get_center().z) + front
	ball.scale = Vector3.ONE * maxf(progress, 0.01)


## A parabola from where the cast left it to the click: the straight line plus the arc a pull of `gravity` makes in that time.
func _fly() -> void:
	var seconds := float(maxi(zone.arm_ticks, 1)) / MatchClock.TICKS_PER_SECOND_F
	var t := clampf(float(zone.phase_ticks) / float(maxi(zone.arm_ticks, 1)), 0.0, 1.0)
	var line := _from.lerp(zone.points[0], t)
	global_position = line + Vector3(0.0, 0.5 * gravity * (t * seconds) * ((1.0 - t) * seconds), 0.0)
