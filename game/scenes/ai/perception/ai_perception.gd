@tool
class_name AiPerception
extends Node

## The bodies one AI side knows and what each is to it (own, ally, neutral, enemy): the index the rest of the AI reads. At the start
## it takes in every structure and wizard, its own and allied creatures and, with SIGHT_AND_MAP, the others on its minimap; then its
## own bodies as they appear, a foe once its side sees it (SightIntake), and it drops what dies. What it believes of an unseen body
## is Belief's, the souls Souls', the rituals AiRituals'. It takes no decisions.
## Ref: shiny.d:1129-1200 scanGlobal (0x10, 1158), 575-584, 563-566, 1289-1300, 1373-1400, 975, 536.; shiny.d:1243-1262

signal forced(bits: int)
signal tracked(track: AiTrack)
signal untracked(track: AiTrack)

var play: AiPlay  # what the side plays with (AiSide.setup)
## The passive that makes a creature a Manahoar for the AI (data/catalog/abilities/hmba.tres, the one UnitManaSupport.source uses).
@export var mana_source: AbilityType
@export var intake: AiSightIntake
@export var belief: AiBelief
@export var souls: AiSouls

var slot := 0
var wizard: Node3D  ## the AI's own wizard (set by AiSide)
var tracks: Dictionary = {}
var scanned := false
## What the side has seen of souls and of free founts (the stance and the capture task read them).
var neutral_founts := 0
var max_souls_seen := 0
var unseen_reads: int:
	get: return belief.unseen_reads if belief != null else 0
var forgotten: int:
	get: return intake.forgotten if intake != null else 0

var _bodies: Array = [[], [], [], []]
var _structures: Array = [[], [], [], []]
var _nav: NavService
var _sacrifice: SacrificeSystem

func _get_configuration_warnings() -> PackedStringArray:
	var missing := PackedStringArray()
	for pair: Array in [[mana_source, "mana_source (hmba.tres)"], [intake, "intake"], [belief, "belief"], [souls, "souls"]]:
		if pair[0] == null: missing.append("Falta `%s`: sin él la IA no ve, no recuerda o no reconoce al Manahoar." % pair[1])
	return missing

func nav() -> NavService:
	if _nav == null or not is_instance_valid(_nav): _nav = get_tree().get_first_node_in_group(NavService.GROUP) as NavService
	return _nav

func sacrifice() -> SacrificeSystem:
	if _sacrifice == null or not is_instance_valid(_sacrifice): _sacrifice = get_tree().get_first_node_in_group(SacrificeSystem.GROUP) as SacrificeSystem
	return _sacrifice

func scan_global() -> void:
	scanned = true
	for group in [Altar.GROUP, &"manafount", &"structure", &"wizard", &"unit"]:
		for node in get_tree().get_nodes_in_group(group):
			if group == &"unit" and relation_of(node) > AiTrack.Relation.ALLY and not belief.within_map(node as Node3D): continue
			add_node(node as Node3D, &"scan")
	if DebugLog.on(&"ai_seat"): print("ia slot %d: escaneo inicial %d propios, %d aliados, %d neutrales, %d enemigos" % [slot, tracks_of(0).size(), tracks_of(1).size(), tracks_of(2).size(), tracks_of(3).size()])
	forced.emit(1)

## One of its own bodies appeared, or a foe was seen. A body of the side appearing also asks for the stats.
func add_node(node: Node3D, origin: StringName = &"event") -> AiTrack:
	if node == null or not is_instance_valid(node):
		return null
	var id := node.get_instance_id()
	if tracks.has(id):
		return tracks[id]
	var kind := AiTrackFacts.kind_of(node, mana_source)
	if kind == AiTrack.Kind.NONE or not AiTrackUpkeep.should_track(node, kind, wizard, nav()):
		return null
	var t := AiTrackFacts.make(node, kind, origin, self)
	tracks[id] = t
	_list_of(t).append(t)
	AiTrackUpkeep.watch(t, _on_unit_died.bind(node), _on_altar_state.bind(node))
	tracked.emit(t)
	forced.emit(3 if origin == &"event" else 1)
	return t

func remove_node(node: Node3D) -> void:
	var t: AiTrack = tracks.get(node.get_instance_id()) if node != null else null
	if t != null: _erase(t)

func _erase(t: AiTrack) -> void:
	tracks.erase(t.id)
	_list_of(t).erase(t)
	untracked.emit(t)
	forced.emit(1)

