class_name Pulling
extends Affliction

## F128 (RFC-030 030q-a): the user of Web pull and Cage pull while it pulls, sacengine mode `pulling` (startPulling,
## state.d:10108-10113) and the Pull effect that runs beside it (updatePull, 25434-25519). The one owner of the simulation
## of the pull: the thread, the pulls, the 25-tick window, the extra pull and the end. Pull (the AbilityEffect) only judges
## the target and calls start(); the target's own states (Stunned, Tumbling) keep what they own and are asked by their API.
##
## One update per tick from the tick after start() (sacengine frame 1, 2, …), before the bodies move (process priority −1,
## like the other effects): nothing is checked while the first 20 ticks last (numShootFrames). Then, each tick:
##   1. the user must still be pulling and the target a valid body (isValidAttackTarget); at a pull tick the target must
##      still be applicable to the ability (checkAbility; range, mana and cooldown do not count for a ranged ability);
##   2. thread = target center − (user center + 0.5 · forward); velocity = −pull_speed · thread/|thread|;
##   3. it ends when it already pulled once, the target's box is within `min_thread` of the user's center and the window ran
##      out or the thread does not go below −0.5 · min_thread (a pulled body that is not far under the user);
##   4. a tumbling target that goes away (farther than 1.05 · the smallest radius so far and moving along the thread
##      faster than 1.5, or backwards faster than 0.2 of its climb) is pulled at once (the extra pull);
##   5. at a pull tick (the clip's last frame, every `loop_ticks`, or the extra pull): numPulls += 1,
##      velocity.y += 5 · fallingAcceleration / 60, Stunned.stun_with_cooldown(stun_ticks) (only the first one stuns: the
##      cooldown runs), Tumbling.catapult(velocity), window = pull_ticks. Else, for the next pull_ticks − 1 ticks: a
##      tumbling target takes `velocity` (Tumbling.drive), one on the ground is pushed by velocity / 60 (BodyNudge.push);
##   6. with max_pulls pulls done it ends at the last tick of the clip loop (frame + 1 >= numFrames · 2).
## Ending (a thread cut, the target gone, the user stunned or dead…) always goes through _finish(): the break FX at the
## target, the bit off, and the user is free again (idle, as startIdling).
##
## The thread (hilo) is a presentation scene (Pull.thread_scene) played on every peer by FxBus.broadcast_scene once; it
## follows the two bodies by itself while this state's bit is on.
##
## Divergences (declared): a structure or a soul on the way does not become the target (sacengine's ray would stop there and
## the pull would end at frame 20); the user does not walk closer or turn to the target; the web / cage around the target is
## not drawn; the user keeps its idle pose (no shoot clip while it pulls).
##
## Server (or solo) only: the clients get the bit and the positions. The user's own velocity is 0 while it lasts (steer).


## sacengine Pull.numShootFrames: no check while the thread flies out.
const SHOOT_FRAMES := 20
## unit_orders.gd has no class_name (other scripts preload it).
const _ORDERS := preload("res://scenes/units/unit_orders.gd")
## sacengine updatePull: the extra pull (25462-25481) and the lift of every pull (25485).
const OUTWARD_RADIUS_FACTOR := 1.05
const OUTWARD_SPEED := 1.5
const BACKWARD_FACTOR := 0.2
const LIFT_FACTOR := 5.0

var _effect: Pull
var _target: Node3D
var _fired := 0
## MatchClock tick at which the user's clip began (the order): its frame is (now − _clip_origin) mod _loop.
var _clip_origin := 0
var _loop := 1
var _next_pull := 0
var _pulls := 0
var _window := 0
var _radius := INF
var _running := false


static func of(body: Node) -> Pulling:
	return (body.get_node_or_null("Afflictions/Pulling") as Pulling) if body else null


func _ready() -> void:
	set_physics_process(false)
	## sacengine updates its effects before its creatures: the pull sets the target's velocity before the target steps.
	process_physics_priority = -1


