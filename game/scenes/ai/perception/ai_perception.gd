# gdlint: disable=max-public-methods
# max-public-methods: the AI's read API over what a side knows (28 queries); split it by
# responsibility later, not by count.
@tool
class_name AiPerception
extends Node

## The bodies one AI side knows and what each is to it (own, ally, neutral, enemy): the index the
## rest of the AI reads. At the start it takes in every structure and wizard, its own and allied
## creatures and, with SIGHT_AND_MAP, the others on its minimap; then its own bodies as they appear,
## a foe once its side sees it (SightIntake), and it drops what dies. It keeps each track up to date
## (rating, readiness, souls), sorts the lists and answers the questions about the rituals. What it
## believes of an unseen body is Belief's, the souls are Souls'. It takes no decisions.

## Something the side's clock should answer before its time (AiClock.Wake bits).
signal forced(bits: int)
signal tracked(track: AiTrack)
signal untracked(track: AiTrack)

## The Desecrate reach when the match has no rules (MatchRules.desecrate_altar_range).
const DESECRATE_RANGE_FALLBACK := 75.0

## The passive that makes a creature a Manahoar for the AI
## (scenes/units/abilities/manahoar_channelling.tres, the Manahoar's `on_damage`).
@export var mana_source: AbilityType
@export var intake: AiSightIntake
@export var belief: AiBelief
@export var souls: AiSouls

## What the side plays with (AiSide.setup).
var play: AiPlay
var slot := 0
## The AI's own wizard (set by AiSide).
var wizard: Node3D
var tracks: Dictionary = {}
var scanned := false
## What the side has seen of souls and of free founts (the stance and the capture task read them).
var neutral_founts := 0
var max_souls_seen := 0
var unseen_reads: int:
	get:
		return belief.unseen_reads if belief != null else 0
var forgotten: int:
	get:
		return intake.forgotten if intake != null else 0

## One list per AiTrack.Relation.
var _bodies: Array = [[], [], [], []]
var _structures: Array = [[], [], [], []]
var _nav: NavService
var _sacrifice: SacrificeSystem


func _get_configuration_warnings() -> PackedStringArray:
	var missing := PackedStringArray()
	var sockets := [
		[mana_source, "mana_source (hmba.tres)"],
		[intake, "intake"],
		[belief, "belief"],
		[souls, "souls"],
	]
	for pair: Array in sockets:
		if pair[0] == null:
			var why := "without it the AI does not see, remember or recognize the Manahoar"
			missing.append("Missing `%s`: %s." % [pair[1], why])
	return missing


func nav() -> NavService:
	if _nav == null or not is_instance_valid(_nav):
		_nav = get_tree().get_first_node_in_group(NavService.GROUP) as NavService
	return _nav


func sacrifice() -> SacrificeSystem:
	if _sacrifice == null or not is_instance_valid(_sacrifice):
		_sacrifice = get_tree().get_first_node_in_group(SacrificeSystem.GROUP) as SacrificeSystem
	return _sacrifice


func scan_global() -> void:
	scanned = true
	var groups := [
		Altar.GROUP,
		ManafountBody.GROUP,
		MapBuilding.STRUCTURE_GROUP,
		WizardBody.GROUP,
		UnitBody.GROUP,
	]
	for group: StringName in groups:
		for node in get_tree().get_nodes_in_group(group):
			var foe := relation_of(node) > AiTrack.Relation.ALLY
			if group == UnitBody.GROUP and foe and not belief.within_map(node as Node3D):
				continue
			add_node(node as Node3D, AiTrack.Origin.SCAN)
	if DebugLog.on(&"ai_seat"):
		print(
			(
				"ai slot %d: first scan %d own, %d allied, %d neutral, %d enemy"
				% [
					slot,
					tracks_of(AiTrack.Relation.OWN).size(),
					tracks_of(AiTrack.Relation.ALLY).size(),
					tracks_of(AiTrack.Relation.NEUTRAL).size(),
					tracks_of(AiTrack.Relation.ENEMY).size(),
				]
			)
		)
	forced.emit(AiClock.Wake.REPLAN)


## One of its own bodies appeared, or a foe was seen. A body of the side appearing also asks for the
## stats.
func add_node(node: Node3D, origin := AiTrack.Origin.EVENT) -> AiTrack:
	if node == null or not is_instance_valid(node):
		return null
	var id := node.get_instance_id()
	if tracks.has(id):
		return tracks[id]
	var kind := AiTrackFacts.kind_of(node, mana_source)
	if kind == AiTrack.Kind.NONE or not _should_track(node, kind):
		return null
	var t := AiTrackFacts.make(node, kind, origin, self)
	tracks[id] = t
	_list_of(t).append(t)
	_watch(t)
	tracked.emit(t)
	if origin == AiTrack.Origin.EVENT:
		forced.emit(AiClock.Wake.REPLAN | AiClock.Wake.STATS)
	else:
		forced.emit(AiClock.Wake.REPLAN)
	return t


