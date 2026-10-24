class_name AiAudit
extends Node

## The record of a match (RFC-024 §5.2), the base of the bench report. It only watches: it never
## decides or changes the game. Everything it sees becomes one text line, hashed in order into `digest`
## (sha256), so two runs with the same seed must give the same one. Wall-clock times never enter it.
## 024a: events of bodies and souls, positions every `sample_every_ticks`, and the souls ledger of each
## side. 024c: the AI's columns: every request its port makes (summons with the mana and souls before and after, casts,
## the reasons the game refused one), the mana that comes in by source, the orders, what the perception knows.

## RFC-034 034k: the lines, the clock and the sha256 live in the kit's recorder (self_tick off: this node moves the clock
## in its own _physics_process, so the order of the physics step does not change). Without one in the scene it makes its own.
@export var recorder: DetRecorder

## F371 (RFC-053): a cast the port started (not a summon), for the criteria of a bench (ExpectJudge). Reading it changes nothing.
signal cast_noted(slot: int, tag: String, target: Node)
## Every request of the port the Caster started, summons included (diagnostic, for the bench probes).
signal request_noted(slot: int, tag: String, target: Node, is_summon: bool)

## Physics ticks since start(); the clock of every line.
var tick: int:
	get: return recorder.tick if recorder != null else 0
var running: bool:
	get: return recorder != null and recorder.running
## Also keep every line (for the debug file and to find where two runs part ways).
var keep_lines: bool:
	get: return recorder.keep_lines if recorder != null else false
	set(value):
		_ensure_recorder()
		recorder.keep_lines = value

var lines: PackedStringArray:
	get: return recorder.lines if recorder != null else PackedStringArray()
var line_count: int:
	get: return recorder.line_count if recorder != null else 0

var _sides: Dictionary = {}
## Per slot: how the next gain of the purse is booked, set by the signal that announces it just before.
var _gain_kind: Dictionary = {}
var _gain_origin: Dictionary = {}
var _npcs: Array[Node] = []
var _npc_kind: Dictionary = {}
var _npc_ids: Array[int] = []
var _purses: Dictionary = {}
var _last_count: Dictionary = {}
var _hp: Dictionary = {}
var _pools: Dictionary = {}
var _last_mana: Dictionary = {}
var _perceptions: Dictionary = {}
## Per slot: the summons whose cast has not ended (the window in which the mana is counted).
var _open: Dictionary = {}
var _leaks_max: Dictionary = {}
var _foes_max: Dictionary = {}
var _extra: Dictionary = {}
var _rituals: Array[Dictionary] = []
var _checkpoints: Dictionary = {}


func _ready() -> void:
	_ensure_recorder()


func _ensure_recorder() -> void:
	if recorder == null:
		recorder = DetRecorder.new()
		recorder.name = "Recorder"
		add_child(recorder)
	recorder.self_tick = false


func start() -> void:
	_ensure_recorder()
	recorder.start()


func stop() -> void:
	recorder.stop()


func _physics_process(_delta: float) -> void:
	if not running:
		return
	recorder.advance()
	if tick % 30 == 0:
		for slot in _perceptions.keys():
			var perception: AiPerception = _perceptions[slot]
			_leaks_max[slot] = maxi(int(_leaks_max.get(slot, 0)), perception.leak_count())
			_foes_max[slot] = maxi(int(_foes_max.get(slot, 0)), perception.foes_count())


## One line of the record: the tick, a kind and the text.
func record(kind: String, text: String) -> void:
	if recorder != null:
		recorder.record(kind, text)


## Sha256 of the lines so far. It finishes the context, so call it once, at the end.
func digest() -> String:
	return recorder.digest()


## RFC-024 024d: the structures that go up (the Manaliths of each side, with the tick) and the rituals (Desecrate: when it began, when
## it ended and how). Server or solo only; the bench calls it once the world exists.
func watch_world(world: Node) -> void:
	var structures := world.get_node_or_null("Structures")
	if structures != null:
		structures.child_entered_tree.connect(_on_structure_entered)
	world.get_tree().node_added.connect(_on_node_added)


