class_name MakeWay
extends RefCounted

## The crowd rules of BodySeparation.make_way (RFC-027 027d, F88; split out of BodySeparation in the F88 review round).
## A deviation of the port: sacengine positionAfterCollision only cuts the step of a body that walks into another.
## - Slide (creatures only, group «unit»; wizards, doctors and ghosts stop as in the original): a creature whose
##   first-pass cut leaves less than SLIDE_KEEP of its speed tries the detours DETOUR_DEG off its heading, first to the
##   side it slid to in the last HOLD_TICKS, else away from the bodies that cut it, and takes the first that keeps
##   SLIDE_KEEP of its speed.
## - Yield: a creature of the same slot that cut such a body and stands still with no order (UnitBody IDLE, `ordered`
##   off: not on guard nor holding the spot of an order; targetable: not playing dead nor hidden) steps aside, across
##   the walker's heading and away from its line, at YIELD_SPEED, until HOLD_TICKS after it was last asked (from its
##   next resolve on: the order of the bodies in the tick decides whether that is this tick or the next one). Of the
##   walkers that ask it in one tick, the closest sets the direction; a later tick's ask sets it again.
## - Return: a creature standing still with no order that made way, or that a walker of its slot pushed out of its spot,
##   walks back to where it stood RETURN_TICKS after the last of those (debug/crowd_cases.gd checks `off_slot`).
## - Soft between walkers: for a creature on its way (MOVE or CHASE) the creatures of its slot also on their way do not
##   cut the step (first pass, BodySeparation._separate); the second pass still pushes the two out of each other at up
##   to FIXUP_SPEED, so two that meet head-on press, turn the overlap sideways and pass instead of holding each other.
## Static state, like the box cache of BodySeparation: only the tables of the requests and of the sides. Every deadline
## (HOLD_TICKS, RETURN_TICKS) is a tick of the match (MatchClock.now(), RFC-032 032d): it does not run out in a pause.

## The fraction of its speed a cut step must keep along its own heading to count as free.
const SLIDE_KEEP := 0.5
## The detours tried, in degrees off the heading, in order (each to the preferred side, then to the other).
const DETOUR_DEG: Array[float] = [45.0, 90.0]
## m/s of the sidestep of a creature that makes way.
const YIELD_SPEED := 2.5
## Physics ticks a creature that made way waits, after its last request ran out, before it walks back home (the walker
## that asked has to get past first). F88 round 4: 60 → 20 and the walk back at the creature's own pace (see with_yield):
## with 60 and YIELD_SPEED, a creature shoved 2 m by a runner was still 2 m off a second after the runner left
## (debug/crowd_cases.gd, crowd_return).
const RETURN_TICKS := 20
## A creature that made way is back home this close (m).
const HOME_M := 0.15
## Physics ticks a request to make way, and the side of a slide, hold after they were last made.
const HOLD_TICKS := 20

## Requests: instance id of the creature asked to step aside -> [sidestep (flat, m/s), last tick it holds, tick it was
## asked, flat distance of the walker that set it]. A request holds
## HOLD_TICKS after the last time it was made, so the one asked gets clear instead of stepping back the next tick.
static var _asks: Dictionary = {}
## The side (+1 / -1 across the heading) a body last slid to -> [side, last tick]: kept HOLD_TICKS, so a body does not
## swing from one side of a blocker to the other every tick.
static var _sides: Dictionary = {}
## Where a creature stood still before it made way or was pushed out by a walker of its slot (instance id -> [flat
## position, last tick it was disturbed]): RETURN_TICKS after the last disturbance it walks back there at its own pace,
## so the formation it had arrived in is kept. Kept when it is back; dropped when it moves by itself.
static var _homes: Dictionary = {}
static var _pruned_tick := -1


