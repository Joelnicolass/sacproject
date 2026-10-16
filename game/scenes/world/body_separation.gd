class_name BodySeparation
extends RefCounted

## Creatures and wizards do not walk through each other, as sacengine positionAfterCollision
## (state.d:14446-14564). Every living body is an axis-aligned box (dead and preSpawning ones are
## not obstacles, ghosts are: isObstacle / isReactingToObstacles, state.d:112-126). First pass,
## with the box shrunk by blockSlack: a step that goes deeper into an obstacle is cut along the
## axis of least overlap (newPosition.x = min(newPosition.x, position.x)…). Second pass, with the
## box grown by blockSlack: the overlaps add up to a push-out capped at collisionFixupSpeed
## (stats.d:161). Call resolve on the velocity right before GroundGuard.keep_on_ground and
## move_and_slide, so the push still slides on the ground like moveOnGround (state.d:14553).

const GROUPS: Array[StringName] = [&"unit", &"wizard", &"doctor"]
## sacengine blockSlack (state.d:14538).
const BLOCK_SLACK := 0.2
## sacengine collisionFixupSpeed, m/s (stats.d:161).
const FIXUP_SPEED := 5.0

## RFC-024 addendum 1 (024b2): with 90+ bodies the pair loop was the cost of the tick. The obstacles are
## filed once per physics tick in a grid (BodyGrid) and a body asks only for the cells around it; the
## candidates keep the order of the old list. Since RFC-027 027d they are read where they were filed (see
## _resolve_near) and a pair whose boxes do not meet draws no tie (see _scan).

## Meters a pair may be kept by _resolve_near beyond the exact overlap bound (float error of the sums in _scan).
const NEAR_SLACK := 0.001

enum Face { NONE, LEFT, RIGHT, BACK, FRONT }

## Off: the old way, every body against every other at its live position (to compare the cost; the same velocity as
## the grid while nothing moved since the grid was filed).
static var use_grid := true
## Deviation of the port (RFC-024 024d fix, decision of the orchestrator): a wizard has right of way over his own creatures.
## When the body that moves is a wizard, the creatures (group «unit») of his own slot are not obstacles for him; they still
## treat him as one, so the creature steps aside and the wizard is never pushed back by his own army. sacengine
## positionAfterCollision (state.d:14446-14564) does not exempt one's own side: with an escort on guard ahead of him the
## wizard was pushed backwards and boxed in (debug/escort_jam.tscn). Off = the original rule.
static var wizard_passes_own := true
## RFC-027 027d (F88), deviation of the port (debt of F72, RFC-026 §8: inside BodySeparation, no RVO). In sacengine
## positionAfterCollision a body that walks head-on into another only has the step cut (newPosition.x = min(…)) and waits:
## with 150 creatures ordered through each other's formation slots, dozens stood still for good behind bodies already
## parked on their slots (debug/crowd_cases.gd, crowd_150). With make_way on:
## - Slide: a body whose first-pass cut leaves less than SLIDE_KEEP of its speed tries the detours DETOUR_DEG off its
##   heading, first to the side it slid to in the last HOLD_TICKS, else away from the bodies that cut it, and takes the
##   first that keeps SLIDE_KEEP of its speed.
## - Yield: a creature of the same slot standing still (UnitBody IDLE) that cut such a body steps aside, across the
##   walker's heading and away from its line, at YIELD_SPEED, until HOLD_TICKS after it was last asked (from its next
##   resolve on: the order of the bodies in the tick decides whether that is this tick or the next one).
## - Soft between walkers: for a creature on its way (MOVE or CHASE) the creatures of its slot also on their way do not
##   cut the step (first pass); the second pass still pushes the two out of each other at up to FIXUP_SPEED, so two
##   that meet head-on press, turn the overlap sideways and pass instead of holding each other.
## Both passes run as before on the resulting velocity. Off = the original rule.
static var make_way := true
## The fraction of its speed a cut step must keep along its own heading to count as free.
const SLIDE_KEEP := 0.5
## The detours tried, in degrees off the heading, in order (each to the preferred side, then to the other).
const DETOUR_DEG: Array[float] = [45.0, 90.0]
## m/s of the sidestep of a creature that makes way.
const YIELD_SPEED := 2.5
## Physics ticks a request to make way, and the side of a slide, hold after they were last made.
const HOLD_TICKS := 20
## On: resolve() adds its time to sep_us (the bench reports it per tick as `sep_ms`).
static var measure := false
static var sep_us := 0
static var sep_calls := 0


