class_name Firewalking
extends Affliction

## The Warmonger's Firewalk walk. Mode `firewalk`:
## not a target, not an obstacle, takes no damage, cannot be immobilized and is invisible.
## The type says the first three (holds, hides); this state writes the position and draws the look.
##
## The walk (numFrames 60, animatedDistance 20): each tick the position is written from start to end, the body's
## velocity is 0 (steer). start and end take the land's height. Distance d = 3D start→end:
##   d <= animated_distance: a straight line, p = frame/frames;
##   else p <= 0.5: from start to start + animated_distance/2 · dir (2p); p > 0.5: from end − animated_distance/2 · dir
##   to end (2(p − 0.5)). The jump between the halves is announced to the clients (WarpSnap).
## At the last frame the body is at `end` and the state ends. Whether `end` is land is decided
## by Firewalk before it starts, so the final catapult never happens here.
## Look: Tilt (the mesh) hidden while it lasts and a `fire` trail at the body (every peer, from the replicated bit; the
## position is replicated). The health bar stays visible and the capsule stays on the units' layer.


## How long the walk lasts.
@export_range(0.0166, 10.0, 0.0001, "suffix:s") var walk_s := 1.0
## The distance (m) under which the walk is a straight line.
@export var animated_distance := 20.0
## A step longer than this (m) is a jump: the clients are told not to glide it.
@export var snap_step := 2.0
@export var snap: WarpSnap
## walk_s in ticks: the frames of the walk.
var frames: int:
	get: return MatchClock.ticks_for(walk_s)
## The mesh pivot that is hidden while it lasts.
@export var tilt: Node3D
## The trail of flames puffed while it walks, and the socket it leaves from: the muzzle, where the Warmonger's flame is.
@export var trail_fx: ParticleType = preload("res://data/fx/firewalk_trail.tres")
@export var trail_socket: BodyFacts.Socket = BodyFacts.Socket.MUZZLE
## How often a trail flame is placed. The type's 14 every 2 ticks give 6 flames per tick with a quarter of the emitters.
@export_range(0.0, 1.0, 0.0001, "suffix:s") var trail_every_s := 0.0333
## The burst at the start and at the end (32 flames in the body's box), and its socket.
@export var burst_fx: ParticleType = preload("res://data/fx/firewalk_burst.tres")
@export var burst_socket: BodyFacts.Socket = BodyFacts.Socket.CENTER

var _start := Vector3.ZERO
var _end := Vector3.ZERO
var _frame := 0
## Server: the walk this node started is on.
var _running := false


static func of(body: Node) -> Firewalking:
	return (body.get_node_or_null("Afflictions/Firewalking") as Firewalking) if body else null


func _ready() -> void:
	set_physics_process(false)


## Server (or solo): starts the Firewalk effect. True when the walk started (it ends a UsingAbility).
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
	if DebugLog.on(&"walk"):
		print("firewalk %s start from (%.3f, %.3f, %.3f) to (%.3f, %.3f, %.3f) d %.2f m (tick %d)" % [
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
	if DebugLog.on(&"walk"):
		print("firewalk %s frame %d (%.3f, %.3f, %.3f) (tick %d)" % [str(body.name), _frame, at.x, at.y, at.z, MatchClock.now()])
	if DebugLog.on(&"walk") and _frame == frames / 2 and body is UnitBody:
		print("firewalk %s oculto: is_targetable %s is_obstacle %s (tick %d)" % [
			str(body.name), (body as UnitBody).is_targetable(), (body as UnitBody).is_obstacle(), MatchClock.now()])
	return Vector3.ZERO


## Every peer while it is on: the trail. The server also ends the walk once the last frame was written (a child runs
## after its body, so the body already moved this tick).
func _physics_process(_delta: float) -> void:
	if not is_on():
		set_physics_process(false)
		return
	var body := _body()
	var every := MatchClock.ticks_for(trail_every_s)
	if body and trail_fx != null and every > 0 and MatchClock.now() % every == 0:
		FxBus.puff(trail_fx, BodyFacts.point(body, trail_socket))
	if is_multiplayer_authority() and _running and _frame >= frames:
		_running = false
		_afflictions().mark(self, false)
		if DebugLog.on(&"walk") and body:
			print("firewalk %s end (tick %d)" % [str(body.name), MatchClock.now()])


func _shown(on: bool) -> void:
	var body := _body()
	if body and burst_fx != null:
		FxBus.play(burst_fx, BodyFacts.point(body, burst_socket))
	if tilt:
		tilt.visible = not on
	set_physics_process(on)
	if not on:
		_running = false