func _on_structure_entered(node: Node) -> void:
	var tower := node as CastTower
	if not running or tower == null or tower.type.role != BuildingType.Role.MANALITH:
		return
	var slot := int(node.get("owner_slot"))
	var at := (node as Node3D).global_position if node is Node3D else Vector3.ZERO
	(_side(slot)["manaliths"] as Array).append({"tick": tick, "at": fmt(at), "name": str(node.name)})
	record("manalith", "slot %d %s %s" % [slot, node.name, _fmt(at)])


func _on_node_added(node: Node) -> void:
	if not running or not node is Ritual:
		return
	var ritual := node as Ritual
	if ritual.kind != Ritual.Kind.DESECRATE:
		return
	var entry := {"start": tick, "end": -1, "result": "running", "caster": ritual.caster_slot, "target": ritual.target_slot}
	(_side(ritual.caster_slot)["desecrations"] as Array).append(entry)
	record("desecrate", "slot %d begins on slot %d" % [ritual.caster_slot, ritual.target_slot])
	ritual.ended.connect(_on_ritual_ended.bind(entry), CONNECT_ONE_SHOT)
	_rituals.append(entry)


func _on_ritual_ended(completed: bool, entry: Dictionary) -> void:
	entry["end"] = tick
	entry["result"] = "completed" if completed else "cancelled"
	record("desecrate", "slot %d on slot %d %s" % [int(entry["caster"]), int(entry["target"]), entry["result"]])


## Why the match ended, from what the record saw: the loser's wizard went down while a Desecrate of the winner was on his altar
## (the ritual drained him to death, or the army finished him under it: either way the altar fell by the ritual's rule).
func end_reason(winner: int) -> String:
	if winner <= 0:
		return "none"
	for entry: Dictionary in _rituals:
		if int(entry["caster"]) == winner and (entry["result"] == "completed" or entry["result"] == "running"):
			return "desecration"
	return "other"


## A snapshot of the numbers the criteria read at a given minute (the NPC economy at 10 min, the Manaliths at 6).
func checkpoint(label: String) -> void:
	var snap := {}
	for slot in _sides.keys():
		var side: Dictionary = _sides[slot]
		var ledger: Dictionary = side["souls_ledger"]
		var kills := 0
		for key in (side["npc_kills"] as Dictionary):
			kills += int(side["npc_kills"][key])
		snap[str(slot)] = {
			"tick": tick,
			"npc_kills": kills,
			"by_origin": (ledger["by_origin"] as Dictionary).duplicate(),
			"npc_touched": ledger["npc_touched"],
			"converts": side["converts"],
			"manaliths": (side["manaliths"] as Array).size(),
			"summons": (side["summons"] as Array).size(),
			"souls_now": int(_purses[slot].get("count")) if _purses.has(slot) else 0,
		}
	_checkpoints[label] = snap


func checkpoints() -> Dictionary:
	return _checkpoints


## A creature of the match: its hits, its death and its place in the side counters.
func watch_unit(unit: Node) -> void:
	if not is_instance_valid(unit) or _hp.has(unit):
		return
	var slot := int(unit.get("owner_slot"))
	_side(slot)["units_start"] += 1
	if unit.is_in_group(&"npc"):
		_npcs.append(unit)
		_npc_ids.append(unit.get_instance_id())
		_npc_kind[unit.get_instance_id()] = _npc_name(unit)
	var health := unit.get_node("Health")
	_hp[unit] = float(health.get("current"))
	health.changed.connect(_on_health.bind(unit))
	health.hurt.connect(_on_hurt.bind(unit))
	health.died.connect(_on_killed.bind(unit))
	unit.connect("struck", _on_struck.bind(unit))
	unit.connect("died", _on_died.bind(unit))


## A soul came out of a corpse (SoulSystem.soul_spawned).
func watch_soul(soul: Node3D) -> void:
	var at := soul.global_position
	record("soul", "%s n%d slot %d %s" % [soul.name, int(soul.get("number")), int(soul.get("owner_slot")), _fmt(at)])