## Horizontal velocity of `body` after both passes of positionAfterCollision (and make_way) against the obstacles
## around it; Y is kept. With use_grid (the default) the candidates come from the cells of BodyGrid near the body and
## a cheap filter drops those whose box cannot meet the probe (see _resolve_near); with use_grid off every obstacle is
## read live (the old pair loop). Adds its time to sep_us while `measure` is on.
static func resolve(body: Node3D, velocity: Vector3, delta: float) -> Vector3:
	if not measure:
		return _resolve(body, velocity, delta)
	var started := Time.get_ticks_usec()
	var result := _resolve(body, velocity, delta)
	sep_us += Time.get_ticks_usec() - started
	sep_calls += 1
	return result


## Microseconds spent in resolve() since the last call; the bench reads it once a tick.
static func take_us() -> int:
	var taken := sep_us
	sep_us = 0
	sep_calls = 0
	return taken


static func _resolve(body: Node3D, velocity: Vector3, delta: float) -> Vector3:
	if delta <= 0.0 or not body.is_inside_tree():
		return velocity
	if make_way:
		velocity = _with_yield(body, velocity)
	if use_grid:
		return _resolve_near(body, velocity, delta)
	var others := _obstacles(body)
	if others.is_empty():
		return velocity
	var count := others.size()
	var at_x := PackedFloat64Array()
	var at_y := PackedFloat64Array()
	var at_z := PackedFloat64Array()
	var halves := PackedFloat64Array()
	var heights := PackedFloat64Array()
	at_x.resize(count)
	at_y.resize(count)
	at_z.resize(count)
	halves.resize(count)
	heights.resize(count)
	for i in count:
		var other := others[i]
		var other_at := other.global_position
		at_x[i] = other_at.x
		at_y[i] = other_at.y
		at_z[i] = other_at.z
		var box := _box(other)
		halves[i] = box.x
		heights[i] = box.y
	var own_box := _box(body)
	return _separate(body, body.global_position, own_box.x, own_box.y, velocity, delta, at_x, at_y, at_z, halves, heights, others)