## Server (or solo): sacengine startPulling + the Pull effect. `loop_ticks`: the user's clip loop (frames · 2). `pull_frame`:
## the tick of the clip (counted from the order) at which it pulls, its last frame ((frames − 1) · 2). The first pull falls
## at the fire tick − effect.windup() + pull_frame. True when it started (it ends a UsingAbility, the type's `cancels`).
func start(target: Node3D, effect: Pull, loop_ticks: int, pull_frame: int) -> bool:
	var body := _body()
	if not _simulates() or body == null or effect == null or target == null or loop_ticks <= 0 or is_on():
		return false
	if not _afflictions().admit(self):
		return false
	_target = target
	_effect = effect
	_fired = MatchClock.now()
	_loop = loop_ticks
	_clip_origin = _fired - effect.windup()
	_next_pull = _clip_origin + pull_frame
	_pulls = 0
	_window = 0
	_radius = INF
	_running = true
	var orders := body.get_node_or_null("Orders") as _ORDERS
	if orders:
		orders.clear()
	_afflictions().mark(self, true)
	set_physics_process(true)
	_throw_thread(body)
	if DebugLog.on(&"pull"):
		print("tirón %s → %s inicio blanco a %.3f m (tick %d)" % [
			AbilityEffect.who(body), AbilityEffect.who(target), body.global_position.distance_to(target.global_position), _fired])
	return true


## The user does not move while it pulls (sacengine: mode pulling has no movement).
func steer(_velocity: Vector3, _delta: float) -> Vector3:
	return Vector3.ZERO


func _shown(on: bool) -> void:
	set_physics_process(on and _simulates())
	if not on and _running and _simulates():
		_finish("cortado")


func _physics_process(_delta: float) -> void:
	if not _running or not _simulates():
		return
	var body := _body()
	var now := MatchClock.now()
	if now - _fired < SHOOT_FRAMES:
		return
	if body == null or not is_on():
		_finish("cortado")
		return
	if not Pull.is_live(_target):
		_finish("blanco inválido")
		return
	var pull_now := false
	while now >= _next_pull:
		pull_now = pull_now or now == _next_pull
		_next_pull += _loop
	if pull_now and not _effect.applicable(_target):
		_finish("blanco no aplicable")
		return
	var forward := _forward(body)
	var user_center := BodyNudge.center(body)
	var target_center := BodyNudge.center(_target)
	var thread := target_center - (user_center + 0.5 * forward)
	var direction := thread.normalized()
	var velocity := -_effect.pull_speed * direction
	var box := box_distance(BodyNudge.box(_target), user_center)
	var checked_window := _window
	if _pulls >= 1 and box < _effect.min_thread and (checked_window <= 0 or thread.y >= -0.5 * _effect.min_thread):
		_finish("cerca", box, thread.y)
		return
	var tumbling := BodyNudge.tumbling_of(_target)
	var flying := tumbling != null and tumbling.is_on()
	if flying:
		if thread.length() > OUTWARD_RADIUS_FACTOR * _radius and direction.dot(tumbling.velocity) > OUTWARD_SPEED:
			pull_now = true
		var forward_dist := forward.dot(thread)
		if forward_dist < -BACKWARD_FACTOR * thread.y:
			if (-forward).dot(tumbling.velocity) > BACKWARD_FACTOR * tumbling.velocity.y:
				pull_now = true
	_radius = minf(_radius, (target_center - user_center).length())
	var action := "nada"
	if pull_now:
		_pulls += 1
		velocity.y += LIFT_FACTOR * _fall_acceleration(tumbling) / MatchClock.TICKS_PER_SECOND_F
		var stunned := _stun()
		if tumbling != null:
			tumbling.catapult(velocity, int(body.get("owner_slot")) if "owner_slot" in body else 0)
		_window = _effect.pull_ticks
		action = "tirón"
		if DebugLog.on(&"pull"):
			print("tirón %d %s → %s v (%.4f, %.4f, %.4f) hilo (%.4f, %.4f, %.4f) aturde %s (tick %d)" % [
				_pulls, AbilityEffect.who(body), AbilityEffect.who(_target), velocity.x, velocity.y, velocity.z,
				thread.x, thread.y, thread.z, "sí" if stunned else "no", now])
	else:
		_window -= 1
		if _window > 0:
			if flying:
				tumbling.drive(velocity)
			else:
				BodyNudge.push(_target, velocity)
			action = "ventana"
	if DebugLog.on(&"pull") and _pulls >= 1:
		print("paso %s → %s centro (%.3f, %.3f, %.3f) hilo y %.4f caja %.4f ventana %d accion %s (tick %d)" % [
			AbilityEffect.who(body), AbilityEffect.who(_target), target_center.x, target_center.y, target_center.z,
			thread.y, box, checked_window, action, now])
	if _pulls >= _effect.max_pulls and (now - _clip_origin) % _loop + 1 >= _loop:
		_finish("4 tirones", box, thread.y)