## Where the souls of a wizard come from: SoulSystem says it before it fills the purse of a pick-up and
## SacrificeSystem before a Convert does (RFC-024 §5.2 `by_origin`). The ledger can then tell collected from converted.
func watch_sources(soul_system: Node, sacrifice_system: Node) -> void:
	if soul_system != null:
		soul_system.connect("soul_collected", _on_soul_collected)
	if sacrifice_system != null:
		sacrifice_system.connect("souls_converted", _on_souls_converted)


func _on_soul_collected(slot: int, _count: int, origin: StringName) -> void:
	_gain_kind[slot] = &"collected"
	_gain_origin[slot] = origin


func _on_souls_converted(slot: int, _count: int, origin: StringName) -> void:
	_gain_kind[slot] = &"converted"
	_gain_origin[slot] = origin
	if running:
		_side(slot)["converts"] += 1


## A wizard's purse: the ledger of its side is filled from every change of its count.
func watch_purse(slot: int, purse: Node) -> void:
	_purses[slot] = purse
	var side := _side(slot)
	side["has_wizard"] = true
	side["souls_ledger"]["start"] = int(purse.get("count"))
	_last_count[slot] = int(purse.get("count"))
	purse.connect("changed", _on_purse_changed.bind(slot))


## The AI of `slot`: its wizard's mana pool (what comes in, by source, and what goes out) and its perception.
func watch_ai(slot: int, wizard: Node, perception: AiPerception) -> void:
	_perceptions[slot] = perception
	var pool := wizard.get_node("ManaPool")
	_pools[slot] = pool
	_last_mana[slot] = float(pool.get("current"))
	pool.connect("fed", _on_fed.bind(slot))
	pool.connect("changed", _on_pool_changed.bind(slot))
	_side(slot)["has_ai"] = true


func _on_fed(amount: float, source: StringName, slot: int) -> void:
	if not running:
		return
	var key := String(source) if not String(source).is_empty() else "other"
	var table: Dictionary = _side(slot)["mana_in"]
	table[key] = snappedf(float(table.get(key, 0.0)) + amount, 0.001)


## Every change of the pool: what goes out is `mana_out`; the open summons add it to their window.
func _on_pool_changed(current: float, _maximum: float, slot: int) -> void:
	if not running:
		_last_mana[slot] = current
		return
	var delta := current - float(_last_mana.get(slot, current))
	_last_mana[slot] = current
	if absf(delta) < 0.000001:
		return
	var side := _side(slot)
	if delta < 0.0:
		side["mana_out"] = float(side["mana_out"]) - delta
	else:
		side["mana_gained"] = float(side["mana_gained"]) + delta
	for entry: Dictionary in _open.get(slot, []):
		if delta < 0.0:
			entry["mana_spent"] = float(entry["mana_spent"]) - delta
		else:
			entry["mana_gained"] = float(entry["mana_gained"]) + delta


## Everything the port asked of the Caster, and what it answered (RFC-024 §5.2): a started summon opens a window that
## closes when the creature is let go (`summoned`); a refusal is counted by its reason.
func note_request(slot: int, tag: String, display: String, started: bool, answer: String, before: Dictionary, is_summon: bool, unit: Node, target: Node) -> void:
	var side := _side(slot)
	if not started:
		var reason := answer if not answer.is_empty() else "(sin respuesta)"
		var table: Dictionary = side["rejections"]
		table[reason] = int(table.get(reason, 0)) + 1
		record("reject", "slot %d %s %s" % [slot, tag, reason])
		return
	request_noted.emit(slot, tag, target, is_summon)
	if is_summon:
		var type := GameData.creature(tag)
		var entry := {
			"tick": tick, "tag": tag, "name": display,
			"mana_before": snappedf(float(before["mana"]), 0.001), "souls_before": int(before["souls"]),
			"cost_mana": maxf(1.0, float(type.mana_cost)) if type != null else 0.0, "cost_souls": type.souls if type != null else 0,
			"mana_spent": 0.0, "mana_gained": 0.0, "mana_after": -1.0, "souls_after": -1, "done": false,
		}
		(side["summons"] as Array).append(entry)
		if not _open.has(slot):
			_open[slot] = []
		(_open[slot] as Array).append(entry)
		record("summon", "slot %d %s mana %.1f souls %d" % [slot, tag, float(before["mana"]), int(before["souls"])])
		if unit != null:
			unit.connect("summoned", _on_summoned.bind(entry, slot, unit), CONNECT_ONE_SHOT)
	else:
		(side["casts"] as Array).append({"tick": tick, "tag": tag, "target": str(target.name) if target != null else "", "at_mana": snappedf(float(before["mana"]), 0.001)})
		record("cast", "slot %d %s -> %s" % [slot, tag, str(target.name) if target != null else "-"])
		cast_noted.emit(slot, tag, target)


