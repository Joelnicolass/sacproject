class_name AiPerception
extends Node

## What one AI side knows (RFC-024 §3.1 `AiPerception`; shiny.d:1129-1200, 1289-1300, 1373-1400, 616-635 `botSeen`).
## - At the start (`scan_global`, once, shiny.d:1175-1183) it takes in every structure, wizard and creature of the map:
##   the enemy altar, the enemy creatures and the NPC of the villages (Farmers and Taurocks), the way
##   thaum.exe did (`config is 0x10 at all three AI-creation call sites`, shiny.d:1158).
## - After that it adds its own bodies when they appear and an enemy body only when its side SEES it (SideVision.marked,
##   shiny.d:616-635), and removes what dies (shiny.d:563-566). A foe it has not seen keeps the position it had when it
##   was taken in: updateBase only follows own bodies and the ones flagged «seen» (shiny.d:1025), and the flag comes from discover (1373).
## - It only follows what lies in the wizard's own region of the pathfinder (`shouldTrack`, shiny.d:754-775).
## The audit reads `leak_count()`: tracks that are neither from the start nor own nor ever seen (RFC §6: `unseen_leaks`).
## 024e: `perfect_information` (AiDifficulty). On (Hard, the original) the AI reads the real position, health and mana of every body it
## knows, seen or not (shiny.d:1710-1711, healthPair). Off (Easy, Normal; a deviation in Normal decided by the user) a body of
## another side that the side does not see now (`sees`) keeps what was seen last: the position where it was (and one step of
## extrapolation), its health and mana of that moment. Every read goes through `pos_of`, `health_of`, `mana_of`; `unseen_reads`
## counts the reads of the real state of an unseen body (only possible with perfect information).
## Runs in the physics frames of AiSide; takes no decisions.

signal forced(bits: int)
signal tracked(track: AiTrack)
signal untracked(track: AiTrack)

## BLDG header flags of the structures the AI looks at (cache/data/buildings.json: altars `ca_a`…, founts `jfnt`…,
## Manaliths `jman`…; equal for the five gods). The word `unknown1[3]` that gates READY is not exported: READY is
## given to a mana structure with no structure on top («aprox.»).
const BLDG_ALTAR := 0x1407
const BLDG_FOUNT := 0x2810
const BLDG_MANALITH := 0x55a0
const MANALITH_TAG := "htlm"
const MAHO_TAG := "oham"

@export var profile: AiProfile
## Set by AiSide from the difficulty (024e).
@export var perfect_information := false

var slot := 0
## The AI's own wizard (set by AiSide).
var wizard: Node3D
var tracks: Dictionary = {}
var scanned := false
## stats of updateStats (shiny.d:1243-1262), for the stance and (024d) the capture task.
var neutral_founts := 0
var max_souls_seen := 0
## Reads of the real position, health or mana of a body of another side its side did not see (perfect information only).
var unseen_reads := 0
## Bodies forgotten because the side looked where they were and they were not there (no perfect information).
var forgotten := 0
var _lost: Dictionary = {}

var _bodies: Array = [[], [], [], []]
var _structures: Array = [[], [], [], []]
var _vision: SideVision
var _nav: NavService
var _tag_accs: Dictionary = {}
var _sacrifice: SacrificeSystem
var _soul_tracks: Dictionary = {}


func _ready() -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		set_process(false)


func vision() -> SideVision:
	if _vision == null or not is_instance_valid(_vision):
		_vision = get_tree().get_first_node_in_group(SideVision.GROUP) as SideVision
		if _vision != null and not _vision.marked.is_connected(_on_marked):
			_vision.marked.connect(_on_marked)
	return _vision


func nav() -> NavService:
	if _nav == null or not is_instance_valid(_nav):
		_nav = get_tree().get_first_node_in_group(NavService.GROUP) as NavService
	return _nav


## setup (shiny.d:659-669) plus the vision hook: the AI starts to listen to what its side sees.
func begin() -> void:
	vision()