## The grid path. RFC-027 027d (F88): the obstacles are read where BodyGrid filed them at the first resolve of the
## tick, as sacengine reads the hitboxes of state.proximity, built once per frame (before 027d they were read live,
## each at the place it had reached in this tick). A candidate of the cells around the body goes to _scan only if
## its box can overlap the probe of either pass: _scan gives Face.NONE and draws nothing for one that does not (see
## _scan), so leaving it out changes neither the push, the cuts nor the seeded stream. With make_way, a detour may
## turn the step up to 90 degrees, so either axis can take the whole step.
static func _resolve_near(body: Node3D, velocity: Vector3, delta: float) -> Vector3:
	var grid := _grid
	grid.file(body.get_tree(), GROUPS)
	if grid.is_empty():
		return velocity
	var at := body.global_position
	var own_box := _box(body)
	var half := own_box.x
	var height := own_box.y
	var step_x := absf(velocity.x * delta)
	var step_z := absf(velocity.z * delta)
	if make_way:
		step_x = Vector2(velocity.x, velocity.z).length() * delta
		step_z = step_x
	var outer := half + 0.5 * BLOCK_SLACK
	# The probe of both scans stays within (step_x, step_z) of `at` and its box half within outer; NEAR_SLACK keeps
	# the float error of _scan's sums on the side of keeping the pair.
	var apart_x := outer + step_x + NEAR_SLACK
	var apart_z := outer + step_z + NEAR_SLACK
	var reach_x := apart_x + grid.widest
	var reach_z := apart_z + grid.widest
	var cell := BodyGrid.CELL
	var indices := grid.indices_in(floori((at.x - reach_x) / cell), floori((at.x + reach_x) / cell),
			floori((at.z - reach_z) / cell), floori((at.z + reach_z) / cell))
	if indices.is_empty():
		return velocity
	var ax := at.x
	var ay := at.y
	var az := at.z
	var at_x := PackedFloat64Array()
	var at_y := PackedFloat64Array()
	var at_z := PackedFloat64Array()
	var halves := PackedFloat64Array()
	var heights := PackedFloat64Array()
	var nodes: Array[Node3D] = []
	var filed := grid.filed
	var filed_x := grid.xs
	var filed_y := grid.ys
	var filed_z := grid.zs
	var filed_halves := grid.halves
	var filed_heights := grid.heights
	var filed_left := grid.left
	var may_pass := wizard_passes_own and body.is_in_group(&"wizard")
	for index in indices:
		var node := filed[index]
		if node == body:
			continue
		var other_half := filed_halves[index]
		var ox := filed_x[index]
		var oz := filed_z[index]
		# No overlap in the plane in either scan: _scan would give Face.NONE without a draw.
		if absf(ax - ox) >= apart_x + other_half or absf(az - oz) >= apart_z + other_half:
			continue
		var oy := filed_y[index]
		var other_height := filed_heights[index]
		# The height test of _scan: the probe's y is at.y in both scans (the step has no y).
		if ay + height <= oy or oy + other_height <= ay:
			continue
		if filed_left[index] != 0 and (not is_instance_valid(node) or not node.is_inside_tree()):
			continue
		if not is_obstacle(node) or (may_pass and _passes(body, node)):
			continue
		at_x.append(ox)
		at_y.append(oy)
		at_z.append(oz)
		halves.append(other_half)
		heights.append(other_height)
		nodes.append(node)
	if at_x.is_empty() and not _any_obstacle(body, indices):
		return velocity
	return _separate(body, at, half, height, velocity, delta, at_x, at_y, at_z, halves, heights, nodes)


