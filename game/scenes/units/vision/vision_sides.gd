class_name VisionSides
extends RefCounted

## What a whole side sees: the union of what the Visions of its bodies remember (and of its allies' when the match shares sight).
## It keeps no marks of its own, only the list of live Visions and a cache of the union for the current tick; the marks live in each Vision.
## It does not choose targets (TargetPicker) nor decide what the AI knows (AiPerception): both ask it.
## Ref: sacengine isVisibleToSide / markAsVisible (state.d:29658-29693).

static var _visions: Array[Vision] = []
## Bumped whenever a Vision joins, leaves or marks something, so the cached union of the same tick is rebuilt.
static var _version := 0
## side -> [tick, version, ids]: the union of that side, valid while tick and version are the same.
static var _cache: Dictionary = {}


static func join(vision: Vision) -> void:
	_visions.append(vision)
	_version += 1


static func leave(vision: Vision) -> void:
	_visions.erase(vision)
	_version += 1


## Something changed in a Vision: the cached unions are stale.
static func touch() -> void:
	_version += 1


## The Vision of a body (UnitBody, WizardBody, the Divine Sight eye), or null for one without eyes (a structure).
static func of(node: Node) -> Vision:
	return node.get("vision") as Vision if node != null else null


## Whether `side` sees `node` now: its own bodies always, a foe while a Vision of the side (or of an ally that shares) remembers it.
static func sees(side: int, node: Node3D) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	return VisionRules.slot_of(node) == side or known(side).has(node.get_instance_id())


## The foes (and founts) `side` remembers, sorted by name. The AI adds the new ones to what it knows.
static func seen_by(side: int) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for id: int in known(side):
		var node := instance_from_id(id) as Node3D
		if node != null and node.is_inside_tree():
			found.append(node)
	found.sort_custom(VisionRules.by_name)
	return found


## `attacker` hurt `victim`: the victim's side sees the attacker for a while, and the victim remembers who hurt it.
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


## The ids `side` knows now. Cached per tick; rebuilt when any Vision changed.
static func known(side: int) -> Dictionary:
	var now := MatchClock.now()
	var cached: Array = _cache.get(side, [])
	if not cached.is_empty() and cached[0] == now and cached[1] == _version:
		return cached[2]
	var ids := {}
	var allies_of := {}
	for vision in _visions:
		if _hears(vision, vision.side(), side, allies_of):
			for id in vision.memory.ids(now):
				ids[id] = true
		for exposed in vision.memory.exposed_sides(now):
			if _hears(vision, exposed, side, allies_of):
				ids[vision.body.get_instance_id()] = true
	_cache[side] = [now, _version, ids]
	return ids


## Whether what `vision` tells about side `from` reaches `side`: it is the same side, or an ally of `from` while the match shares sight.
static func _hears(vision: Vision, from: int, side: int, allies_of: Dictionary) -> bool:
	if from == side:
		return true
	if vision.rules != null and not vision.rules.allied_vision:
		return false
	if not allies_of.has(from):
		allies_of[from] = SideRelations.allies_of(from)
	return (allies_of[from] as Array).has(side)
