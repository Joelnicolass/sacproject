class_name Implosion
extends Node3D

## The Flurry's implosion that draws bodies in.
## ImplosionImpact puts it in the shots' container where the shot burst; server (or solo) only. Its scale
## starts at effectRange and shrinks at effectRange/duration per second; it ends when it reaches 0. Every tick, every
## live creature and wizard whose box meets the cube ±scale and whose center is within effectRange of the burst (no
## side filter) is drawn in:
##   speed = √(max(10, d)·max(10, scale)) / effectRange · influence_speed / 60  (meters this tick, toward the center)
## - not thrown: the step speed·direction; if it ends at most influence_speed/120 over the ground it slides
##   (BodyNudge.slide, on the land only), else it is thrown with 2·speed·direction (vz ≥ −1/60) as its velocity;
## - thrown: position += 2·speed·direction, and a body going down that this lifts has vz = 0 (the original's «hack»).
## The original's axes (x, y, z up) are the port's (x, z, y up). Effects run before creatures: priority −1.
## Ref: F121 (RFC-030j); sacengine FlurryImplosion (state.d:4868-4876, updateFlurryImplosion 24619-24672), state.d:29331.

## How fast bodies are drawn in.
## Ref: sacengine FlurryImplosion.influenceSpeed.
@export var influence_speed := 15.0
## The SPEL's effectRange and duration (caba: 20 m, 1,5 s); the impact writes them.
@export var effect_range := 20.0
@export var duration_s := 1.5

var side := -1
var _scale := 0.0
var _started := false
## Per body: where it was when the implosion first touched it (log of the pull).
var _first := {}


func _physics_process(_delta: float) -> void:
	var ticks := float(MatchClock.TICKS_PER_SECOND)
	if not _started:
		_started = true
		_scale = effect_range
	_scale -= effect_range / maxf(duration_s, 0.001) / ticks
	if _scale <= 0.0:
		_report()
		set_physics_process(false)
		queue_free()
		return
	var area := AABB(global_position - Vector3.ONE * _scale, Vector3.ONE * 2.0 * _scale)
	for body in BodyNudge.bodies_in(get_tree(), area):
		_influence(body, ticks)


func _influence(body: Node3D, ticks: float) -> void:
	var to_center := global_position - BodyNudge.center(body)
	var distance := to_center.length()
	if distance > effect_range or distance <= 0.0:
		return
	if not _first.has(body):
		_first[body] = body.global_position
		print("implosión toca %s en (%.2f, %.2f, %.2f) suelo %.2f centro +%.2f escala %.2f" % [GameBody.name_of(body), body.global_position.x,
			body.global_position.y, body.global_position.z, BodyNudge.ground_y(body, body.global_position),
			BodyNudge.center(body).y - body.global_position.y, _scale])
	var direction := to_center / distance
	var speed := sqrt(maxf(10.0, distance) * maxf(10.0, _scale)) / effect_range * influence_speed / ticks
	var thrown := 2.0 * speed * direction
	thrown.y = maxf(-1.0 / ticks, thrown.y)
	var tumbling := BodyNudge.tumbling_of(body)
	if tumbling == null or not tumbling.is_on():
		var step := speed * direction
		var at := body.global_position + step
		if at.y - BodyNudge.floor_y(body, at) <= influence_speed / (2.0 * ticks):
			BodyNudge.slide(body, step)
		elif tumbling:
			tumbling.catapult(thrown, side)
	if tumbling and tumbling.is_on():
		tumbling.shift(thrown, thrown.y > 0.0)


func _report() -> void:
	for body: Node3D in _first:
		if not is_instance_valid(body):
			continue
		var from: Vector3 = _first[body]
		var at := body.global_position
		var before := Vector2(global_position.x - from.x, global_position.z - from.z).length()
		var after := Vector2(global_position.x - at.x, global_position.z - at.z).length()
		print("implosión %s de %.2f m a %.2f m del centro (tirón %.2f m) (cuadro %d)" % [GameBody.name_of(body), before, after,
			before - after, MatchClock.now()])