## Both passes of positionAfterCollision over the obstacles' boxes, in order (`nodes` = the obstacles, same order),
## with the slide and the yield requests of make_way between them.
static func _separate(body: Node3D, at: Vector3, half: float, height: float, velocity: Vector3, delta: float,
		at_x: PackedFloat64Array, at_y: PackedFloat64Array, at_z: PackedFloat64Array, halves: PackedFloat64Array,
		heights: PackedFloat64Array, nodes: Array[Node3D]) -> Vector3:
	var inner := maxf(0.0, half - 0.5 * BLOCK_SLACK)
	var wanted := Vector2(velocity.x, velocity.z)
	# The obstacles of the first pass: all of them, but for a walking creature not the walking creatures of its slot
	# (make_way: they only push each other out, in the second pass).
	var cut_x := at_x
	var cut_y := at_y
	var cut_z := at_z
	var cut_halves := halves
	var cut_heights := heights
	var cut_nodes := nodes
	if make_way and _walks(body):
		var slot := int(body.get("owner_slot"))
		var own_walkers := PackedInt32Array()
		for i in nodes.size():
			if _walks(nodes[i]) and int(nodes[i].get("owner_slot")) == slot:
				own_walkers.append(i)
		if not own_walkers.is_empty():
			cut_x = PackedFloat64Array()
			cut_y = PackedFloat64Array()
			cut_z = PackedFloat64Array()
			cut_halves = PackedFloat64Array()
			cut_heights = PackedFloat64Array()
			cut_nodes = []
			for i in nodes.size():
				if own_walkers.has(i):
					continue
				cut_x.append(at_x[i])
				cut_y.append(at_y[i])
				cut_z.append(at_z[i])
				cut_halves.append(halves[i])
				cut_heights.append(heights[i])
				cut_nodes.append(nodes[i])
	var faces := _cut_faces(at, wanted, delta, inner, height, cut_x, cut_y, cut_z, cut_halves, cut_heights)
	var kept := _cut(wanted, faces)
	var speed := wanted.length()
	if make_way and speed > 0.0 and kept.dot(wanted) < SLIDE_KEEP * speed * speed:
		var heading := wanted / speed
		var across := Vector2(-heading.y, heading.x)
		var lateral := 0.0
		for i in faces.size():
			if _blocks(faces[i], wanted):
				lateral += (Vector2(cut_x[i], cut_z[i]) - Vector2(at.x, at.z)).dot(across)
				_ask_to_yield(body, cut_nodes[i], heading)
		var side := _slide_side(body, -1.0 if lateral > 0.0 else 1.0)
		var found := false
		for degrees in DETOUR_DEG:
			for turn: float in [side, -side]:
				var angle := deg_to_rad(degrees)
				var detour: Vector2 = (heading * cos(angle) + across * (turn * sin(angle))) * speed
				var detour_kept := _cut(detour, _cut_faces(at, detour, delta, inner, height, cut_x, cut_y, cut_z, cut_halves, cut_heights))
				if detour_kept.dot(detour) >= SLIDE_KEEP * speed * speed:
					kept = detour_kept
					found = true
					_sides[body.get_instance_id()] = [turn, Engine.get_physics_frames() + HOLD_TICKS]
					break
			if found:
				break
	velocity.x = kept.x
	velocity.z = kept.y
	var step := Vector3(velocity.x, 0.0, velocity.z) * delta
	var probe := at + step
	var push := Vector2.ZERO
	var outer := half + 0.5 * BLOCK_SLACK
	var scan := _scan(probe, outer, height, at_x, at_y, at_z, halves, heights)
	faces = scan[0]
	var amounts: PackedFloat64Array = scan[1]
	for i in faces.size():
		var amount := amounts[i]
		match faces[i]:
			Face.LEFT:
				push.x -= amount
			Face.RIGHT:
				push.x += amount
			Face.BACK:
				push.y -= amount
			Face.FRONT:
				push.y += amount
	var cap := FIXUP_SPEED * delta
	if push.length() > cap:
		push = push.normalized() * cap
	velocity.x += push.x / delta
	velocity.z += push.y / delta
	return velocity


## The faces of the first pass (inner box) for a step of `move` (m/s, flat).
static func _cut_faces(at: Vector3, move: Vector2, delta: float, inner: float, height: float, at_x: PackedFloat64Array,
		at_y: PackedFloat64Array, at_z: PackedFloat64Array, halves: PackedFloat64Array, heights: PackedFloat64Array) -> PackedInt32Array:
	var probe := at + Vector3(move.x, 0.0, move.y) * delta
	return _scan(probe, inner, height, at_x, at_y, at_z, halves, heights)[0]


## `move` cut by the faces of the first pass: no component goes deeper into an obstacle (newPosition.x = min(…)).
static func _cut(move: Vector2, faces: PackedInt32Array) -> Vector2:
	for face in faces:
		match face:
			Face.LEFT:
				move.x = minf(move.x, 0.0)
			Face.RIGHT:
				move.x = maxf(move.x, 0.0)
			Face.BACK:
				move.y = minf(move.y, 0.0)
			Face.FRONT:
				move.y = maxf(move.y, 0.0)
	return move


## Whether `face` cuts a component that `move` has.
static func _blocks(face: int, move: Vector2) -> bool:
	match face:
		Face.LEFT:
			return move.x > 0.0
		Face.RIGHT:
			return move.x < 0.0
		Face.BACK:
			return move.y > 0.0
		Face.FRONT:
			return move.y < 0.0
	return false