## scanGlobal (shiny.d:1175-1183): add-if-unknown every structure, then every wizard and creature of the map.
func scan_global() -> void:
	scanned = true
	for group in [Altar.GROUP, &"manafount", &"structure"]:
		for node in get_tree().get_nodes_in_group(group):
			add_node(node as Node3D, &"scan")
	for group in [&"wizard", &"unit"]:
		for node in get_tree().get_nodes_in_group(group):
			add_node(node as Node3D, &"scan")
	print("ia slot %d: escaneo inicial %d propios, %d aliados, %d neutrales, %d enemigos" % [slot, tracks_of(0).size(), tracks_of(1).size(), tracks_of(2).size(), tracks_of(3).size()])
	forced.emit(1)


## One of its own bodies appeared (botSpawned, shiny.d:575-584) or a foe was seen (botSeen).
func add_node(node: Node3D, origin: StringName = &"event") -> AiTrack:
	if node == null or not is_instance_valid(node):
		return null
	var id := node.get_instance_id()
	if tracks.has(id):
		return tracks[id]
	var kind := kind_of(node)
	if kind == AiTrack.Kind.NONE or not _should_track(node, kind):
		return null
	var t := AiTrack.new()
	t.kind = kind
	t.node = node
	t.id = id
	t.origin = origin
	_setup(t)
	tracks[id] = t
	_list_of(t).append(t)
	## A body forgotten (024e) and known again keeps its connection: connect only once.
	if kind == AiTrack.Kind.CRE or kind == AiTrack.Kind.MAHO:
		var on_died := _on_unit_died.bind(node)
		if not node.is_connected("died", on_died):
			node.connect("died", on_died)
	elif kind == AiTrack.Kind.STR and node.has_signal("state_changed"):
		var on_state := _on_altar_state.bind(node)
		if not node.is_connected("state_changed", on_state):
			node.connect("state_changed", on_state)
	tracked.emit(t)
	## addNode itself forces the replan (shiny.d:975); a body of the side appearing (AddToSide) also asks for the stats (3, shiny.d:536).
	forced.emit(3 if origin == &"event" else 1)
	return t


func remove_node(node: Node3D) -> void:
	if node == null:
		return
	var id := node.get_instance_id()
	var t: AiTrack = tracks.get(id)
	if t == null:
		return
	_erase(t)


func _erase(t: AiTrack) -> void:
	tracks.erase(t.id)
	_list_of(t).erase(t)
	untracked.emit(t)
	forced.emit(1)


func find(node: Node) -> AiTrack:
	return tracks.get(node.get_instance_id()) if node != null else null


static func kind_of(node: Node) -> AiTrack.Kind:
	if node.is_in_group(&"wizard"):
		return AiTrack.Kind.WIZ
	if node.is_in_group(&"unit"):
		var type: Variant = node.get("type")
		if type != null and (type as CreatureType).tag == MAHO_TAG:
			return AiTrack.Kind.MAHO
		return AiTrack.Kind.CRE
	if node.is_in_group(Altar.GROUP) or node.is_in_group(&"manafount"):
		return AiTrack.Kind.STR
	if node.is_in_group(&"structure") and not node.is_in_group(MapBuilding.GROUP) and str(node.get("spell_tag")) == MANALITH_TAG:
		return AiTrack.Kind.STR
	return AiTrack.Kind.NONE


## relation (shiny.d:739-745): 0 own, 1 ally, 2 neutral, 3 enemy.
func relation_of(node: Node) -> int:
	var other := owner_slot_of(node)
	if other == slot:
		return 0
	if SideRelations.stance(slot, other) == SideRelations.Stance.ALLY or SideRelations.stance(other, slot) == SideRelations.Stance.ALLY:
		return 1
	if SideRelations.stance(slot, other) == SideRelations.Stance.ENEMY or SideRelations.stance(other, slot) == SideRelations.Stance.ENEMY:
		return 3
	return 2


static func owner_slot_of(node: Node) -> int:
	var value: Variant = node.get("owner_slot")
	return int(value) if value != null else 0