## `velocity` of `body`, or the sidestep it was asked for if it was asked and still stands still (no velocity of its own).
static func with_yield(body: Node3D, velocity: Vector3, delta: float) -> Vector3:
	_prune()
	if _asks.is_empty() and _homes.is_empty():
		return velocity
	var id := body.get_instance_id()
	if velocity.x != 0.0 or velocity.z != 0.0:
		_homes.erase(id)
		return velocity
	var ask: Variant = _asks.get(id)
	if ask != null and int(ask[1]) >= MatchClock.now():
		var away: Vector2 = ask[0]
		velocity.x = away.x
		velocity.z = away.y
		return velocity
	if ask != null:
		_asks.erase(id)
	var home: Variant = _homes.get(id)
	if home == null or int(home[1]) + RETURN_TICKS >= MatchClock.now():
		return velocity
	var at := body.global_position
	var back: Vector2 = (home[0] as Vector2) - Vector2(at.x, at.z)
	var gap := back.length()
	## F88 round 5: back home, the spot is kept (not dropped) until the creature moves by itself. Dropped, the next push
	## from a neighbour standing still marked the spot it had been pushed to as its new home, a few cm on each tick, and a
	## creature crept off its place for good (debug/crowd_cases.gd crowd_return_grid).
	if gap <= HOME_M:
		return velocity
	back *= minf(maxf(YIELD_SPEED, _pace(body)), gap / delta) / gap
	velocity.x = back.x
	velocity.z = back.y
	return velocity


## The velocity (flat) of `body` that wanted `wanted` and was cut by `faces` (the first pass over the cut_* obstacles):
## asks the creatures that cut it to make way and returns the first detour that keeps SLIDE_KEEP of the speed, or the
## plain cut when none does.
static func slide(body: Node3D, at: Vector3, wanted: Vector2, faces: PackedInt32Array, inner: float, height: float,
		delta: float, cut_x: PackedFloat64Array, cut_y: PackedFloat64Array, cut_z: PackedFloat64Array,
		cut_halves: PackedFloat64Array, cut_heights: PackedFloat64Array, cut_nodes: Array[Node3D]) -> Vector2:
	var kept := BodySeparation.cut_step(wanted, faces)
	var speed := wanted.length()
	var heading := wanted / speed
	var across := Vector2(-heading.y, heading.x)
	var lateral := 0.0
	## F88 round 5: only a creature on its way asks others to make way. A creature walking back home (or stepping aside)
	## that asked its neighbours kept them, and they it, stepping aside and putting their return off for good in a dense
	## crowd (debug/crowd_cases.gd crowd_return_grid).
	var asks := walks(body)
	for i in faces.size():
		if BodySeparation.blocks(faces[i], wanted):
			lateral += (Vector2(cut_x[i], cut_z[i]) - Vector2(at.x, at.z)).dot(across)
			if asks:
				_ask_to_yield(body, cut_nodes[i], heading)
	var side := _slide_side(body, -1.0 if lateral > 0.0 else 1.0)
	for degrees in DETOUR_DEG:
		for turn: float in [side, -side]:
			var angle := deg_to_rad(degrees)
			var detour: Vector2 = (heading * cos(angle) + across * (turn * sin(angle))) * speed
			var detour_kept := BodySeparation.cut_step(detour, BodySeparation.first_pass_faces(at, detour, delta, inner,
					height, cut_x, cut_y, cut_z, cut_halves, cut_heights))
			if detour_kept.dot(detour) >= SLIDE_KEEP * speed * speed:
				_sides[body.get_instance_id()] = [turn, MatchClock.now() + HOLD_TICKS]
				return detour_kept
	return kept


## A creature on its way (UnitBody MOVE or CHASE).
static func walks(node: Node3D) -> bool:
	if not node.is_in_group(&"unit"):
		return false
	var mode := int(node.get("mode"))
	return mode == UnitBody.Mode.MOVE or mode == UnitBody.Mode.CHASE