func remove_node(node: Node3D) -> void:
	var t: AiTrack = tracks.get(node.get_instance_id()) if node != null else null
	if t != null:
		_erase(t)


## Drops what no longer exists and updates the rest, `dt` ticks after the last run; it forgets what
## is not where it was seen and knows again what its side sees again.
func update_nodes(dt: int) -> void:
	if souls != null:
		souls.prune()
	for t: AiTrack in tracks.values():
		if not t.is_valid():
			_erase(t)
			continue
		if t.kind != AiTrack.Kind.WIZARD and t.is_body() and AiBody.is_dead(t.node):
			_erase(t)
			continue
		_update_node(t, dt)
	if intake != null:
		for t in intake.forget_checked(_bodies, slot, belief):
			_erase(t)
		for node in intake.take_recalled(slot):
			var t := add_node(node, AiTrack.Origin.SEEN)
			if t != null:
				t.seen = true


## Takes in what the side sees and does not track yet; marks «seen» (followed from now on) what it
## sees; ghosts and dead bodies go.
func discover() -> void:
	if intake != null:
		for node in intake.take_new(slot, tracks):
			add_node(node, AiTrack.Origin.SEEN)
	for t: AiTrack in tracks.values():
		if not t.is_valid() or (t.relation != AiTrack.Relation.OWN and _gone(t)):
			_erase(t)
		elif t.relation != AiTrack.Relation.OWN and not t.seen and VisionSides.sees(slot, t.node):
			t.seen = true
			t.age_seen = t.age


## Stable, best worth first (the key is the cached rate); the lists keep this order until the next
## replan.
func sort_bodies() -> void:
	for list: Array in _bodies:
		_sort_by_rate(list)


## The side's stats: the most souls it has seen on the wizards it knows (their mana and soul
## snapshots) and the free mana founts among the neutral structures.
func update_stats() -> void:
	var souls_seen := 0
	for t: AiTrack in tracks.values():
		if t.kind == AiTrack.Kind.WIZARD:
			souls_seen += t.mana_snap + t.souls_snap
	max_souls_seen = maxi(max_souls_seen, souls_seen)
	neutral_founts = 0
	for t: AiTrack in structures(AiTrack.Relation.NEUTRAL):
		if t.free_fount and t.node.is_in_group(ManafountBody.GROUP):
			neutral_founts += 1


# ---- Reads: the lists, what the AI believes (Belief), the souls (Souls) and the rituals ----


func find(node: Node) -> AiTrack:
	return tracks.get(node.get_instance_id()) if node != null else null


func bodies(relation: AiTrack.Relation) -> Array:
	return _bodies[relation]


func structures(relation: AiTrack.Relation) -> Array:
	return _structures[relation]


func tracks_of(relation: AiTrack.Relation) -> Array:
	return tracks.values().filter(func(t: AiTrack) -> bool: return t.relation == relation)


func relation_of(node: Node) -> AiTrack.Relation:
	return AiTrackFacts.relation(slot, owner_slot_of(node))


static func owner_slot_of(node: Node) -> int:
	return VisionRules.slot_of(node)


func tag_acc(type: CreatureType) -> PackedFloat32Array:
	return AiTrackFacts.tag_acc(type)


func sees(t: AiTrack) -> bool:
	return AiBelief.sees(t, slot)


func knows_live(t: AiTrack) -> bool:
	return belief.knows_live(t, slot)


func knows_where(t: AiTrack) -> bool:
	return belief.knows_where(t, slot)


func pos_of(t: AiTrack) -> Vector3:
	return belief.pos_of(t, slot)


func health_of(t: AiTrack) -> Vector2i:
	return belief.health_of(t, slot)


func mana_of(t: AiTrack) -> Vector2i:
	return belief.mana_of(t, slot)


func find_best_near(pos: Vector3, radius: float, pickup: bool) -> AiTrack:
	if souls == null:
		return null
	return souls.find_best_near(pos, radius, pickup, slot, sacrifice(), nav())


## A Desecrate cast, carrier or ritual against the side of the altar `altar_track`.
func desecration_against(altar_track: AiTrack) -> bool:
	var system := sacrifice()
	if system == null or altar_track == null:
		return false
	return system.desecration_against(owner_slot_of(altar_track.node))


## The side's own wizard is desecrating (his `ucas` attachment).
func own_desecration() -> bool:
	var system := sacrifice()
	return system != null and system.desecration_by(slot)


## The wizard has a standing altar of his own: where a Convert takes the creature.
func has_home_altar() -> bool:
	var system := sacrifice()
	if system == null or wizard == null:
		return false
	return system.closest_own_site(slot, wizard.global_position) != null