func _on_summoned(entry: Dictionary, slot: int, _unit: Node) -> void:
	var pool: Node = _pools.get(slot)
	var purse: Node = _purses.get(slot)
	entry["mana_after"] = snappedf(float(pool.get("current")), 0.001) if pool != null else 0.0
	entry["souls_after"] = int(purse.get("count")) if purse != null else 0
	entry["mana_spent"] = snappedf(float(entry["mana_spent"]), 0.001)
	entry["mana_gained"] = snappedf(float(entry["mana_gained"]), 0.001)
	entry["done"] = true
	(_open.get(slot, []) as Array).erase(entry)
	record("summoned", "slot %d %s mana %.1f souls %d" % [slot, str(entry["tag"]), float(entry["mana_after"]), int(entry["souls_after"])])


## What the side adds to its row of the report when it ends (ai_ms, the orders it issued).
func set_extra(slot: int, key: String, value: Variant) -> void:
	_side(slot)[key] = value


## Positions rounded to 0.1 m of the bodies, sorted by name.
func sample(bodies: Array) -> void:
	recorder.sample(bodies)


## The counters per side, for the report. `now` of the ledger is read from the purse.
func sides_report() -> Dictionary:
	var out := {}
	for slot in _sides.keys():
		var side: Dictionary = _sides[slot].duplicate(true)
		var ledger: Dictionary = side["souls_ledger"]
		var purse: Node = _purses.get(slot)
		ledger["now"] = int(purse.get("count")) if purse else 0
		ledger["balanced"] = int(ledger["now"]) == int(ledger["start"]) + int(ledger["collected"]) + int(ledger["converted"]) - int(ledger["spent"])
		side["souls_collected"] = ledger["collected"]
		side["mana_out"] = snappedf(float(side["mana_out"]), 0.001)
		side["mana_gained"] = snappedf(float(side["mana_gained"]), 0.001)
		if _perceptions.has(slot):
			side["unseen_leaks"] = int(_leaks_max.get(slot, 0))
			side["perceived_foes_max"] = int(_foes_max.get(slot, 0))
			side["tracks_end"] = (_perceptions[slot] as AiPerception).tracks.size()
		out[str(slot)] = side
	return out


## Bodies of a side that were watched and have not died.
func alive_of(slot: int) -> int:
	var side := _side(slot)
	return int(side["units_start"]) - int(side["deaths"])


## Typed damage (ranged shots, spells): Health.hurt says what was really taken and from whom.
func _on_hurt(amount: float, kind: StringName, from_slot: int, unit: Node) -> void:
	if amount > 0.0 and from_slot > 0:
		_side(from_slot)["hits_dealt"] += 1
		_side(from_slot)["damage_dealt"] = snappedf(float(_side(from_slot)["damage_dealt"]) + amount, 0.01)
		_note_ally_hit(from_slot, unit)
	record("hurt", "%s %.2f %s from %d" % [unit.name, amount, kind, from_slot])


## Melee: UnitBody.struck comes from the one who hits (the roll is the unit's own seeded stream).
func _on_struck(target: Node3D, amount: float, hit_chance: float, roll: float, unit: Node) -> void:
	var slot := int(unit.get("owner_slot"))
	_side(slot)["hits_dealt"] += 1
	_side(slot)["damage_dealt"] = snappedf(float(_side(slot)["damage_dealt"]) + amount, 0.01)
	_note_ally_hit(slot, target)
	record("struck", "%s -> %s %.2f p%.3f r%.3f" % [unit.name, target.name, amount, hit_chance, roll])


