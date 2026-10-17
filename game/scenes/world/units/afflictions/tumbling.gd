class_name Tumbling
extends Affliction

## F121 (RFC-030j): a body thrown through the air, sacengine catapult + CreatureMovement.tumbling. The Vortick's vortex
## and the Flurry's implosion throw (catapult, state.d:8579-8599); Squall's Pushback adds to a body already thrown.
## catapult refuses a flier in the air (it hangs, or falls with petrify) and a body that canCatapult says no to (dead,
## landing, being summoned, held by a doctor); the mode becomes stunned, so it ends a stun (the type's `cancels`).
##
## While it lasts (the type holds the body) this state gives the body its velocity (steer, state.d:14781-14797): on the
## ground and going down, vz = 0; else vz −= fallingAcceleration/60 unless an effect lifted it this tick
## (antiGravityTime); then vxy ×0.99 and vz ×0.998 per tick. It lands when vz ≤ 0 and pos + vz/60 is under the ground,
## or (REVIEW-F121 B1) when it rests on a building or another body (is_on_floor after move_and_slide)
## (14175-14197): fall damage max(0, −vz − 3)·20 with no resistance (dealFallDamage, 9429-9438) and it lies hitFloor +
## getUp (Stunned.fall_down; the stun cooldown is not touched).
## Deviation (declared): a hybrid flier leaves the tumble at the top of its arc (sacengine: it flies on, 14176-14181) but
## does not take off again; it comes down with the body's own gravity.
## Look: Tilt rolls while it flies (Tween), as Stunned does; the mesh clips tumble/falling/hitFloor are not exported.
## WORKAROUND: Tween on Tilt rotation:z in place of the tumble mesh clip (disk, same as RFC-030i-a).

const TICKS := float(MatchClock.TICKS_PER_SECOND)
## A body within this of the ground stands on it (the capsule rests a hair above the land).
const REST_M := 0.02

## sacengine CreatureStats.fallingAcceleration (stats.d:142-144), m/s².
@export var falling_acceleration := 9.81
## sacengine dampFactorXY / dampFactorZ per tick at 60 fps (state.d:14783-14784).
@export var damp_xz := 0.99
@export var damp_y := 0.998
## sacengine fallDamageLimit / fallDamageFactor (state.d:9430-9433).
@export var fall_damage_limit := 3.0
@export var fall_damage_factor := 20.0
## It lies here after it lands. Optional: empty = it stands up at once.
@export var stunned: Stunned
@export var tilt: Node3D
@export_group("Fallback look")
## How far it rolls while it flies (degrees, about Tilt's z).
@export_range(0.0, 180.0) var roll_deg := 60.0
@export var roll_s := 0.3

## sacengine fallingVelocity, m/s (port axes: y up).
var velocity := Vector3.ZERO
## sacengine tumbleAttackerSide: the slot that threw it (-1 nobody).
var attacker_slot := -1
var _lifted_tick := -1
var _from := Vector3.ZERO
var _from_ground := 0.0
var _apex := 0.0
var _ticks := 0
var _tween: Tween


func _ready() -> void:
	set_physics_process(false)


## Server (or solo): sacengine catapult(side, velocity). True when it is (now or already) thrown.
func catapult(push: Vector3, side: int) -> bool:
	var body := _body()
	if body == null:
		return false
	if is_on():
		velocity += push
		attacker_slot = side
		return true
	if not _body_allows(body) or not _afflictions().admit(self):
		return false
	velocity = push
	attacker_slot = side
	_from = body.global_position
	_from_ground = BodyNudge.ground_y(body, _from)
	_apex = _from.y
	_ticks = 0
	_afflictions().mark(self, true)
	set_physics_process(true)
	var box := BodyNudge.box(body)
	print("tumbo %s desde (%.2f, %.2f, %.2f) suelo %.2f v (%.3f, %.3f, %.3f) caja (%.2f, %.2f, %.2f) centro +%.2f (cuadro %d)" % [
		str(body.call("display_name")), _from.x, _from.y, _from.z, _from_ground, push.x, push.y, push.z, box.size.x * 0.5,
		box.size.y * 0.5, box.size.z * 0.5, box.get_center().y - _from.y, MatchClock.now()])
	return true


## Server: sacengine fallingVelocity += v of a thrown body (Pushback on a tumbling body, state.d:24024-24026).
func add_velocity(push: Vector3) -> void:
	velocity += push


## Server: the vortex holds it up this tick (sacengine antiGravityTime = frame, state.d:23955).
func lift() -> void:
	_lifted_tick = MatchClock.now()