## Drops what no longer exists and updates the rest, `dt` ticks after the last run; it forgets what is not where it was seen and
## knows again what its side sees again.
func update_nodes(dt: int) -> void:
	if souls != null: souls.prune()
	for t: AiTrack in tracks.values():
		if not t.is_valid() or (t.kind != AiTrack.Kind.WIZARD and t.is_body() and AiBody.is_dead(t.node)):
			_erase(t)
			continue
		_update_node(t, dt)
	if intake != null:
		for t in intake.forget_checked(_bodies, slot, belief): _erase(t)
		for node in intake.take_recalled(slot):
			var t := add_node(node, &"seen")
			if t != null: t.seen = true

func _update_node(t: AiTrack, dt: int) -> void:
	belief.follow(t, dt, slot)
	if t.is_body() and t.relation != AiTrack.Relation.OWN and sees(t): belief.snapshot(t, slot)
	AiTrackUpkeep.upkeep(t, self)

## Takes in what the side sees and does not track yet; marks «seen» (followed from now on) what it sees; ghosts and dead bodies go.
func discover() -> void:
	if intake != null:
		for node in intake.take_new(slot, tracks): add_node(node, &"seen")
	for t: AiTrack in tracks.values():
		if not t.is_valid() or (t.relation != AiTrack.Relation.OWN and ((t.kind == AiTrack.Kind.WIZARD and (t.node as WizardBody).is_ghost()) or AiBody.is_dead(t.node))):
			_erase(t)
		elif t.relation != AiTrack.Relation.OWN and not t.seen and VisionSides.sees(slot, t.node):
			t.seen = true
			t.age_seen = t.age

func _on_altar_state(_state: int, node: Node3D) -> void:
	if not (node as Altar).is_standing(): remove_node(node)

func _on_unit_died(_tag: String, _slot: int, _at: Vector3, node: Node3D) -> void: remove_node(node)
func _list_of(t: AiTrack) -> Array: return _bodies[t.category()] if t.is_body() else _structures[t.category()]
## Stable, best worth first (the key is the cached rate); the lists keep this order until the next replan.
func sort_bodies() -> void: AiTrackUpkeep.sort_lists(_bodies)
func update_stats() -> void: AiTrackUpkeep.update_stats(self)

# ---- Reads: the lists, and what the AI believes (Belief), the souls (Souls) and the rituals (AiRituals) ----
func find(node: Node) -> AiTrack: return tracks.get(node.get_instance_id()) if node != null else null
func bodies(category: int) -> Array: return _bodies[category]
func structures(category: int) -> Array: return _structures[category]
func tracks_of(category: int) -> Array: return tracks.values().filter(func(t: AiTrack) -> bool: return t.category() == category)
func foes_count() -> int: return bodies(3).size()
func relation_of(node: Node) -> AiTrack.Relation: return AiTrackFacts.relation(slot, owner_slot_of(node))
static func owner_slot_of(node: Node) -> int: return VisionRules.slot_of(node)
func tag_acc(type: CreatureType) -> PackedFloat32Array: return AiTrackFacts.tag_acc(type)
func leak_count() -> int: return AiSightIntake.leak_count(tracks, slot)
func sees(t: AiTrack) -> bool: return AiBelief.sees(t, slot)
func knows_live(t: AiTrack) -> bool: return belief.knows_live(t, slot)
func knows_where(t: AiTrack) -> bool: return belief.knows_where(t, slot)
func pos_of(t: AiTrack) -> Vector3: return belief.pos_of(t, slot)
func health_of(t: AiTrack) -> Vector2i: return belief.health_of(t, slot)
func mana_of(t: AiTrack) -> Vector2i: return belief.mana_of(t, slot)
func find_best_near(pos: Vector3, radius: float, pickup: bool) -> AiTrack: return souls.find_best_near(pos, radius, pickup, slot, sacrifice(), nav()) if souls != null else null
func desecration_against(altar_track: AiTrack) -> bool: return AiRituals.desecration_against(sacrifice(), altar_track)
func own_desecration() -> bool: return AiRituals.own_desecration(sacrifice(), slot)
func has_home_altar() -> bool: return AiRituals.has_home_altar(sacrifice(), slot, wizard)
func closest_enemy_altar_in_range() -> Node3D: return AiRituals.closest_enemy_altar_in_range(sacrifice(), slot, wizard)