## RFC-049 049d (F293): a hit of `from_slot` on a body of an ALLY seat (another slot of its team). A report counter only: no line of
## the record, so the digest does not change. With teams on and friendly fire on, a bench of AI expects 0.
func _note_ally_hit(from_slot: int, target: Node) -> void:
	var slot := int(target.get("owner_slot")) if target != null else 0
	if slot > 0 and slot != from_slot and SideRelations.stance(from_slot, slot) == SideRelations.Stance.ALLY:
		_side(from_slot)["ally_hits"] += 1


## Every drop of health, whatever took it.
func _on_health(current: float, _maximum: float, unit: Node) -> void:
	var before := float(_hp.get(unit, current))
	_hp[unit] = current
	if not running or current >= before:
		return
	var slot := int(unit.get("owner_slot"))
	_side(slot)["damage_taken"] = snappedf(float(_side(slot)["damage_taken"]) + before - current, 0.01)
	record("hp", "%s %.2f" % [unit.name, current])


## Health.died knows who took the last point: the NPC kills of each side (`npc_kills`).
func _on_killed(from_slot: int, unit: Node) -> void:
	if from_slot <= 0 or not unit.is_in_group(&"npc"):
		return
	var kills: Dictionary = _side(from_slot)["npc_kills"]
	var key := _npc_name(unit)
	kills[key] = int(kills.get(key, 0)) + 1


func _npc_name(unit: Node) -> String:
	var type: Variant = unit.get("type")
	return str(type.display_name).to_lower() if type != null else str(unit.get("creature_tag"))


## NPC bodies of the map still alive: {name: count}. Zero rows are kept for the kinds that existed.
func npc_alive() -> Dictionary:
	var alive := {}
	for id in _npc_ids:
		## The corpse of an NPC leaves the tree after a while: its kind was written down when it was first watched.
		var unit: Object = instance_from_id(id)
		var key: String = _npc_kind.get(id, "npc")
		if not alive.has(key):
			alive[key] = 0
		if unit != null and is_instance_valid(unit) and unit is UnitBody and not (unit as UnitBody).is_dead():
			alive[key] += 1
	return alive


func _on_died(tag: String, slot: int, at: Vector3, unit: Node) -> void:
	_side(slot)["deaths"] += 1
	record("died", "%s %s slot %d %s" % [unit.name, tag, slot, _fmt(at)])


func _on_purse_changed(count: int, slot: int) -> void:
	if not running:
		return
	var delta := count - int(_last_count.get(slot, count))
	_last_count[slot] = count
	var ledger: Dictionary = _side(slot)["souls_ledger"]
	if delta > 0:
		## What announced it says how it is booked; a gain nobody announced (a Desecrate giving the souls back)
		## is a collected one of a creature.
		var kind: StringName = _gain_kind.get(slot, &"collected")
		var origin: StringName = _gain_origin.get(slot, &"creature")
		_gain_kind.erase(slot)
		_gain_origin.erase(slot)
		ledger[String(kind)] += delta
		ledger["by_origin"][String(origin)] += delta
		if kind == &"collected" and origin == &"npc":
			ledger["npc_touched"] += delta
	elif delta < 0:
		ledger["spent"] -= delta
	record("purse", "slot %d %d" % [slot, count])


func _side(slot: int) -> Dictionary:
	if not _sides.has(slot):
		_sides[slot] = {
			"has_wizard": false,
			"units_start": 0,
			"deaths": 0,
			"hits_dealt": 0,
			"ally_hits": 0,
			"damage_dealt": 0.0,
			"damage_taken": 0.0,
			"summons": [],
			"casts": [],
			"rejections": {},
			"converts": 0,
			"manaliths": [],
			"desecrations": [],
			"mana_in": {"fount": 0.0, "altar": 0.0, "manalith": 0.0, "manahoar": 0.0, "other": 0.0},
			"mana_out": 0.0,
			"mana_gained": 0.0,
			"npc_kills": {},
			"souls_ledger": {"start": 0, "collected": 0, "converted": 0, "spent": 0, "now": 0,
				"by_origin": {"npc": 0, "creature": 0, "wizard": 0}, "npc_touched": 0},
		}
	return _sides[slot]


static func _fmt(at: Vector3) -> String:
	return "%.1f,%.1f,%.1f" % [at.x, at.y, at.z]


static func fmt(at: Vector3) -> String:
	return _fmt(at)
