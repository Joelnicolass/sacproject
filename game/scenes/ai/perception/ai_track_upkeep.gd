class_name AiTrackUpkeep
extends RefCounted

## How the AI keeps its tracks over time: whether a body is worth following (in the wizard's region, alive), what tells the index
## that a tracked body died or fell, the periodic re-rating and status of each body, the side's soul and fount stats, and the order
## of the lists (best worth first). Static and read-only on the game: AiPerception owns the tracks and calls it.
## Ref: shiny.d:754-775 shouldTrack, 1289-1297 updateNtts (the soul snapshot of updateWiz, 1080-1083, is read for the own wizard only: sacengine reads the enemy wizard's too, without seeing him), 1243-1262 updateStats, 1651-1672 sortFam1


## The body lies in the wizard's pathfinder region (when there is a wizard and a ready pathfinder) and is not dead.
static func should_track(node: Node3D, kind: AiTrack.Kind, wizard: Node3D, service: NavService) -> bool:
	if wizard != null and is_instance_valid(wizard) and service != null and service.is_ready():
		if not service.same_region(wizard.global_position, node.global_position):
			return false
	if kind == AiTrack.Kind.STRUCTURE:
		return true
	return not AiBody.is_dead(node)


## Connects `on_died` to a creature's death and `on_state` to a structure's state, once (a body forgotten and known again keeps its
## connection).
static func watch(t: AiTrack, on_died: Callable, on_state: Callable) -> void:
	var node := t.node
	if t.kind == AiTrack.Kind.CREATURE or t.kind == AiTrack.Kind.MANAHOAR:
		if not node.is_connected("died", on_died):
			node.connect("died", on_died)
	elif t.kind == AiTrack.Kind.STRUCTURE and node.has_signal("state_changed"):
		if not node.is_connected("state_changed", on_state):
			node.connect("state_changed", on_state)


## What falls due on `t` at its age: a new rating, the Manahoar's readiness, the own wizard's souls, a structure's state.
static func upkeep(t: AiTrack, perception: AiPerception) -> void:
	var play := perception.play
	var senses := play.tactics.senses
	match t.kind:
		AiTrack.Kind.CREATURE, AiTrack.Kind.MANAHOAR, AiTrack.Kind.WIZARD:
			if t.age >= t.rerate_tick:
				t.rerate_tick = t.age + play.ages_for(senses.rerate_s)
				AiTrackFacts.rate(t, perception)
			if t.kind == AiTrack.Kind.MANAHOAR and t.age >= t.status_tick:
				t.status_tick = t.age + play.ages_for(senses.status_s)
				if perception.sees(t):  # an unseen Manahoar keeps the readiness seen last (no difficulty cheats)
					t.ready = maho_ready(t.node)
			if t.kind == AiTrack.Kind.WIZARD and t.relation == AiTrack.Relation.OWN and t.age >= t.souls_snap_tick:
				t.souls_snap_tick = t.age + play.ages_for(senses.souls_snapshot_s)
				var purse := t.node.get_node_or_null("SoulPurse")
				if purse != null:
					t.souls_snap = int(purse.get("count"))
		AiTrack.Kind.STRUCTURE:
			if t.age >= t.status_tick:
				t.status_tick = t.age + play.ages_for(senses.status_s)
				AiTrackFacts.refresh_structure(t)


## A Manahoar works while it is not dead, not being summoned and not held. ## Ref: manahoarAbilityEnabled.
static func maho_ready(node: Node) -> bool:
	var unit := node as UnitBody
	return unit == null or not (unit.is_dead() or unit.is_summoning() or unit.is_taken())


## The side's stats: the most souls it has seen on the wizards it knows (their mana and soul snapshots) and the free mana founts
## among the neutral structures.
static func update_stats(perception: AiPerception) -> void:
	var souls := 0
	for t: AiTrack in perception.tracks.values():
		if t.kind == AiTrack.Kind.WIZARD:
			souls += t.mana_snap + t.souls_snap
	perception.max_souls_seen = maxi(perception.max_souls_seen, souls)
	perception.neutral_founts = 0
	for t: AiTrack in perception.structures(2):
		if t.free_fount and t.node.is_in_group(&"manafount"):
			perception.neutral_founts += 1


## Every list of `lists`, stable, best worth first (the key is the cached rate).
static func sort_lists(lists: Array) -> void:
	for k in lists.size():
		sort_by_rate(lists[k])


static func sort_by_rate(list: Array) -> void:
	var order := {}
	for i in list.size():
		order[(list[i] as AiTrack).id] = i
	list.sort_custom(func(a: AiTrack, b: AiTrack) -> bool:
		if a.cached_rate != b.cached_rate:
			return a.cached_rate > b.cached_rate
		return int(order[a.id]) < int(order[b.id]))
