class_name CreatureBrain
extends Node

## The brain of a creature of the AI (RFC-024 §3.1 `CreatureBrain`; shiny.d:2557-2570 `t4oBrain`, 2546-2555 `autoCapture`). What a
## creature does when its record asks it to think. First, `autoCapture`: a body with mana that dropped to its minimum goes to
## the best source it knows (a ready Manahoar of its side, weighed x1000, or an own mana building) and stays by it. Then, by the
## kind of the record's task: guard stays by the target and fights what comes (REFILL, radius `retreat_hold_m`), capture
## goes to the anchor of the record (orderInteract: move there, then guard it or advance), focus (F373) attacks the record's target,
## idle nothing,
## since the record's leader or the creature's own aggression decide. The wizard calls it when he has nothing to cast, as
## the original does.

@export var port: AiCommandPort
@export var perception: AiPerception
@export var profile: AiProfile

## RFC-053: the common sense of the difficulty (AiSide.setup sets it). Null: the original autoCapture, no refill band.
var tactics: AiTactics


## t4oBrain (shiny.d:2557-2570). Returns 1 when it handled the case.
func think(t: AiTrack, task_kind: AiTask.Kind, record: AiRecord) -> int:
	if auto_capture(t) != 0:
		return 1
	if record == null:
		return 0
	match task_kind:
		AiTask.Kind.IDLE:
			return 1
		AiTask.Kind.GUARD:
			if record.target != null:
				port.orders.order_target_radius(t, AiCommandPort.AiOrder.REFILL, record.target, profile.retreat_hold_m if profile != null else 10.0)
			return 1
		AiTask.Kind.CAPTURE:
			## thaum: (1 - value6c) * 160, with value6c the wizard's threat (a creature's is 0).
			var reach := AiField.f32((1.0 - t.value_6c()) * (profile.interact_reach_m if profile != null else 160.0))
			port.orders.order_interact(t, record.anchor, record.target, reach)
			return 1
		AiTask.Kind.FOCUS:
			## RFC-053 053d (F373): attack the target the side committed to, the order of a human's right click.
			if record.target != null and AiWizardBrain.target_alive(record.target):
				port.orders.order_if_changed(t, AiCommandPort.AiOrder.ATTACK, record.target, null)
			return 1
	return 1


## autoCapture (shiny.d:2546-2555, 0x487600): a body with a mana pool whose mana is not above its minimum (`minManaCost`; a wizard
## with a creature to summon at the head of his queue: 5/4 of its cost) looks for the best source of mana within 3620 m of itself and,
## if it is not already within the radius of it (50 m a building, 40 m a Manahoar), guards it.
func auto_capture(t: AiTrack) -> int:
	if perception == null or t.kind == AiTrack.Kind.MANAHOAR or t.kind == AiTrack.Kind.NONE or t.kind == AiTrack.Kind.STRUCTURE:
		return 0
	var pair := AiBody.mana_pair(t)
	if pair.y == 0:
		return 0
	if pair.x <= _min_mana(t) or _respawning(t):
		t.refilling = true
	elif not t.refilling or pair.x >= refill_until(t, pair.y):
		t.refilling = false
		return 0
	var found := find_best_capture_target(t.cur_pos, profile.mana_seek_m if profile != null else 3620.0)
	if found.is_empty():
		return 0
	var source: AiTrack = found["node"]
	var radius := float(found["radius"])
	if DebugLog.on(&"ai_order") and t.kind == AiTrack.Kind.WIZARD:
		print("ai_order slot %d %s auto_capture mana %d/%d min %d hasta %d fuente %s a %.1f m" % [perception.slot, t.node.name, pair.x, pair.y,
			_min_mana(t), refill_until(t, pair.y),
			source.node.name, t.cur_pos.distance_to(source.cur_pos)])
	if radius * radius < t.cur_pos.distance_squared_to(source.cur_pos):
		port.orders.order_if_changed(t, AiCommandPort.AiOrder.REFILL, source, null)
	return 1


## nodeSlot22 (shiny.d:2498-2512): the mana a body must be above to stay where it is.
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


## The mana a body that went to refill holds before it leaves the source: AiTactics.mana_refill_ratio of its pool, never under its
## minimum + 1 (with no tactics or a ratio of 0: the minimum + 1, the original's «above the minimum»).
func refill_until(t: AiTrack, max_mana: int) -> int:
	var ratio := tactics.mana_refill_ratio if tactics != null else 0.0
	return maxi(_min_mana(t) + 1, AiRater.ftol(float(max_mana) * ratio))


static func _respawning(t: AiTrack) -> bool:
	return t.kind == AiTrack.Kind.WIZARD and (t.node as WizardBody).is_ghost()


## findBestCaptureTarget (shiny.d:2518-2545, 0x485a40): among the own and ally bodies and structures that are READY (a Manahoar that
## works, a standing mana building with nothing on top) in the region of `pos`, the one that weighs most: 1 within 1 m, falling to 0
## at `radius`; x1000 a Manahoar (a building: x its mana yield, which the port does not export: 1, «aprox.»). Returns {node, radius}
## or {} (50 m for a building, 40 m for a Manahoar).
func find_best_capture_target(pos: Vector3, radius: float) -> Dictionary:
	var best := 0.0
	var found: AiTrack
	var found_radius := 0.0
	var service := perception.nav()
	for category in [0, 1]:
		for list in [perception.bodies(category), perception.structures(category)]:
			for t: AiTrack in list:
				if not t.ready or not t.is_valid():
					continue
				if service != null and service.is_ready() and not service.same_region(pos, t.cur_pos):
					continue
				var d := pos.distance_to(t.cur_pos)
				var w := 0.0
				if d <= 1.0:
					w = 1.0
				elif d < radius:
					w = AiField.safediv(radius - d, radius - 1.0)
				if t.kind == AiTrack.Kind.STRUCTURE:
					## «ready»: the building has to be standing (an altar being desecrated is still there)
					pass
				else:
					w *= 1000.0
				if best < w:
					best = w
					found = t
					found_radius = 50.0 if t.kind == AiTrack.Kind.STRUCTURE else 40.0
	if found == null:
		return {}
	return {"node": found, "radius": found_radius}