## make_way requests: instance id of the creature asked to step aside -> [sidestep (flat, m/s), last tick]. A request
## holds HOLD_TICKS after the last time it was made, so the one asked gets clear instead of stepping back the next tick.
static var _asks: Dictionary = {}
## The side (+1 / -1 across the heading) a body last slid to -> [side, last tick]: kept HOLD_TICKS, so a body does not
## swing from one side of a blocker to the other every tick.
static var _sides: Dictionary = {}
static var _pruned_tick := -1


## The side to slide to: the one kept from a recent slide, or `fresh`.
static func _slide_side(body: Node3D, fresh: float) -> float:
	var held: Variant = _sides.get(body.get_instance_id())
	if held != null and int(held[1]) >= Engine.get_physics_frames():
		return float(held[0])
	return fresh


## Drops the requests and sides that ran out (once a second: they are also checked when read).
static func _prune() -> void:
	var tick := Engine.get_physics_frames()
	if tick - _pruned_tick < 60:
		return
	_pruned_tick = tick
	for table: Dictionary in [_asks, _sides]:
		for id in table.keys():
			if int(table[id][1]) < tick:
				table.erase(id)


## `walker`, heading `heading`, was cut by `other`: a creature of its slot that stands still (IDLE) is asked to make way.
static func _ask_to_yield(walker: Node3D, other: Node3D, heading: Vector2) -> void:
	if not other.is_in_group(&"unit") or not "owner_slot" in walker:
		return
	if int(other.get("owner_slot")) != int(walker.get("owner_slot")) or int(other.get("mode")) != UnitBody.Mode.IDLE:
		return
	var id := other.get_instance_id()
	var until := Engine.get_physics_frames() + HOLD_TICKS
	var held: Variant = _asks.get(id)
	if held != null:
		held[1] = until
		return
	var across := Vector2(-heading.y, heading.x)
	var from := walker.global_position
	var at := other.global_position
	var side := 1.0 if Vector2(at.x - from.x, at.z - from.z).dot(across) >= 0.0 else -1.0
	_asks[id] = [across * (side * YIELD_SPEED), until]


## A creature on its way (UnitBody MOVE or CHASE).
static func _walks(node: Node3D) -> bool:
	if not node.is_in_group(&"unit"):
		return false
	var mode := int(node.get("mode"))
	return mode == UnitBody.Mode.MOVE or mode == UnitBody.Mode.CHASE


## `velocity` of `body`, or the sidestep it was asked for if it was asked and still stands still (no velocity of its own).
static func _with_yield(body: Node3D, velocity: Vector3) -> Vector3:
	_prune()
	if _asks.is_empty() or velocity.x != 0.0 or velocity.z != 0.0:
		return velocity
	var id := body.get_instance_id()
	var ask: Variant = _asks.get(id)
	if ask == null:
		return velocity
	if int(ask[1]) < Engine.get_physics_frames():
		_asks.erase(id)
		return velocity
	var away: Vector2 = ask[0]
	velocity.x = away.x
	velocity.z = away.y
	return velocity


## (half width, height) of a body's box. Both come from the model, which changes rarely, so they
## are read once per body per physics tick instead of once per pair of bodies.
static var _boxes: Dictionary = {}
static var _boxes_tick := -1


## The (half width, height) box of `body` this tick (BodyGrid files it with each obstacle).
static func box_of(body: Node3D) -> Vector2:
	return _box(body)


static func _box(body: Node3D) -> Vector2:
	var tick := Engine.get_physics_frames()
	if tick != _boxes_tick:
		_boxes_tick = tick
		_boxes.clear()
	var id := body.get_instance_id()
	if _boxes.has(id):
		return _boxes[id]
	var box := Vector2(half_size(body), body_height(body))
	_boxes[id] = box
	return box