## shouldTrack (shiny.d:754-775): the body must lie in the wizard's pathfinder region and not be dead.
func _should_track(node: Node3D, kind: AiTrack.Kind) -> bool:
	var service := nav()
	if wizard != null and is_instance_valid(wizard) and service != null and service.is_ready():
		if not service.same_region(wizard.global_position, node.global_position):
			return false
	if kind == AiTrack.Kind.STR:
		return true
	return not _is_dead(node)


static func _is_dead(node: Node) -> bool:
	return node.has_method("is_dead") and bool(node.call("is_dead"))


func _setup(t: AiTrack) -> void:
	var relation := relation_of(t.node)
	t.flags = [AiTrack.OWN, AiTrack.ALLY, 0, AiTrack.ENEMY][relation]
	if relation == 0:
		t.age_seen = 0
	var here := t.node.global_position
	t.cur_pos = here
	t.prev_pos = here
	t.extrap_pos = here
	if t.is_body():
		_snapshot(t)
	match t.kind:
		AiTrack.Kind.WIZ:
			t.flags |= AiTrack.BODY | 0x40 | AiTrack.WIZARD
			t.status = AiTrack.WIZARD_STATUS | AiTrack.ACTIVE
			t.min_mana_cost = float(AiRater.ftol(_mana_max(t.node)) / 4)
			t.spell_dirty = true
			_rate(t)
		AiTrack.Kind.CRE, AiTrack.Kind.MAHO:
			t.flags |= AiTrack.BODY | 0x40
			var type := t.node.get("type") as CreatureType
			if type != null and (_ability_count(type) > 0 or type.aggressiveness != 0):
				t.status |= AiTrack.ACTIVE
			## setupT4oBody (shiny.d:892-900): the mana below which a creature with abilities goes to a source to recharge
			## (the Manahoar has none: setupMaho). 024d (autoCapture).
			if t.kind == AiTrack.Kind.CRE and type != null:
				t.min_mana_cost = float(AiRater.ftol(_mana_max(t.node))) if _ability_count(type) > 0 else 0.0
				for ability_tag in type.ability_tags:
					if ability_tag == "":
						continue
					var ability := GameData.ability(ability_tag)
					if ability != null and float(ability.mana_cost) < t.min_mana_cost:
						t.min_mana_cost = float(ability.mana_cost)
			_rate(t)
		AiTrack.Kind.STR:
			t.flags |= AiTrack.STRUCTURE
			var bfl := _bldg_flags(t.node)
			if bfl & 1:
				t.flags |= 0x300
			if bfl & 0xc17:
				t.flags |= AiTrack.CAPTURABLE
			_status_of_structure(t)


## The abilities the CRE8 really has: the tags of export_stats.py keep empty slots (shiny.d:891-894 counts the non-null ones).
static func _ability_count(type: CreatureType) -> int:
	var n := 0
	for tag in type.ability_tags:
		if tag != "":
			n += 1
	return n


func _bldg_flags(node: Node) -> int:
	if node.is_in_group(&"manafount"):
		return BLDG_FOUNT
	if node.is_in_group(Altar.GROUP):
		return BLDG_ALTAR
	return BLDG_MANALITH


func _status_of_structure(t: AiTrack) -> void:
	var bfl := _bldg_flags(t.node)
	var top_free := true
	if t.node.is_in_group(&"manafount"):
		top_free = bool(t.node.call("is_free"))
		if (bfl & 0x10) and top_free:
			t.status |= AiTrack.UNBUILT
		else:
			t.status &= ~AiTrack.UNBUILT
	if top_free and (bfl & 0xc00):
		t.status |= AiTrack.READY
	else:
		t.status &= ~AiTrack.READY
	if bfl & 0x4000:
		t.status |= AiTrack.MANALITH
	else:
		t.status &= ~AiTrack.MANALITH
	if bfl & 2:
		t.status |= 0x40000
	else:
		t.status &= ~0x40000


