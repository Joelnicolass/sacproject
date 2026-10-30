class_name CreatureBrain
extends Node

## The brain of a creature of the AI. What a creature does when its record asks it to think. First,
## A body with mana that dropped to its minimum goes to the best source it knows (a
## ready Manahoar of its side, weighed x1000, or an own mana building) and stays by it. Then, by the
## kind of the record's task: guard stays by the target and fights what comes (REFILL, radius
## `retreat_hold_m`), capture goes to the anchor of the record (order_interact: move there, then
## guard it or advance), focus attacks the record's target, idle nothing, since the record's
## leader or the creature's own aggression decide. The wizard calls it when he has nothing to cast,
## as the original does.

## A body that goes to refill holds this close to the source: a building, a Manahoar.
const BUILDING_HOLD_M := 50.0
const MANAHOAR_HOLD_M := 40.0
## A Manahoar weighs this much more than a mana building as a source.
const MANAHOAR_WEIGHT := 1000.0

@export var port: AiCommandPort
@export var perception: AiPerception

## What the side plays with (AiSide.setup sets it once): its crowd tactics give the guard, capture
## and refill distances.
var play: AiPlay


## t4oBrain. Returns true when it handled the case.
func think(t: AiTrack, task_kind: AiTask.Kind, record: AiRecord) -> bool:
	if auto_capture(t):
		return true
	if record == null:
		return false
	match task_kind:
		AiTask.Kind.IDLE:
			return true
		AiTask.Kind.GUARD:
			if record.target != null:
				port.orders.order_target_radius(
					t,
					AiCommandPort.AiOrder.REFILL,
					record.target,
					play.tactics.crowd.retreat_hold_m
				)
			return true
		AiTask.Kind.CAPTURE:
			# (1 - value6c) * interact_reach_m, with value6c the wizard's threat (a creature's is
			# 0).
			var reach := AiField.f32((1.0 - t.value_6c()) * play.tactics.crowd.interact_reach_m)
			port.orders.order_interact(t, record.anchor, record.target, reach)
			return true
		AiTask.Kind.FOCUS:
			# Attack the target the side committed to, the order of a human's
			# right click.
			if record.target != null and AiWizardBrain.target_alive(record.target):
				port.orders.order_if_changed(t, AiCommandPort.AiOrder.ATTACK, record.target, null)
			return true
	# max-returns: one return per task the creature can be on.
	# gdlint: ignore=max-returns
	return true


## A body with a mana pool whose mana is not above its minimum (`min_mana_cost`; a wizard
## with a creature to summon at the head of his queue: 5/4 of its cost) looks for the best source of
## mana within 3620 m of itself and, if it is not already within the radius of it (50 m a building,
## 40 m a Manahoar), guards it.
func auto_capture(t: AiTrack) -> bool:
	if (
		perception == null
		or t.kind == AiTrack.Kind.MANAHOAR
		or t.kind == AiTrack.Kind.NONE
		or t.kind == AiTrack.Kind.STRUCTURE
	):
		return false
	var pair := AiBody.mana_pair(t)
	if pair.y == 0:
		return false
	if pair.x <= _min_mana(t) or _respawning(t):
		t.refilling = true
	elif not t.refilling or pair.x >= refill_until(t, pair.y):
		t.refilling = false
		return false
	var found := find_best_capture_target(t.cur_pos, play.tactics.crowd.mana_seek_m)
	if found.is_empty():
		return false
	var source: AiTrack = found["node"]
	var radius := float(found["radius"])
	if DebugLog.on(&"ai_order") and t.kind == AiTrack.Kind.WIZARD:
		print(
			(
				"ai_order slot %d %s auto_capture mana %d/%d min %d until %d source %s at %.1f m"
				% [
					perception.slot,
					t.node.name,
					pair.x,
					pair.y,
					_min_mana(t),
					refill_until(t, pair.y),
					source.node.name,
					t.cur_pos.distance_to(source.cur_pos)
				]
			)
		)
	if radius * radius < t.cur_pos.distance_squared_to(source.cur_pos):
		port.orders.order_if_changed(t, AiCommandPort.AiOrder.REFILL, source, null)
	return true


## The mana a body must be above to stay where it is.
func _min_mana(t: AiTrack) -> int:
	if t.kind == AiTrack.Kind.WIZARD and not t.cast_queue.is_empty():
		if perception.own_desecration():
			return AiRater.ftol(t.min_mana_cost)
		var head: Resource = (t.cast_queue[0] as Dictionary)["spell"]
		if head is CreatureType:
			var souls := AiBody.souls(t.node)
			if souls > (head as CreatureType).souls:
				@warning_ignore("integer_division")
				return 5 * AiRater.ftol(float((head as CreatureType).mana_cost)) / 4
	return AiRater.ftol(t.min_mana_cost)


## The mana a body that went to refill holds before it leaves the source:
## AiCrowdTactics.mana_refill_ratio of its pool, never under its minimum + 1 (with a ratio of 0: the
## minimum + 1, the original's «above the minimum»).
func refill_until(t: AiTrack, max_mana: int) -> int:
	var ratio := play.tactics.crowd.mana_refill_ratio
	return maxi(_min_mana(t) + 1, AiRater.ftol(float(max_mana) * ratio))


static func _respawning(t: AiTrack) -> bool:
	return t.kind == AiTrack.Kind.WIZARD and (t.node as WizardBody).is_ghost()


## Among the own and ally bodies and structures that are READY (a Manahoar
## that works, a standing mana building with nothing on top) in the region of `pos`, the one that
## weighs most: 1 within 1 m, falling to 0 at `radius`; x1000 a Manahoar (a building: x its mana
## yield, which the port does not export: 1, «aprox.»). Returns {node, radius} or {} (50 m for a
## building, 40 m for a Manahoar).
func find_best_capture_target(pos: Vector3, radius: float) -> Dictionary:
	var best := 0.0
	var found: AiTrack
	var found_radius := 0.0
	var service := perception.nav()
	for relation in [AiTrack.Relation.OWN, AiTrack.Relation.ALLY]:
		for list in [perception.bodies(relation), perception.structures(relation)]:
			for t: AiTrack in list:
				if not t.ready or not t.is_valid():
					continue
				if (
					service != null
					and service.is_ready()
					and not service.same_region(pos, t.cur_pos)
				):
					continue
				var d := pos.distance_to(t.cur_pos)
				var w := 0.0
				if d <= 1.0:
					w = 1.0
				elif d < radius:
					w = AiField.safediv(radius - d, radius - 1.0)
				if t.kind == AiTrack.Kind.STRUCTURE:
					# «ready»: the building has to be standing (an altar being desecrated is still
					# there)
					pass
				else:
					w *= MANAHOAR_WEIGHT
				if best < w:
					best = w
					found = t
					found_radius = (
						BUILDING_HOLD_M if t.kind == AiTrack.Kind.STRUCTURE else MANAHOAR_HOLD_M
					)
	if found == null:
		return {}
	return {"node": found, "radius": found_radius}
