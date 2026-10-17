class_name Petrified
extends Affliction

## F137 (RFC-030i-b): sacengine petrified. petrify (state.d:11631-11645) refuses a ccProtected body (a petrified one
## among them, stats.d:89) and one that cannot be immobilized (dying, dead, reviving…, state.d:189-197); a stunned body
## is petrified all the same (the type's `cancels`). While it lasts the type's flags say the rest: held, not pushed,
## a flier falls (startTumbling), every hit ×0.2 (8965), refuses crowd control. Here: the pose freezes (ClipPosePlayer)
## and the body turns grey (StoneLook), on every peer from the replicated bit.
## The end (updatePetrification, 23732-23764): the stun cooldown is cleared and damageStun knocks it down with 4 s of
## cooldown (Stunned.knock); 32 rocks burst from its box.

## sacengine damageStunCooldownFrames = 4·updateFPS.
@export var knock_cooldown_ticks := 240
## The pose that holds while it lasts.
@export var clip_pose: ClipPosePlayer
@export var stone_look: StoneLook
## Knocked down when it ends. Optional: empty = it just stands up.
@export var stunned: Stunned
## Its body_height() puts the rocks at the middle of the body.
@export var visual: Node3D
## FxBus type of the rocks broadcast when it ends.
@export var rocks_fx := "petrify_rocks"

## Simulation ticks it has lived (counted in _physics_process, so a paused tree does not count).
var _elapsed := 0
var _lifetime := 0
## The physics frame it started on: that tick is not one of its updates, whatever the order of processing.
var _start_frame := -1


func _ready() -> void:
	set_physics_process(false)


## Server (or solo): sacengine petrify(obj, lifetime). True when it turned to stone.
func petrify(lifetime_ticks: int) -> bool:
	var body := _body()
	if body == null or lifetime_ticks <= 0 or not _body_allows(body):
		return false
	if _afflictions().cc_protected():
		print("  petrificar: %s protegido" % str(body.call("display_name")))
		return false
	if not _afflictions().admit(self):
		return false
	_elapsed = 0
	_lifetime = lifetime_ticks
	_start_frame = Engine.get_physics_frames()
	_afflictions().mark(self, true)
	set_physics_process(true)
	print("petrificado %s durante %d (cuadro %d)" % [str(body.call("display_name")), _lifetime, _start_frame])
	return true


## canBePetrified (state.d:189-197), with the port's names: not dead, not still summoned, not held by a doctor.
## Playing dead and Rockform may be petrified. A wizard (F138) only alive: dying, dead and every ghost stage say no.
func _body_allows(body: Node3D) -> bool:
	var unit := body as UnitBody
	if unit == null:
		return body.has_method("is_targetable") and bool(body.call("is_targetable"))
	return not unit.is_dead() and not unit.is_taken() and unit.mode != UnitBody.Mode.SUMMONING


## Server only: _physics_process is on from petrify() until it ends. updatePetrification (state.d:23758-23761):
## `if(frame++>=lifetime)` ends it on its update lifetime + 1.
func _physics_process(_delta: float) -> void:
	if not is_on():
		set_physics_process(false)
		return
	if Engine.get_physics_frames() == _start_frame:
		return
	_elapsed += 1
	if _elapsed > _lifetime:
		_end()


func _end() -> void:
	set_physics_process(false)
	var body := _body()
	_afflictions().mark(self, false)
	print("%s deja de ser piedra (cuadro %d)" % [str(body.call("display_name")), Engine.get_physics_frames()])
	if stunned:
		stunned.knock(knock_cooldown_ticks)
	_burst_rocks()


## removePetrification (state.d:23740-23753): the rocks fly at every end, the stun only when it can still be stunned.
func _burst_rocks() -> void:
	var body := _body()
	var height := float(visual.call("body_height")) if visual and visual.has_method("body_height") else 1.0
	FxBus.broadcast(rocks_fx, body.global_position + Vector3.UP * height * 0.5)


func _shown(on: bool) -> void:
	if clip_pose:
		clip_pose.frozen = on
	if stone_look:
		stone_look.stone = on
	if not on and is_physics_processing():
		## Ended from outside while the server still ran it (the body died, state.d:23759-23760): rocks, no stun.
		set_physics_process(false)
		_burst_rocks()
