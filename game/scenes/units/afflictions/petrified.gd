class_name Petrified
extends Affliction

## A creature turned to stone. Petrifying refuses a ccProtected body (a petrified one
## among them) and one that cannot be immobilized (dying, dead, reviving…); a stunned body
## is petrified all the same (the type's `cancels`). While it lasts the type's flags say the rest: held, not pushed,
## a flier falls, every hit ×0.2, refuses crowd control. The pose and the grey belong to
## Afflictions (its clip_pose and look, from the type's look_tint: one owner for petrified and frozen).
## The end: the stun cooldown is cleared and the stun knocks it down with 4 s of
## cooldown (Stunned.knock); 32 rocks burst from its box.
## Ref: F137 (RFC-030i-b), F149; sacengine petrified, petrify state.d:11631-11645, stats.d:89, state.d:189-197, startTumbling, 8965, updatePetrification 23732-23764, damageStun.

## How long the body cannot be stunned again after it is knocked down.
## Ref: sacengine damageStunCooldownFrames = 4·updateFPS.
@export_range(0.0, 60.0, 0.0001, "suffix:s") var knock_cooldown_s := 4.0
## Knocked down when it ends. Optional: empty = it just stands up.
@export var stunned: Stunned
## The rocks broadcast when it ends, and the socket of the body they leave from.
@export var rocks_fx: ParticleType = preload("res://data/fx/petrify_rocks.tres")
@export var rocks_socket: BodyFacts.Socket = BodyFacts.Socket.CENTER

## Simulation ticks it has lived (counted in _physics_process, so a paused tree does not count).
var _elapsed := 0
var _lifetime := 0
## The physics frame it started on: that tick is not one of its updates, whatever the order of processing.
var _start_frame := -1


func _ready() -> void:
	set_physics_process(false)


## Server (or solo): turns the body to stone for `lifetime`. True when it turned to stone.
## Ref: sacengine petrify(obj, lifetime).
func petrify(lifetime_ticks: int) -> bool:
	var body := _body()
	if body == null or lifetime_ticks <= 0 or not can_be_immobilized(body):
		return false
	if _afflictions().cc_protected():
		print("  petrificar: %s protegido" % _body_name())
		return false
	if not _afflictions().admit(self):
		return false
	_elapsed = 0
	_lifetime = lifetime_ticks
	_start_frame = MatchClock.now()
	_afflictions().mark(self, true)
	set_physics_process(true)
	print("petrificado %s durante %d (cuadro %d)" % [_body_name(), _lifetime, _start_frame])
	return true


## Can it be immobilized (the same answer as petrified and frozen), with the port's names: not dead, not still
## summoned, not held by a doctor. Playing dead and Rockform may be petrified. A wizard only alive: dying, dead
## and every ghost stage say no. Frozen asks here too.
## Ref: canBeImmobilized = canBePetrified = canBeFrozen (state.d:189-198); F138, F149.
static func can_be_immobilized(body: Node3D) -> bool:
	var unit := body as UnitBody
	if unit == null:
		return body.has_method("is_targetable") and bool(body.call("is_targetable"))  # dynamic: a wizard (or another body) answers it
	return not unit.is_dead() and not unit.is_taken() and unit.mode != UnitBody.Mode.SUMMONING


## Server only: _physics_process is on from petrify() until it ends. `if(frame++>=lifetime)` ends it on its
## update lifetime + 1.
## Ref: updatePetrification (state.d:23758-23761).
func _physics_process(_delta: float) -> void:
	if not is_on():
		set_physics_process(false)
		return
	if MatchClock.now() == _start_frame:
		return
	_elapsed += 1
	if _elapsed > _lifetime:
		_end()


func _end() -> void:
	set_physics_process(false)
	var body := _body()
	_afflictions().mark(self, false)
	print("%s deja de ser piedra (cuadro %d)" % [_body_name(), MatchClock.now()])
	if stunned:
		stunned.knock(MatchClock.ticks_for(knock_cooldown_s))
	_burst_rocks()


## The rocks fly at every end, the stun only when it can still be stunned.
## Ref: removePetrification (state.d:23740-23753).
func _burst_rocks() -> void:
	var body := _body()
	if rocks_fx != null:
		FxBus.broadcast(rocks_fx, BodyFacts.point(body, rocks_socket))


func _shown(on: bool) -> void:
	if not on and is_physics_processing():
		## Ended from outside while the server still ran it (the body died): rocks, no stun.
		## Ref: state.d:23759-23760.
		set_physics_process(false)
		_burst_rocks()
