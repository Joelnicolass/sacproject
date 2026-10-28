class_name Tumbling
extends Affliction

## A body thrown through the air. The Vortick's vortex
## and the Flurry's implosion throw it; Squall's Pushback adds to a body already thrown.
## The throw refuses a flier in the air (it hangs, or falls with petrify) and a body that cannot be thrown (dead,
## landing, being summoned, held by a doctor); the mode becomes stunned, so it ends a stun (the type's `cancels`).
##
## While it lasts (the type holds the body) this state gives the body its velocity (steer): on the
## ground and going down, vz = 0; else vz −= falling acceleration/60 unless an effect lifted it this tick;
## then vxy ×0.99 and vz ×0.998 per tick. It lands when vz ≤ 0 and pos + vz/60 is under the ground,
## or when it rests on a building or another body (is_on_floor after move_and_slide):
## fall damage max(0, −vz − 3)·20 with no resistance and it lies hit_floor +
## get_up (Stunned.fall_down; the stun cooldown is not touched).
## A hybrid flier leaves the tumble at the top of its arc but
## does not take off again; it comes down with the body's own gravity.
## Look: Tilt rolls while it flies (Tween), as Stunned does; the mesh clips tumble/falling/hit_floor are not exported.
## WORKAROUND: Tween on Tilt rotation:z in place of the tumble mesh clip (disk, same as Stunned).

## A body within this of the ground stands on it (the capsule rests a hair above the land).
const REST_M := 0.02

## Falling acceleration, m/s².
@export var falling_acceleration := 9.81
## Horizontal and vertical damping per tick at 60 fps.
@export var damp_xz := 0.99
@export var damp_y := 0.998
## The speed under which a fall does no damage, and the damage per m/s over it.
@export var fall_damage_limit := 3.0
@export var fall_damage_factor := 20.0
## It lies here after it lands. Optional: empty = it stands up at once.
@export var stunned: Stunned
@export var tilt: Node3D
@export_group("Fallback look")
## How far it rolls while it flies (degrees, about Tilt's z).
@export_range(0.0, 180.0) var roll_deg := 60.0
@export var roll_s := 0.3

## The velocity of the fall, m/s (port axes: y up).
var velocity := Vector3.ZERO
## The slot that threw it (-1 nobody).
var attacker_slot := -1
var _lifted_tick := -1
var _from := Vector3.ZERO
var _from_ground := 0.0
var _apex := 0.0
var _ticks := 0
var _tween: Tween


func _ready() -> void:
	set_physics_process(false)


## Server (or solo): sets the fall velocity `v` of a body already thrown (the pull sets it each tick of its window).
func drive(v: Vector3) -> void:
	if is_on():
		velocity = v


## Server (or solo): throws the body with `velocity`. True when it is (now or already) thrown.
func catapult(push: Vector3, side: int) -> bool:
	var body := _body()
	if body == null or BodyNudge.fixed(body):
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
	print("tumble %s from (%.2f, %.2f, %.2f) ground %.2f v (%.3f, %.3f, %.3f) box (%.2f, %.2f, %.2f) center +%.2f (frame %d)" % [
		_body_name(), _from.x, _from.y, _from.z, _from_ground, push.x, push.y, push.z, box.size.x * 0.5,
		box.size.y * 0.5, box.size.z * 0.5, box.get_center().y - _from.y, MatchClock.now()])
	return true


## Server: adds `v` to the fall velocity of a thrown body (Pushback on a tumbling body).
func add_velocity(push: Vector3) -> void:
	velocity += push


## Server: the vortex holds it up this tick.
func lift() -> void:
	_lifted_tick = MatchClock.now()


## Server: moves a thrown body by `v` (the implosion). `clear_fall`: it was going
## down while this moves it up, so vz = 0.
func shift(offset: Vector3, clear_fall: bool) -> void:
	var body := _body()
	if body:
		body.global_position += offset
	if clear_fall and velocity.y < 0.0:
		velocity.y = 0.0


## Can it be thrown, in this game's terms: not in the air on its own, alive, not being
## summoned, not held or revived by a doctor, not landing. Rockform and playing dead may be thrown.
func _body_allows(body: Node3D) -> bool:
	if BodyNudge.airborne(body):
		return false
	var health := _afflictions().health
	if health and health.is_dead():
		return false
	var unit := body as UnitBody
	if unit == null:
		return GameBody.targetable(body)
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
		velocity.y -= falling_acceleration / MatchClock.TICKS_PER_SECOND_F
	velocity.x *= damp_xz
	velocity.z *= damp_xz
	velocity.y *= damp_y
	return velocity


## Server, after the body moved this tick (a child runs after its body): the top of the arc and the landing.
func _physics_process(_delta: float) -> void:
	if not is_on():
		set_physics_process(false)
		return
	if not is_multiplayer_authority():
		return
	var body := _body()
	var at := body.global_position
	_ticks += 1
	if at.y > _apex:
		_apex = at.y
	if velocity.y > 0.0:
		return
	if _hybrid(body):
		print("%s leaves the tumble at the apex %.2f m (frame %d)" % [_body_name(), _apex - _from_ground, MatchClock.now()])
		_afflictions().mark(self, false)
		return
	if BodyNudge.on_land(body, at) and at.y + velocity.y / MatchClock.TICKS_PER_SECOND_F <= BodyNudge.ground_y(body, at) + REST_M:
		_land(body, at, "ground")
	elif body is CharacterBody3D and (body as CharacterBody3D).is_on_floor():
		# It rests on a building or on another body,
		# not on the land: it lands there all the same.
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
	print("lands %s on %s at (%.2f, %.2f, %.2f) at %.2f m (dx %.2f, dz %.2f) after %d ticks, apex %.2f m, vz %.2f, fall %.1f (frame %d)" % [
		_body_name(), on, at.x, at.y, at.z, flat.length(), flat.x, flat.y, _ticks, _apex - _from_ground,
		velocity.y, damage, MatchClock.now()])
	velocity = Vector3.ZERO
	# Stunned first, so the body stays held through the hand-over (held_changed does not blink).
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