## `body`, a creature standing still with no order, was pushed out of a creature of its slot this tick: it will walk
## back. Only a walker (`by_walker`) keeps it waiting; a push from one standing still (a neighbour shoved by a walker)
## only records where it stood, so two that push each other on the way back do not hold each other there.
static func pushed(body: Node3D, by_walker: bool) -> void:
	var id := body.get_instance_id()
	if by_walker:
		_mark_home(id, body.global_position, MatchClock.now())
	elif not _homes.has(id):
		_mark_home(id, body.global_position, -RETURN_TICKS - 1)


static func _mark_home(id: int, at: Vector3, disturbed: int) -> void:
	var home: Variant = _homes.get(id)
	if home == null:
		_homes[id] = [Vector2(at.x, at.z), disturbed]
	elif int(home[1]) < disturbed:
		home[1] = disturbed


## Copies of the tables, for a probe that calls resolve outside the tick (agent/perf/frame_budget.gd) and puts them back.
static func snapshot() -> Array:
	return [_asks.duplicate(true), _sides.duplicate(true), _homes.duplicate(true), _pruned_tick]


static func restore(saved: Array) -> void:
	_asks = saved[0]
	_sides = saved[1]
	_homes = saved[2]
	_pruned_tick = saved[3]


## The walking speed of `body` (UnitBody move_speed · speed_factor), 0 when it has none.
static func _pace(body: Node3D) -> float:
	var speed: Variant = body.get("move_speed")
	var factor: Variant = body.get("speed_factor")
	return (float(speed) if speed != null else 0.0) * (float(factor) if factor != null else 1.0)


## The side to slide to: the one kept from a recent slide, or `fresh`.
static func _slide_side(body: Node3D, fresh: float) -> float:
	var held: Variant = _sides.get(body.get_instance_id())
	if held != null and int(held[1]) >= MatchClock.now():
		return float(held[0])
	return fresh


## Drops the requests and sides that ran out and the homes of freed bodies (once a second; also checked when read).
static func _prune() -> void:
	var tick := MatchClock.now()
	if tick < _pruned_tick:
		## The clock went back: a new match (MatchClock.begin). The ticks of the old one mean nothing now.
		_asks.clear()
		_sides.clear()
		_homes.clear()
		_pruned_tick = -1
	if tick - _pruned_tick < 60:
		return
	_pruned_tick = tick
	for id in _asks.keys():
		if int(_asks[id][1]) < tick:
			_asks.erase(id)
	for id in _sides.keys():
		if int(_sides[id][1]) < tick:
			_sides.erase(id)
	for id in _homes.keys():
		if not is_instance_id_valid(id):
			_homes.erase(id)


## `walker`, heading `heading`, was cut by `other`: a creature of its slot that stands still with no order is asked to
## make way. A live request keeps the direction of the closest walker of the tick it was set; an ask of a later tick, or
## one after it ran out, sets it again.
static func _ask_to_yield(walker: Node3D, other: Node3D, heading: Vector2) -> void:
	if not other.is_in_group(&"unit") or not "owner_slot" in walker:
		return
	if int(other.get("owner_slot")) != int(walker.get("owner_slot")) or int(other.get("mode")) != UnitBody.Mode.IDLE:
		return
	if bool(other.get("ordered")) or not bool(other.call("is_targetable")):
		return
	var id := other.get_instance_id()
	var tick := MatchClock.now()
	var from := walker.global_position
	var at := other.global_position
	var gap := Vector2(at.x - from.x, at.z - from.z)
	var held: Variant = _asks.get(id)
	if held != null and int(held[1]) >= tick and int(held[2]) == tick and float(held[3]) <= gap.length():
		return
	var across := Vector2(-heading.y, heading.x)
	var side := 1.0 if gap.dot(across) >= 0.0 else -1.0
	_asks[id] = [across * (side * YIELD_SPEED), tick + HOLD_TICKS, tick, gap.length()]
	_mark_home(id, at, tick + HOLD_TICKS)