## The one way out: the break FX at the target, the bit off, one line in the log. Idempotent.
func _finish(reason: String, box := NAN, thread_y := 0.0) -> void:
	if not _running:
		return
	_running = false
	var body := _body()
	var target := _target
	var effect := _effect
	var live := Pull.is_live(target)
	var center := BodyNudge.center(target) if live else Vector3.ZERO
	if is_nan(box):
		box = box_distance(BodyNudge.box(target), BodyNudge.center(body)) if live and body != null else NAN
	if live and effect != null and not effect.break_fx.is_empty():
		FxBus.broadcast(effect.break_fx, center)
	if is_on():
		_afflictions().mark(self, false)
	set_physics_process(false)
	if DebugLog.on(&"pull"):
		print("tirón fin %s → %s por %s tirones %d caja %.4f hilo y %.4f ventana %d bit %d centro (%.3f, %.3f, %.3f) (tick %d)" % [
			AbilityEffect.who(body), AbilityEffect.who(target) if target != null and is_instance_valid(target) else "?", reason,
			_pulls, box, thread_y, _window, 1 if is_on() else 0, center.x, center.y, center.z, MatchClock.now()])
	_target = null
	_effect = null


## Presentation: the thread, once, on every peer. It follows the bodies and ends with this state's bit.
func _throw_thread(body: Node3D) -> void:
	var scene := _effect.thread_scene
	if scene == null or scene.resource_path.is_empty() or not body.is_inside_tree() or not _target.is_inside_tree():
		return
	FxBus.broadcast_scene(scene.resource_path, body.global_position, {
		"user": str(body.get_path()), "target": str(_target.get_path()),
		"seed": MatchSeed.derive(["pull_thread", str(body.name), _fired]), "grow_ticks": SHOOT_FRAMES,
	})


func _stun() -> bool:
	var stunned := _target.get_node_or_null("Afflictions/Stunned") as Stunned
	return stunned != null and stunned.stun_with_cooldown(_effect.stun_ticks)


## The target's fallingAcceleration (CreatureStats): its Tumbling's, else the default of a creature.
static func _fall_acceleration(tumbling: Tumbling) -> float:
	return tumbling.falling_acceleration if tumbling != null else 9.81


static func _forward(body: Node3D) -> Vector3:
	if body.has_method("facing_flat"):  # dynamic: unit, wizard and doctor bodies all face
		return body.call("facing_flat")
	var flat := -body.global_basis.z
	flat.y = 0.0
	return flat.normalized()


## sacengine boxPointDistance: from `point` to the nearest point of the box (0 inside it).
static func box_distance(box: AABB, point: Vector3) -> float:
	var low := box.position
	var high := box.end
	var nearest := Vector3(clampf(point.x, low.x, high.x), clampf(point.y, low.y, high.y), clampf(point.z, low.z, high.z))
	return point.distance_to(nearest)