## The current mana and the file stats a body is rated by.
func _rate(t: AiTrack) -> void:
	var node := t.node
	var abilities: Array = []
	var spells: Array = []
	var ts: Dictionary
	if t.kind == AiTrack.Kind.WIZ:
		ts = AiRater.WIZARD_STATS
		var book := node.get_node_or_null("Spellbook")
		if book != null:
			for i in int(book.call("size")):
				spells.append(book.call("spell_at", i))
	else:
		var type := node.get("type") as CreatureType
		if type == null:
			return
		ts = AiRater.stats_of(type)
		for tag in type.ability_tags:
			if tag != "":
				abilities.append(GameData.ability(tag))
	t.acc = AiRater.fill_from_object(ts, mana_of(t).x, abilities, spells)
	t.cached_rate = AiRater.rate(t.acc)


## fillByTag cache (shiny.d:392-405 `tagAcc`): what a creature a wizard may summon is worth.
func tag_acc(tag: String) -> PackedFloat32Array:
	if _tag_accs.has(tag):
		return _tag_accs[tag]
	var type := GameData.creature(tag)
	var abilities: Array = []
	if type != null:
		for ability_tag in type.ability_tags:
			if ability_tag != "":
				abilities.append(GameData.ability(ability_tag))
	var acc := AiRater.fill_by_tag(type, abilities) if type != null else AiRater.new_acc()
	_tag_accs[tag] = acc
	return acc


static func _mana_now(node: Node) -> float:
	var pool := node.get_node_or_null("ManaPool")
	return float(pool.get("current")) if pool != null else 0.0


static func _mana_max(node: Node) -> float:
	var pool := node.get_node_or_null("ManaPool")
	return float(pool.get("maximum")) if pool != null else 0.0


## (current, maximum) of health, shiny.d:2715-2722 `healthPair`.
static func health_pair(t: AiTrack) -> Vector2i:
	var health := t.node.get_node_or_null("Health")
	if health == null:
		return Vector2i.ZERO
	return Vector2i(AiRater.ftol(float(health.get("current"))), AiRater.ftol(float(health.get("maximum"))))


## updateNtts (shiny.d:1289-1297; the soul snapshot of updateWiz, shiny.d:1080-1083, is read for the own wizard only: sacengine
## reads the enemy wizard's too, without seeing him, and the port does not): drops what no longer exists, updates the rest. `dt` = ticks since the last run.
func update_nodes(dt: int) -> void:
	if _soul_tracks.size() > 64:
		for id in _soul_tracks.keys():
			if not (_soul_tracks[id] as AiTrack).is_valid():
				_soul_tracks.erase(id)
	for t: AiTrack in tracks.values():
		if not t.is_valid() or (t.kind != AiTrack.Kind.WIZ and t.is_body() and _is_dead(t.node)):
			_erase(t)
			continue
		_update_node(t, dt)
	if not perfect_information:
		_forget_checked()
		_recall_seen()


## 024e, without perfect information: a body of another side that the side does not see now, whose last known place lies inside the
## sight of one of the side's own bodies, is not there any more (it would have been marked): the AI forgets it until its side sees it
## again (else a group seen near the wizard and gone stays there for good and keeps his threat up). The original never needs it: it
## reads the real position (Hard keeps that rule).
func _forget_checked() -> void:
	var service := vision()
	if service == null:
		return
	var lookers: Array = []
	for own: AiTrack in bodies(0):
		if own.is_valid():
			var sight := service.sight_of(own.node)
			if sight > 0.0:
				lookers.append([own.node.global_position, sight * sight])
	if lookers.is_empty():
		return
	var gone: Array[AiTrack] = []
	for k in [1, 2, 3]:
		for t: AiTrack in _bodies[k]:
			if not t.is_valid() or sees(t):
				continue
			for looker: Array in lookers:
				var at: Vector3 = looker[0]
				if Vector2(t.cur_pos.x - at.x, t.cur_pos.z - at.z).length_squared() <= float(looker[1]):
					gone.append(t)
					break
	for t in gone:
		_lost[t.id] = t.node
		forgotten += 1
		_erase(t)


