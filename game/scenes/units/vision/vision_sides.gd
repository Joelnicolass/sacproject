class_name VisionSides
extends Node

## What a whole side sees: the union of what the Visions of its bodies remember (and of its allies'
## when the match shares sight). It keeps no marks of its own, only the list of live Visions and a
## cache of the union for the current tick; the marks live in each Vision. It does not choose
## targets (TargetPicker) nor decide what the AI knows (AiPerception): both ask it. It is the node
## `Context/Vision` of match.tscn and is live while it is in the tree (`Context` enters before the
## map and the bodies and leaves after them, so every Vision joins and leaves it). The static
## functions are how everybody asks: they forward to the sight of the match in the tree. A scene
## played with no match (F6 on a unit or a test scene) gets a loose registry of its own, made on the
## first question and dropped when the current scene changes or a match starts; it holds nothing of
## any match.

## The sight of the running match (set in _enter_tree, cleared in _exit_tree); null = no match.
static var _live: VisionSides
## The registry of the scene played with no match, and the instance id of that scene. Null until a
## Vision asks with no match in the tree.
static var _loose: Registry
static var _loose_scene := 0

var _registry := Registry.new()


func _enter_tree() -> void:
	_live = self
	_loose = null


func _exit_tree() -> void:
	if _live == self:
		_live = null


## Where the Visions announce what they learn (VisionMemory emits `learned`).
static func events() -> VisionEvents:
	return _current().events


static func join(vision: Vision) -> void:
	_current().join(vision)


static func leave(vision: Vision) -> void:
	# Leaves the registry it joined: never makes a new one just to take a Vision out.
	if _live != null:
		_live._registry.leave(vision)
	elif _loose != null:
		_loose.leave(vision)


## Something changed in a Vision: the cached unions are stale.
static func touch() -> void:
	_current().touch()


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
## no order: what a listener of `events()` that starts late has missed.
static func remembered() -> Array[Node3D]:
	return _current().remembered()


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
	return _current().mark_kind(mine, node, observer)


## The ids `side` knows now. Kept while no Vision learned a new foe and nothing has lapsed yet;
## rebuilt otherwise.
static func known(side: int) -> Dictionary:
	return _current().known(side)


## The registry of the match in the tree; with none, the loose one of the current scene.
static func _current() -> Registry:
	if _live != null:
		return _live._registry
	var tree := Engine.get_main_loop() as SceneTree
	var scene := tree.current_scene if tree != null else null
	var scene_id := scene.get_instance_id() if scene != null else 0
	if _loose == null or _loose_scene != scene_id:
		_loose = Registry.new()
		_loose_scene = scene_id
	return _loose


## The live Visions of one match (or one loose scene) and the caches of their union.
class Registry:
	extends RefCounted

	var events := VisionEvents.new()
	var visions: Array[Vision] = []
	## Bumped whenever a Vision joins, leaves or marks something, so the cached union of the same
	## tick is rebuilt.
	var version := 0
	## side -> [tick, until, version, ids]: the union of that side, valid while the tick is before
	## `until` and the version is the same.
	var cache: Dictionary = {}
	## slot -> {id -> 0 not a foe, 1 a foe, 2 a foe that never moves}, for the tick `kind_tick`:
	## asked once per body and tick.
	var kinds: Dictionary = {}
	var kind_tick := -1

	func join(vision: Vision) -> void:
		visions.append(vision)
		version += 1

	func leave(vision: Vision) -> void:
		visions.erase(vision)
		version += 1

	func touch() -> void:
		version += 1

	func remembered() -> Array[Node3D]:
		var found: Array[Node3D] = []
		for vision in visions:
			for id: int in vision.memory.held_ids():
				var node := instance_from_id(id) as Node3D
				if node != null:
					found.append(node)
			if vision.memory.has_exposures() and vision.body != null:
				found.append(vision.body)
		return found

	func mark_kind(mine: int, node: Node3D, observer: Node3D) -> int:
		var now := MatchClock.now()
		if now != kind_tick:
			kind_tick = now
			kinds.clear()
		var of_slot: Dictionary = kinds.get(mine, {})
		kinds[mine] = of_slot
		var id := node.get_instance_id()
		if not of_slot.has(id):
			var fount := node.is_in_group(ManafountBody.GROUP)
			var kind := 0
			if fount or TargetRules.is_valid_foe_of(mine, node, observer):
				kind = 2 if fount or node.is_in_group(MapBuilding.STRUCTURE_GROUP) else 1
			of_slot[id] = kind
		return of_slot[id]

	func known(side: int) -> Dictionary:
		var now := MatchClock.now()
		var cached: Array = cache.get(side, [])
		if not cached.is_empty() and cached[0] <= now and now < cached[1] and cached[2] == version:
			return cached[3]
		var ids := {}
		var allies_of := {}
		var until := Vision.FOREVER
		for vision in visions:
			if _hears(vision, vision.side(), side, allies_of):
				for id in vision.memory.ids(now):
					ids[id] = true
				until = mini(until, vision.memory.next_lapse(now))
			for exposed in vision.memory.exposed_sides(now):
				until = now + 1
				if _hears(vision, exposed, side, allies_of):
					ids[vision.body.get_instance_id()] = true
		cache[side] = [now, until, version, ids]
		return ids

	## Whether what `vision` tells about side `from` reaches `side`: it is the same side, or an ally
	## of `from` while the match shares sight.
	func _hears(vision: Vision, from: int, side: int, allies_of: Dictionary) -> bool:
		if from == side:
			return true
		if vision.rules != null and not vision.rules.allied_vision:
			return false
		if not allies_of.has(from):
			allies_of[from] = SideRelations.allies_of(from)
		return (allies_of[from] as Array).has(side)