## The enemy altar within the Desecrate range of the wizard, as the game defines it.
func closest_enemy_altar_in_range() -> Node3D:
	var system := sacrifice()
	if system == null or wizard == null:
		return null
	var rules: MatchRules = system.rules
	var reach := rules.desecrate_altar_range if rules != null else DESECRATE_RANGE_FALLBACK
	return system.closest_enemy_altar(slot, wizard.global_position, reach)


## A Manahoar works while it is not dead, not being summoned and not held.
static func maho_ready(node: Node) -> bool:
	var unit := node as UnitBody
	return unit == null or not (unit.is_dead() or unit.is_summoning() or unit.is_taken())


func _erase(t: AiTrack) -> void:
	tracks.erase(t.id)
	_list_of(t).erase(t)
	untracked.emit(t)
	forced.emit(AiClock.Wake.REPLAN)


func _update_node(t: AiTrack, dt: int) -> void:
	belief.follow(t, dt, slot)
	if t.is_body() and t.relation != AiTrack.Relation.OWN and sees(t):
		belief.snapshot(t, slot)
	_upkeep(t)


## A body of another side that is no longer worth a track: a ghost wizard or a dead body.
func _gone(t: AiTrack) -> bool:
	if t.kind == AiTrack.Kind.WIZARD and (t.node as WizardBody).is_ghost():
		return true
	return AiBody.is_dead(t.node)


func _list_of(t: AiTrack) -> Array:
	return _bodies[t.relation] if t.is_body() else _structures[t.relation]


## The body lies in the wizard's pathfinder region (when there is a wizard and a ready pathfinder)
## and is not dead.
func _should_track(node: Node3D, kind: AiTrack.Kind) -> bool:
	var service := nav()
	if wizard != null and is_instance_valid(wizard) and service != null and service.is_ready():
		if not service.same_region(wizard.global_position, node.global_position):
			return false
	if kind == AiTrack.Kind.STRUCTURE:
		return true
	return not AiBody.is_dead(node)


## Hears a creature's death and an altar's state, once (a body forgotten and known again keeps its
## connection).
func _watch(t: AiTrack) -> void:
	var unit := t.node as UnitBody
	if unit != null and (t.kind == AiTrack.Kind.CREATURE or t.kind == AiTrack.Kind.MANAHOAR):
		var on_died := _on_unit_died.bind(unit)
		if not unit.died.is_connected(on_died):
			unit.died.connect(on_died)
		return
	var altar := t.node as Altar
	if altar != null and t.kind == AiTrack.Kind.STRUCTURE:
		var on_state := _on_altar_state.bind(altar)
		if not altar.state_changed.is_connected(on_state):
			altar.state_changed.connect(on_state)


## What falls due on `t` at its age: a new rating, the Manahoar's readiness, the own wizard's souls,
## a structure's state.
func _upkeep(t: AiTrack) -> void:
	var senses := play.tactics.senses
	match t.kind:
		AiTrack.Kind.CREATURE, AiTrack.Kind.MANAHOAR, AiTrack.Kind.WIZARD:
			if t.age >= t.rerate_tick:
				t.rerate_tick = t.age + play.ages_for(senses.rerate_s)
				AiTrackFacts.rate(t, self)
			if t.kind == AiTrack.Kind.MANAHOAR and t.age >= t.status_tick:
				t.status_tick = t.age + play.ages_for(senses.status_s)
				# an unseen Manahoar keeps the readiness seen last (no difficulty cheats)
				if sees(t):
					t.ready = maho_ready(t.node)
			var own_wizard := t.kind == AiTrack.Kind.WIZARD and t.relation == AiTrack.Relation.OWN
			if own_wizard and t.age >= t.souls_snap_tick:
				t.souls_snap_tick = t.age + play.ages_for(senses.souls_snapshot_s)
				t.souls_snap = AiBody.souls(t.node)
		AiTrack.Kind.STRUCTURE:
			if t.age >= t.status_tick:
				t.status_tick = t.age + play.ages_for(senses.status_s)
				AiTrackFacts.refresh_structure(t)


func _on_altar_state(_state: int, node: Node3D) -> void:
	if not (node as Altar).is_standing():
		remove_node(node)


func _on_unit_died(_tag: String, _slot: int, _at: Vector3, node: Node3D) -> void:
	remove_node(node)


static func _sort_by_rate(list: Array) -> void:
	var order := {}
	for i in list.size():
		order[(list[i] as AiTrack).id] = i
	list.sort_custom(
		func(a: AiTrack, b: AiTrack) -> bool:
			if a.cached_rate != b.cached_rate:
				return a.cached_rate > b.cached_rate
			return int(order[a.id]) < int(order[b.id])
	)