## A forgotten body the side sees again is known again (botSeen).
func _recall_seen() -> void:
	if _lost.is_empty():
		return
	var service := vision()
	for id in _lost.keys():
		## Variant: the body may have been freed since (a typed Node3D would not take a freed instance)
		var held: Variant = _lost[id]
		if not is_instance_valid(held) or _is_dead(held as Node3D):
			_lost.erase(id)
			continue
		var node := held as Node3D
		if service != null and service.is_visible_to(slot, node):
			_lost.erase(id)
			var t := add_node(node, &"seen")
			if t != null:
				t.flags |= AiTrack.SEEN


## updateBase (shiny.d:1024-1038): own and seen bodies follow the real position. Without perfect information (024e) a seen body that
## the side does not see now stays where it was seen last, one step of its last velocity ahead.
func _update_base(t: AiTrack, dt: int) -> void:
	if not (t.flags & (AiTrack.OWN | AiTrack.SEEN)):
		return
	t.age += dt
	if not knows_live(t):
		t.frozen = true
		t.extrap_pos = t.cur_pos + t.velocity
		return
	var p := t.node.global_position
	if t.frozen:
		## seen again: it does not jump from where it was last seen
		t.frozen = false
		t.prev_pos = p
	t.cur_pos = p
	t.velocity = p - t.prev_pos
	if dt != 0:
		t.velocity /= float(dt)
	t.prev_pos = p
	t.extrap_pos = p + t.velocity


func _update_node(t: AiTrack, dt: int) -> void:
	_update_base(t, dt)
	if t.is_body() and not (t.flags & AiTrack.OWN) and sees(t):
		_snapshot(t)
	match t.kind:
		AiTrack.Kind.CRE, AiTrack.Kind.MAHO, AiTrack.Kind.WIZ:
			if t.age >= t.rerate_tick:
				t.rerate_tick = t.age + profile.rerate_ticks
				_rate(t)
			if t.kind == AiTrack.Kind.MAHO and t.age >= t.status_tick:
				t.status_tick = t.age + profile.status_ticks
				if _maho_ready(t.node):
					t.status |= AiTrack.READY
				else:
					t.status &= ~AiTrack.READY
			if t.kind == AiTrack.Kind.WIZ and (t.flags & AiTrack.OWN) and t.age >= t.souls_snap_tick:
				t.souls_snap_tick = t.age + profile.souls_snapshot_ticks
				var purse := t.node.get_node_or_null("SoulPurse")
				if purse != null:
					t.souls_snap = int(purse.get("count"))
		AiTrack.Kind.STR:
			if t.age >= t.status_tick:
				t.status_tick = t.age + profile.status_ticks
				_status_of_structure(t)


## manahoarAbilityEnabled: it works while it is not dead, not being summoned and not held.
static func _maho_ready(node: Node) -> bool:
	if node.has_method("is_dead") and node.call("is_dead"):
		return false
	if node.has_method("is_summoning") and node.call("is_summoning"):
		return false
	return not (node.has_method("is_taken") and node.call("is_taken"))


## discover (shiny.d:1373-1400) for what it does here: bodies it has seen get the «seen» flag so updateBase follows
## them; ghost wizards and dead bodies go.
func discover() -> void:
	var service := vision()
	for t: AiTrack in tracks.values():
		if not t.is_valid():
			_erase(t)
			continue
		if t.flags & AiTrack.OWN:
			continue
		if t.kind == AiTrack.Kind.WIZ and bool(t.node.call("is_ghost")):
			_erase(t)
			continue
		if _is_dead(t.node):
			_erase(t)
			continue
		if service != null and service.last_seen_tick(slot, t.node) >= 0 and not (t.flags & AiTrack.SEEN):
			t.flags |= AiTrack.SEEN
			t.age_seen = t.age