## Server: sacengine `position += v` on a thrown body (the implosion, state.d:24663-24666). `clear_fall`: it was going
## down while this moves it up, so vz = 0 (sacengine's own «hack»).
func shift(offset: Vector3, clear_fall: bool) -> void:
	var body := _body()
	if body:
		body.global_position += offset
	if clear_fall and velocity.y < 0.0:
		velocity.y = 0.0


## canCatapult (state.d:250-255, 8579-8584), with the port's names: not in the air on its own, alive, not being
## summoned, not held or revived by a doctor, not landing. Rockform and playing dead may be thrown.
func _body_allows(body: Node3D) -> bool:
	if BodyNudge.airborne(body):
		return false
	var health := _afflictions().health
	if health and health.is_dead():
		return false
	var unit := body as UnitBody
	if unit == null:
		return not body.has_method("is_targetable") or bool(body.call("is_targetable"))
	var flight := unit.get_node_or_null("Flight") as Flight
	if flight and flight.state == Flight.State.LANDING:
		return false
	return unit.mode != UnitBody.Mode.SUMMONING and not unit.is_taken()


func steer(_velocity: Vector3, _delta: float) -> Vector3:
	var body := _body()
	var at := body.global_position
	if BodyNudge.on_land(body, at) and at.y <= BodyNudge.ground_y(body, at) + REST_M:
		if velocity.y < 0.0:
			velocity.y = 0.0
	elif _lifted_tick < MatchClock.now():
		velocity.y -= falling_acceleration / TICKS
	velocity.x *= damp_xz
	velocity.z *= damp_xz
	velocity.y *= damp_y
	return velocity


## Server, after the body moved this tick (a child runs after its body): the top of the arc and the landing.
func _physics_process(_delta: float) -> void:
	if not is_on():
		set_physics_process(false)
		return
	if not _simulates():
		return
	var body := _body()
	var at := body.global_position
	_ticks += 1
	if at.y > _apex:
		_apex = at.y
	if velocity.y > 0.0:
		return
	if _hybrid(body):
		print("%s deja el tumbo en el ápice %.2f m (cuadro %d)" % [str(body.call("display_name")), _apex - _from_ground, MatchClock.now()])
		_afflictions().mark(self, false)
		return
	if BodyNudge.on_land(body, at) and at.y + velocity.y / TICKS <= BodyNudge.ground_y(body, at) + REST_M:
		_land(body, at, "suelo")
	elif body is CharacterBody3D and (body as CharacterBody3D).is_on_floor():
		## REVIEW-F121 B1: it rests on a building or on another body (sacengine positionAfterCollision stops it on top,
		## state.d:14446-14564), not on the land: it lands there all the same.
		_land(body, at, _floor_name(body as CharacterBody3D))


## What the body stands on after move_and_slide (the first floor contact), for the log.
static func _floor_name(body: CharacterBody3D) -> String:
	for i in body.get_slide_collision_count():
		var hit := body.get_slide_collision(i)
		if hit.get_normal().angle_to(body.up_direction) <= body.floor_max_angle + 0.01:
			var other := hit.get_collider() as Node
			return str(other.name) if other else "?"
	return "?"


func _land(body: Node3D, at: Vector3, on: String) -> void:
	var damage := maxf(0.0, -velocity.y - fall_damage_limit) * fall_damage_factor
	var flat := Vector2(at.x - _from.x, at.z - _from.z)
	print("aterriza %s sobre %s en (%.2f, %.2f, %.2f) a %.2f m (dx %.2f, dz %.2f) tras %d ticks, ápice %.2f m, vz %.2f, caída %.1f (cuadro %d)" % [
		str(body.call("display_name")), on, at.x, at.y, at.z, flat.length(), flat.x, flat.y, _ticks, _apex - _from_ground,
		velocity.y, damage, MatchClock.now()])
	velocity = Vector3.ZERO
	## Stunned first, so the body stays held through the hand-over (held_changed does not blink).
	if stunned:
		stunned.fall_down()
	_afflictions().mark(self, false)
	var health := _afflictions().health
	if damage > 0.0 and health:
		health.damage(damage, 0)


static func _hybrid(body: Node3D) -> bool:
	var type := body.get("type") as CreatureType
	return type != null and type.is_hybrid_flier()


func _shown(on: bool) -> void:
	if _tween:
		_tween.kill()
		_tween = null
	if tilt == null:
		return
	if on:
		_tween = tilt.create_tween()
		_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		_tween.tween_property(tilt, "rotation:z", deg_to_rad(roll_deg), roll_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	elif stunned == null or not stunned.is_on():
		_tween = tilt.create_tween()
		_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		_tween.tween_property(tilt, "rotation:z", 0.0, roll_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