## Half the box width: the same body size Orders uses for the formation (getFormationOffsets).
static func half_size(body: Node3D) -> float:
	var model := str(body.get("model")) if "model" in body else ""
	var info := BodyLibrary.info(model)
	return maxf(float(info.get("radius", 0.35)), float(info.get("reach", 0.35)))


static func body_height(body: Node3D) -> float:
	var model := str(body.get("model")) if "model" in body else ""
	return float(BodyLibrary.info(model).get("height", 1.8))


static func is_obstacle(body: Node) -> bool:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return false
	if body.has_method("is_obstacle"):
		return bool(body.call("is_obstacle"))
	return true


static func _obstacles(body: Node3D) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for group in GROUPS:
		for node in body.get_tree().get_nodes_in_group(group):
			if node != body and node is Node3D and is_obstacle(node) and not _passes(body, node):
				found.append(node as Node3D)
	return found


## The grid of the obstacles (BodyGrid), filed again once per physics tick by _resolve_near.
static var _grid := BodyGrid.new()


## Whether the old candidate list (the cells around `body`) was not empty: with none, resolve returns the velocity
## as it came; with some that all miss, both passes still run and add a zero push (which turns a -0.0 into 0.0).
static func _any_obstacle(body: Node3D, indices: PackedInt32Array) -> bool:
	for index in indices:
		var node := _grid.filed[index]
		if node != body and is_instance_valid(node) and is_obstacle(node) and not _passes(body, node):
			return true
	return false


## `body` walks through `other`: a wizard through a creature of his own slot (see wizard_passes_own).
static func _passes(body: Node3D, other: Node3D) -> bool:
	if not wizard_passes_own or not body.is_in_group(&"wizard") or not other.is_in_group(&"unit"):
		return false
	return "owner_slot" in body and "owner_slot" in other and int(body.get("owner_slot")) == int(other.get("owner_slot"))


## For a box of half width `half` at `center` against every obstacle box: [faces, overlaps],
## one entry per obstacle in order. The obstacle face is the one of least overlap; a tie picks at
## random (state.uniform(2)). Face.NONE and 0, with no draw, when they do not overlap in height or in the plane.
## Inlined on purpose: this runs per pair of bodies every physics tick.
static func _scan(center: Vector3, half: float, height: float, at_x: PackedFloat64Array,
		at_y: PackedFloat64Array, at_z: PackedFloat64Array, halves: PackedFloat64Array,
		heights: PackedFloat64Array) -> Array:
	var count := at_x.size()
	var faces := PackedInt32Array()
	var amounts := PackedFloat64Array()
	faces.resize(count)
	amounts.resize(count)
	var cx := center.x
	var cy := center.y
	var cz := center.z
	for i in count:
		var oy := at_y[i]
		if cy + height <= oy or oy + heights[i] <= cy:
			continue
		var ox := at_x[i]
		var oz := at_z[i]
		var other_half := halves[i]
		var left := (cx + half) - (ox - other_half)
		var right := (ox + other_half) - (cx - half)
		var back := (cz + half) - (oz - other_half)
		var front := (oz + other_half) - (cz - half)
		# RFC-027 027d: no overlap, no face and no draw. sacengine handles (and draws for) only the proximity entries whose
		# hitbox meets the body's (proximity.collide); the port drew the ties of every pair it was given.
		if left <= 0.0 or right <= 0.0 or back <= 0.0 or front <= 0.0:
			continue
		var best_face := Face.LEFT
		var best := left
		if right < best or (is_equal_approx(right, best) and MatchSeed.separation.randi() % 2 == 0):
			best_face = Face.RIGHT
			best = right
		if back < best or (is_equal_approx(back, best) and MatchSeed.separation.randi() % 2 == 0):
			best_face = Face.BACK
			best = back
		if front < best or (is_equal_approx(front, best) and MatchSeed.separation.randi() % 2 == 0):
			best_face = Face.FRONT
			best = front
		faces[i] = best_face
		amounts[i] = best
	return [faces, amounts]