## updateStats (shiny.d:1243-1262): what the side has seen of souls and of free founts.
func update_stats() -> void:
	var souls := 0
	for t: AiTrack in tracks.values():
		if t.kind == AiTrack.Kind.WIZ:
			souls += t.mana_snap + t.souls_snap
	max_souls_seen = maxi(max_souls_seen, souls)
	neutral_founts = 0
	for t in structures(2):
		if (t.status & AiTrack.UNBUILT) and t.node.is_in_group(&"manafount"):
			neutral_founts += 1


## The bodies (wizards, creatures, Manahoars) of a category, in the order of the list `fam1`: sorted by worth at
## every replan (sort_bodies), new ones at the tail.
func bodies(category: int) -> Array:
	return _bodies[category]


func structures(category: int) -> Array:
	return _structures[category]


## catHead[k] of shiny.d: everything of a category, bodies and structures, in the order it was taken in.
func tracks_of(category: int) -> Array:
	var out: Array = []
	for t: AiTrack in tracks.values():
		if t.category() == category:
			out.append(t)
	return out


func _list_of(t: AiTrack) -> Array:
	return _bodies[t.category()] if t.is_body() else _structures[t.category()]


## sortFam1 (shiny.d:1651-1672): stable, best worth first (the sort key is the cached rate).
func sort_bodies() -> void:
	for k in 4:
		var list: Array = _bodies[k]
		var order := {}
		for i in list.size():
			order[(list[i] as AiTrack).id] = i
		list.sort_custom(func(a: AiTrack, b: AiTrack) -> bool:
			if a.cached_rate != b.cached_rate:
				return a.cached_rate > b.cached_rate
			return int(order[a.id]) < int(order[b.id]))


## botDeath (shiny.d:563-566): a creature that dies leaves every AI at once. UnitBody.died(tag, slot, at).
func _on_unit_died(_tag: String, _slot: int, _at: Vector3, node: Node3D) -> void:
	remove_node(node)


func _on_altar_state(_state: int, node: Node3D) -> void:
	if not (node as Altar).is_standing():
		remove_node(node)


## SideVision: the side saw `node` (botSeen, shiny.d:616-635): own bodies are tracked by their own events.
func _on_marked(side: int, node: Node3D) -> void:
	if side != slot or tracks.has(node.get_instance_id()):
		return
	add_node(node, &"seen")


## Tracks the audit calls a leak: neither from the start nor own, and no mark of the side's vision behind them.
func leak_count() -> int:
	var service := vision()
	var leaks := 0
	for t: AiTrack in tracks.values():
		if t.origin == &"scan" or (t.flags & AiTrack.OWN):
			continue
		if service == null or not t.is_valid() or service.last_seen_tick(slot, t.node) < 0:
			leaks += 1
	return leaks


# ---- 024e: what the AI knows of a body (perfect information or the last it saw) ----

## The side sees `t` now: its own and its allies' bodies, structures and souls always (structures stand still and are marked for good
## once seen; souls are not gated in the original either, shiny.d:583); a body of another side while SideVision.is_visible_to holds
## (384 ticks after its last mark: the rule the creatures pick their targets by).
func sees(t: AiTrack) -> bool:
	if t == null or (t.flags & (AiTrack.OWN | AiTrack.ALLY)) or not t.is_body():
		return true
	var service := vision()
	return service == null or service.is_visible_to(slot, t.node)


## The AI may read the real state of `t`: perfect information, or the side sees it.
func knows_live(t: AiTrack) -> bool:
	return perfect_information or sees(t)


## Where the AI believes `t` is: the real position when it knows it live, else where it was seen last.
func pos_of(t: AiTrack) -> Vector3:
	if not knows_live(t):
		return t.cur_pos
	_count_read(t)
	return t.node.global_position


## (current, maximum) health the AI believes `t` has.
func health_of(t: AiTrack) -> Vector2i:
	if not knows_live(t):
		return t.seen_health
	_count_read(t)
	return health_pair(t)


## (current, maximum) mana the AI believes `t` has.
func mana_of(t: AiTrack) -> Vector2i:
	if not knows_live(t):
		return t.seen_mana
	_count_read(t)
	return AiGroups._mana_pair(t)


