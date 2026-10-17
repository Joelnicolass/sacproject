class_name Firewalking
extends Affliction

## F152 (RFC-030 030o-b): the Warmonger's Firewalk walk, sacengine updateFirewalk (state.d:25802-25846). Mode `firewalk`:
## not a target (141), not an obstacle (124, 135), takes no damage (8922), cannot be immobilized (193) and is invisible.
## The type says the first three (holds, hides); this state writes the position and draws the look.
##
## The walk (numFrames 60, animatedDistance 20): each tick the position is written from start to end, the body's
## velocity is 0 (steer). start and end take the land's height. Distance d = 3D start→end:
##   d <= animated_distance: a straight line, p = frame/frames;
##   else p <= 0.5: from start to start + animated_distance/2 · dir (2p); p > 0.5: from end − animated_distance/2 · dir
##   to end (2(p − 0.5)). The jump between the halves is announced to the clients (WarpSnap).
## At the last frame the body is at `end` and the state ends (sacengine startIdling). Whether `end` is land is decided
## by Firewalk before it starts (isOnGround), so the final catapult (25838-25840) never happens here.
## Look: Tilt (the mesh) hidden while it lasts and a `fire` trail at the body (every peer, from the replicated bit; the
## position is replicated). Declared: the health bar stays visible and the capsule stays on the units' layer.

## Bench log (`ai_match` turns it on; off in the product).
static var log_walk := false

## sacengine Firewalk.numFrames.
@export var frames := 60
## sacengine Firewalk.animatedDistance (m).
@export var animated_distance := 20.0
## A step longer than this (m) is a jump: the clients are told not to glide it.
@export var snap_step := 2.0
@export var snap: WarpSnap
## The mesh pivot that is hidden while it lasts.
@export var tilt: Node3D
## FxBus type of the trail (sacengine placeFirewalkParticles) and the height above the feet it is placed at (m).
@export var trail_fx := "firewalk_trail"
@export var trail_lift := 0.8
## sacengine places 6 flames every tick; the type's 14 every 2 ticks is the same density with a quarter of the emitters.
@export var trail_every_ticks := 2
## FxBus type of the burst at the start and at the end (sacengine animateFirewalk: 32 flames in the body's box).
@export var burst_fx := "firewalk_burst"

var _start := Vector3.ZERO
var _end := Vector3.ZERO
var _frame := 0
## Server: the walk this node started is on.
var _running := false


static func of(body: Node) -> Firewalking:
	return (body.get_node_or_null("Afflictions/Firewalking") as Firewalking) if body else null


func _ready() -> void:
	set_physics_process(false)


## Server (or solo): sacengine firewalk's Firewalk effect. True when the walk started (it ends a UsingAbility).
func walk(end: Vector3) -> bool:
	var body := _body()
	if body == null or frames <= 0 or is_on() or not _afflictions().admit(self):
		return false
	_start = body.global_position
	_end = end
	_frame = 0
	_running = true
	_afflictions().mark(self, true)
	set_physics_process(true)
	if log_walk:
		print("firewalk %s inicio de (%.3f, %.3f, %.3f) a (%.3f, %.3f, %.3f) d %.2f m (tick %d)" % [
			str(body.name), _start.x, _start.y, _start.z, end.x, end.y, end.z, _start.distance_to(end), MatchClock.now()])
	return true


## The body's position at `frame` (1..frames) of the walk from start to end. Pure: the land's height at each point.
func position_at(frame: int) -> Vector3:
	var body := _body()
	var start := Vector3(_start.x, BodyNudge.ground_y(body, _start), _start.z)
	var end := Vector3(_end.x, BodyNudge.ground_y(body, _end), _end.z)
	if frame >= frames:
		return end
	var direction := end - start
	var distance := direction.length()
	if distance != 0.0:
		direction /= distance
	var progress := float(frame) / float(frames)
	var at := end
	if distance <= animated_distance:
		at = start.lerp(end, progress)
	elif progress <= 0.5:
		var midpoint := start + 0.5 * animated_distance * direction
		at = start.lerp(midpoint, 2.0 * progress)
	else:
		var midpoint := end - 0.5 * animated_distance * direction
		at = midpoint.lerp(end, 2.0 * (progress - 0.5))
	at.y = BodyNudge.ground_y(body, at)
	return at


## Server, every tick while it is on (Afflictions.steer): writes the position of this frame; the velocity is 0.
func steer(_velocity: Vector3, _delta: float) -> Vector3:
	var body := _body()
	if body == null or not _running or _frame >= frames:
		return Vector3.ZERO
	_frame += 1
	var at := position_at(_frame)
	var jump := body.global_position.distance_to(at)
	body.global_position = at
	if snap and jump > snap_step:
		snap.announce()
	if log_walk:
		print("firewalk %s cuadro %d (%.3f, %.3f, %.3f) (tick %d)" % [str(body.name), _frame, at.x, at.y, at.z, MatchClock.now()])
	if log_walk and _frame == frames / 2 and body.has_method("is_targetable"):
		print("firewalk %s oculto: is_targetable %s is_obstacle %s (tick %d)" % [
			str(body.name), body.call("is_targetable"), body.call("is_obstacle"), MatchClock.now()])
	return Vector3.ZERO


## Every peer while it is on: the trail. The server also ends the walk once the last frame was written (a child runs
## after its body, so the body already moved this tick).
func _physics_process(_delta: float) -> void:
	if not is_on():
		set_physics_process(false)
		return
	var body := _body()
	if body and trail_every_ticks > 0 and MatchClock.now() % trail_every_ticks == 0:
		FxBus.play(trail_fx, body.global_position + Vector3.UP * trail_lift)
	if _simulates() and _running and _frame >= frames:
		_running = false
		_afflictions().mark(self, false)
		if log_walk and body:
			print("firewalk %s fin (tick %d)" % [str(body.name), MatchClock.now()])


func _shown(on: bool) -> void:
	var body := _body()
	if body and burst_fx != "":
		FxBus.play(burst_fx, body.global_position + Vector3.UP * trail_lift)
	if tilt:
		tilt.visible = not on
	set_physics_process(on)
	if not on:
		_running = false
