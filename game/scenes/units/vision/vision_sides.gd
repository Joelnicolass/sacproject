class_name VisionSides
extends RefCounted

## What a whole side sees: the union of what the Visions of its bodies remember (and of its allies'
## when the match shares sight). It keeps no marks of its own, only the list of live Visions and a
## cache of the union for the current tick; the marks live in each Vision. It does not choose
## targets (TargetPicker) nor decide what the AI knows (AiPerception): both ask it.

## Where the Visions announce what they learn (VisionMemory emits `learned`).
static var events := VisionEvents.new()
static var _visions: Array[Vision] = []
## Bumped whenever a Vision joins, leaves or marks something, so the cached union of the same tick
## is rebuilt.
static var _version := 0
## side -> [tick, version, ids]: the union of that side, valid while tick and version are the same.
static var _cache: Dictionary = {}
## slot -> {id -> 0 not a foe, 1 a foe, 2 a foe that never moves}, for the tick `_kind_tick`: asked
## once per body and tick.
static var _kinds: Dictionary = {}
static var _kind_tick := -1


static func join(vision: Vision) -> void:
	_visions.append(vision)
	_version += 1


static func leave(vision: Vision) -> void:
	_visions.erase(vision)
	_version += 1


## Something changed in a Vision: the cached unions are stale.
static func touch() -> void:
	_version += 1


## The Vision of a body (UnitBody, WizardBody, the Divine Sight eye), or null for one without eyes
## (a structure).
static func of(node: Node) -> Vision:
	return node.get("vision") as Vision if node != null else null


## Whether `side` sees `node` now: its own bodies always, a foe while a Vision of the side (or of an
## ally that shares) remembers it.
static func sees(side: int, node: Node3D) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	return VisionRules.slot_of(node) == side or known(side).has(node.get_instance_id())


## The foes (and founts) `side` remembers, sorted by name. The AI adds the new ones to what it
## knows.
static func seen_by(side: int) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for id: int in known(side):
		var node := instance_from_id(id) as Node3D
		if node != null and node.is_inside_tree():
			found.append(node)
	found.sort_custom(VisionRules.by_name)
	return found


## Every body some live Vision has in mind (lapsed or not) and every body some side saw strike, in
## no order: what a listener of `events` that starts late has missed.
static func remembered() -> Array[Node3D]:
	var found: Array[Node3D] = []
	for vision in _visions:
		for id: int in vision.memory.held_ids():
			var node := instance_from_id(id) as Node3D
			if node != null:
				found.append(node)
		if vision.memory.has_exposures() and vision.body != null:
			found.append(vision.body)
	return found


## `attacker` hurt `victim`: the victim's side sees the attacker for a while, and the victim
## remembers who hurt it.
static func reveal(attacker: Node3D, victim: Node3D) -> void:
	if attacker == null or victim == null:
		return
	var eyes := of(attacker)
	var side := VisionRules.slot_of(victim)
	if eyes != null and side > 0:
		eyes.expose_to(side)
	var hurt := of(victim)
	if hurt != null:
		hurt.hurt_by.emit(attacker)


## What `node` is for the Vision of side `mine`: 0 not worth remembering, 1 a foe, 2 a foe that
## stands for good (structure, mana fount).
static func mark_kind(mine: int, node: Node3D, observer: Node3D) -> int:
	var now := MatchClock.now()
	if now != _kind_tick:
		_kind_tick = now
		_kinds.clear()
	var of_slot: Dictionary = _kinds.get(mine, {})
	_kinds[mine] = of_slot
	var id := node.get_instance_id()
	if not of_slot.has(id):
		var fount := node.is_in_group(ManafountBody.GROUP)
		var kind := 0
		if fount or TargetRules.is_valid_foe_of(mine, node, observer):
			kind = 2 if fount or node.is_in_group(MapBuilding.STRUCTURE_GROUP) else 1
		of_slot[id] = kind
	return of_slot[id]


## The ids `side` knows now. Kept while no Vision learned a new foe and nothing has lapsed yet;
## rebuilt otherwise.
static func known(side: int) -> Dictionary:
	var now := MatchClock.now()
	var cached: Array = _cache.get(side, [])
	if not cached.is_empty() and cached[0] <= now and now < cached[1] and cached[2] == _version:
		return cached[3]
	var ids := {}
	var allies_of := {}
	var until := Vision.FOREVER
	for vision in _visions:
		if _hears(vision, vision.side(), side, allies_of):
			for id in vision.memory.ids(now):
				ids[id] = true
			until = mini(until, vision.memory.next_lapse(now))
		for exposed in vision.memory.exposed_sides(now):
			until = now + 1
			if _hears(vision, exposed, side, allies_of):
				ids[vision.body.get_instance_id()] = true
	_cache[side] = [now, until, _version, ids]
	return ids


## Whether what `vision` tells about side `from` reaches `side`: it is the same side, or an ally of
## `from` while the match shares sight.
static func _hears(vision: Vision, from: int, side: int, allies_of: Dictionary) -> bool:
	if from == side:
		return true
	if vision.rules != null and not vision.rules.allied_vision:
		return false
	if not allies_of.has(from):
		allies_of[from] = SideRelations.allies_of(from)
	return (allies_of[from] as Array).has(side)