func _count_read(t: AiTrack) -> void:
	if perfect_information and t.is_body() and not (t.flags & (AiTrack.OWN | AiTrack.ALLY)) and not sees(t):
		unseen_reads += 1


func _snapshot(t: AiTrack) -> void:
	t.seen_health = health_pair(t)
	t.seen_mana = AiGroups._mana_pair(t)


func foes_count() -> int:
	return bodies(3).size()


# ---- 024d: souls, rituals and the altars, as the original reads them ----

## The system that owns the rules of the rituals (Convert and Desecrate).
func sacrifice() -> SacrificeSystem:
	if _sacrifice == null or not is_instance_valid(_sacrifice):
		_sacrifice = get_tree().get_first_node_in_group(SacrificeSystem.GROUP) as SacrificeSystem
	return _sacrifice


## A track for a soul (the original follows the souls too, ungated: shiny.d:1358-1369, 583). Kind NONE: it only carries the node and
## where it is, so the cast queue and the orders can aim at it like at any other target.
func soul_track(soul: Node3D) -> AiTrack:
	var id := soul.get_instance_id()
	var t: AiTrack = _soul_tracks.get(id)
	if t == null:
		t = AiTrack.new()
		t.kind = AiTrack.Kind.NONE
		t.node = soul
		t.id = id
		t.origin = &"soul"
		_soul_tracks[id] = t
	t.cur_pos = soul.global_position
	t.extrap_pos = t.cur_pos
	return t


## findBestNear (shiny.d:3005-3024, retail 0x485490): the soul within `radius` of `pos` that weighs most (1 on top of it, falling
## linearly to 0 at `radius`; strict argmax, the first one wins a tie). `pickup` asks for the souls this side can take by
## touching them (the wizard walks onto them); else for the ones it cannot but can convert (the red ones in the open, with the
## rules of the Convert cast, so the AI does not ask for what the game would answer «Blanco inválido»).
func find_best_near(pos: Vector3, radius: float, pickup: bool) -> AiTrack:
	var best := 0.0
	var best_soul: Node3D
	var system := sacrifice()
	var service := nav()
	for node in get_tree().get_nodes_in_group(&"soul"):
		var soul := node as Soul
		if soul == null or not is_instance_valid(soul) or soul.is_queued_for_deletion():
			continue
		if pickup:
			if not soul.can_be_collected_by(slot):
				continue
		elif system == null or not system.convert_status(slot, soul).is_empty():
			continue
		if service != null and service.is_ready() and not service.same_region(pos, soul.global_position):
			continue
		var d := pos.distance_to(soul.global_position)
		var w := 0.0
		if d <= 0.0:
			w = 1.0
		elif d < radius:
			w = AiField.safediv(radius - d, radius)
		if best < w:
			best = w
			best_soul = soul
	return soul_track(best_soul) if best_soul != null else null


## desecrationOngoing (shiny.d:3079-3085) for the altar `altar_track`: a Desecrate cast, carrier or ritual against that altar's side.
func desecration_against(altar_track: AiTrack) -> bool:
	var system := sacrifice()
	return system != null and altar_track != null and system.desecration_against(owner_slot_of(altar_track.node))


## wizardSacrificing / the `ucas` attachment of the AI's own wizard (shiny.d:3096, 2264).
func own_desecration() -> bool:
	var system := sacrifice()
	return system != null and system.desecration_by(slot)


## The wizard has a standing altar of his own (closestShrine != 0, shiny.d:3100): where a Convert takes the creature.
func has_home_altar() -> bool:
	var system := sacrifice()
	return system != null and wizard != null and system.closest_own_altar(slot, wizard.global_position) != null


## closestEnemyAltar of the wizard (shiny.d:3358): the enemy altar within the Desecrate range, as the game defines it.
func closest_enemy_altar_in_range() -> Node3D:
	var system := sacrifice()
	if system == null or wizard == null:
		return null
	var rules: MatchRules = system.rules
	return system.closest_enemy_altar(slot, wizard.global_position, rules.desecrate_altar_range if rules != null else 75.0)
