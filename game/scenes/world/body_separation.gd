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
## the grid while nothing moved since the grid was filed). It is not the rule of sacengine by itself: for that also
## turn off make_way and wizard_passes_own (the two deviations of the port).
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
## parked on their slots (debug/crowd_cases.gd, crowd_150). On: the slide, the yield and the soft contact between
## walkers of MakeWay (see there). Both passes run as before on the resulting velocity. Off = the original rule.
static var make_way := true
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
		velocity = MakeWay.with_yield(body, velocity, delta)
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
## tick (or again in the middle of it after a spawn or a removal, see BodyGrid.file), as sacengine reads the hitboxes of state.proximity, built once per frame (before 027d they were read live,
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
	if make_way and MakeWay.walks(body):
		var slot := int(body.get("owner_slot"))
		var own_walkers := PackedInt32Array()
		for i in nodes.size():
			if MakeWay.walks(nodes[i]) and int(nodes[i].get("owner_slot")) == slot:
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
	var faces := first_pass_faces(at, wanted, delta, inner, height, cut_x, cut_y, cut_z, cut_halves, cut_heights)
	var kept := cut_step(wanted, faces)
	var speed := wanted.length()
	if make_way and speed > 0.0 and kept.dot(wanted) < MakeWay.SLIDE_KEEP * speed * speed and body.is_in_group(&"unit"):
		kept = MakeWay.slide(body, at, wanted, faces, inner, height, delta, cut_x, cut_y, cut_z, cut_halves, cut_heights,
				cut_nodes)
	var outer := half + 0.5 * BLOCK_SLACK
	var pass_two := _second_pass(at, kept, delta, outer, height, at_x, at_y, at_z, halves, heights)
	var push: Vector2 = pass_two[0]
	faces = pass_two[1]
	# F88 round 3: a creature whose step only enters the slack band of a body (outside its inner box, inside its grown one)
	# is not cut by the first pass, so it never slid, but the push of the second pass took the whole step back: it stood
	# still for good beside a diagonal neighbour (a creature walking back to its spot in a parked formation,
	# debug/crowd_rock.tscn). When the step plus the push keeps less than SLIDE_KEEP of the speed, the detours of the slide
	# are tried against the grown boxes, and the push is worked out again for the detour taken.
	if make_way and speed > 0.0 and body.is_in_group(&"unit"):
		var net := kept + _capped(push, delta) / delta
		if net.dot(wanted) < MakeWay.SLIDE_KEEP * speed * speed:
			var detour := MakeWay.slide(body, at, wanted, first_pass_faces(at, wanted, delta, outer, height, at_x, at_y, at_z,
					halves, heights), outer, height, delta, at_x, at_y, at_z, halves, heights, nodes)
			if detour.dot(wanted) >= MakeWay.SLIDE_KEEP * speed * speed:
				kept = detour
				pass_two = _second_pass(at, kept, delta, outer, height, at_x, at_y, at_z, halves, heights)
				push = pass_two[0]
				faces = pass_two[1]
	velocity.x = kept.x
	velocity.z = kept.y
	if make_way and push != Vector2.ZERO and wanted == Vector2.ZERO and body.is_in_group(&"unit") \
			and int(body.get("mode")) == UnitBody.Mode.IDLE and not bool(body.get("ordered")):
		var slot := int(body.get("owner_slot"))
		for i in faces.size():
			if faces[i] != Face.NONE and nodes[i].is_in_group(&"unit") and int(nodes[i].get("owner_slot")) == slot:
				MakeWay.pushed(body, MakeWay.walks(nodes[i]))
				if MakeWay.walks(nodes[i]):
					break
	# F88 round 5: a creature that stands still or makes way is pushed out of a walker of any slot only across the walker's
	# heading, never along it: the push out of the box (the axis of least overlap) often lay along the march, and a runner
	# through a dense crowd carried three creatures 20 m ahead of it (pt88b_open; debug/crowd_cases.gd crowd_return_grid).
	# The walker still slides round it and asks it to make way (MakeWay); the overlap is undone sideways.
	if make_way and push != Vector2.ZERO and body.is_in_group(&"unit") and not MakeWay.walks(body):
		push = _without_carry(faces, pass_two[2], nodes)
	push = _capped(push, delta)
	velocity.x += push.x / delta
	velocity.z += push.y / delta
	return velocity


## The second pass (box grown by blockSlack) for the step `kept` (m/s, flat): [push (m, flat, before the cap), faces].
static func _second_pass(at: Vector3, kept: Vector2, delta: float, outer: float, height: float, at_x: PackedFloat64Array,
		at_y: PackedFloat64Array, at_z: PackedFloat64Array, halves: PackedFloat64Array, heights: PackedFloat64Array) -> Array:
	var probe := at + Vector3(kept.x, 0.0, kept.y) * delta
	var scan := _scan(probe, outer, height, at_x, at_y, at_z, halves, heights)
	var faces: PackedInt32Array = scan[0]
	var amounts: PackedFloat64Array = scan[1]
	var push := Vector2.ZERO
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
	return [push, faces, amounts]


## The push of the second pass (`faces`, `amounts`, one per obstacle in `nodes`) with, for each walking creature, the part
## along its heading (its velocity of the last tick) taken out when it points the way the walker goes.
static func _without_carry(faces: PackedInt32Array, amounts: PackedFloat64Array, nodes: Array[Node3D]) -> Vector2:
	var push := Vector2.ZERO
	for i in faces.size():
		var out := Vector2.ZERO
		match faces[i]:
			Face.LEFT:
				out.x = -amounts[i]
			Face.RIGHT:
				out.x = amounts[i]
			Face.BACK:
				out.y = -amounts[i]
			Face.FRONT:
				out.y = amounts[i]
			_:
				continue
		var other := nodes[i]
		if other is CharacterBody3D and MakeWay.walks(other):
			var heading := Vector2((other as CharacterBody3D).velocity.x, (other as CharacterBody3D).velocity.z)
			if heading.length_squared() > 0.000001:
				heading = heading.normalized()
				var along := out.dot(heading)
				if along > 0.0:
					out -= heading * along
		push += out
	return push


## `push` capped at collisionFixupSpeed for one tick.
static func _capped(push: Vector2, delta: float) -> Vector2:
	var cap := FIXUP_SPEED * delta
	return push.normalized() * cap if push.length() > cap else push


## The faces of the first pass (inner box) for a step of `move` (m/s, flat).
static func first_pass_faces(at: Vector3, move: Vector2, delta: float, inner: float, height: float, at_x: PackedFloat64Array,
		at_y: PackedFloat64Array, at_z: PackedFloat64Array, halves: PackedFloat64Array, heights: PackedFloat64Array) -> PackedInt32Array:
	var probe := at + Vector3(move.x, 0.0, move.y) * delta
	return _scan(probe, inner, height, at_x, at_y, at_z, halves, heights)[0]


## `move` cut by the faces of the first pass: no component goes deeper into an obstacle (newPosition.x = min(…)).
static func cut_step(move: Vector2, faces: PackedInt32Array) -> Vector2:
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
static func blocks(face: int, move: Vector2) -> bool:
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


## (half width, height) of a body's box. Both come from the model, which changes rarely, so they
## are read once per body per physics tick instead of once per pair of bodies.
static var _boxes: Dictionary = {}
static var _boxes_tick := -1


## The (half width, height) box of `body` this tick (BodyGrid files it with each obstacle).
static func box_of(body: Node3D) -> Vector2:
	return _box(body)


static func _box(body: Node3D) -> Vector2:
	## A cache per step of the engine, not game time (RFC-032 032d): not MatchClock.
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
