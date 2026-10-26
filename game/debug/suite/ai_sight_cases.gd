extends RefCounted

## 055f f2 case of rules_suite: what the AI takes in from Vision by listening (SightIntake on VisionSides.events.learned) is what it
## took in by asking every replan (the polling of before f2, copied below line by line as the reference). Two perceptions of side 2
## watch the same scripted scene: a foe walks into the sight of a body of the side, out of it, is forgotten where it was last seen,
## walks back, and a second foe is revealed by a hit. After every step both must track the same bodies with the same flags, and both
## must have taken them in in the same order. Also: a perception that starts late knows what was seen before it existed, a mark that
## lapsed but was not dropped yet is announced again, and a strike is announced once while it is remembered.
## Not covered here: a body rejected by the pathfinder region (the suite has no ready NavService; the rule is the same call for both).
## Prints AI SIGHT compared=<n> differ=<n> and each difference.

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const RIG := preload("res://debug/suite/ai_perception_rig.tscn")
const RULES := preload("res://data/match_rules.tres")
const PROFILE := preload("res://data/ai/profile_original.tres")
const HOME := Vector3(1700.0, 0.0, 1700.0)
const FAR := Vector3(2300.0, 0.0, 1700.0)
const FORGET_TICKS := 3

var _event: AiPerception
var _poll: AiPerception
var _lost: Dictionary = {}  ## the reference's own `_lost`
var _poll_forgotten := 0
var _adds := {"event": [], "poll": []}
var _compared := 0
var _lines := PackedStringArray()


func run(host: Node3D) -> Dictionary:
	var checks := {}
	_event = _perception(host, "SightCasesIntake", true)
	_poll = _perception(host, "SightCasesPolling", false)
	var mine := _unit(host, 2, HOME, "SightCasesMine")
	var foe := _unit(host, 1, FAR, "SightCasesFoe")
	var foe2 := _unit(host, 1, FAR + Vector3(0.0, 0.0, 40.0), "SightCasesFoe2")
	await host.get_tree().process_frame
	var eyes := mine.get("vision") as Vision
	eyes.memory.forget_ticks = FORGET_TICKS
	for p: AiPerception in [_event, _poll]:
		p.add_node(mine, &"event")
	_step("start")
	foe.global_position = HOME + Vector3(20.0, 0.0, 0.0)
	eyes.refresh()
	_step("foe walks in")
	checks["foe_known"] = _event.find(foe) != null and _event.find(foe).seen
	var late: AiPerception = _perception(host, "SightCasesLate", true)
	late.discover()
	checks["late_knows_what_was_seen"] = late.find(foe) != null
	foe.global_position = FAR
	eyes.refresh()
	for _tick in FORGET_TICKS + 1:
		await host.get_tree().physics_frame
	_step("foe gone, forgotten where it was")
	checks["foe_forgotten"] = _event.find(foe) == null and _event.forgotten == 1 and _poll_forgotten == 1
	_step("nothing new")
	foe.global_position = HOME + Vector3(0.0, 0.0, 20.0)
	eyes.refresh()
	_step("foe walks back")
	checks["foe_known_again"] = _event.find(foe) != null and _event.find(foe).seen
	VisionSides.reveal(foe2, mine)
	_step("foe2 strikes")
	checks["struck_known"] = _event.find(foe2) != null
	checks["same_order"] = _adds["event"] == _adds["poll"]
	if not bool(checks["same_order"]):
		_lines.append("order: intake=%s polling=%s" % [str(_adds["event"]), str(_adds["poll"])])
	checks["lapsed_mark_announced_again"] = _lapsed_mark(mine, foe) == 2
	checks["strike_announced_once"] = _strike_news(foe2) == 1
	checks["same_tracks"] = _lines.is_empty()
	print("AI SIGHT compared=%d differ=%d" % [_compared, _lines.size()])
	for line in _lines:
		print("AI SIGHT   " + line)
	for node: Node in [late, _event, _poll, mine, foe, foe2]:
		node.queue_free()
	var ok := true
	for key: String in checks:
		ok = ok and bool(checks[key])
	return {"ai_sight": {"ok": ok, "checks": checks, "compared": _compared, "notes": _lines}}


func _perception(host: Node3D, title: String, listens: bool) -> AiPerception:
	var p: AiPerception = RIG.instantiate()
	p.name = title
	p.profile = PROFILE
	p.slot = 2
	if not listens:
		var intake := p.intake
		p.intake = null
		p.remove_child(intake)
		intake.free()
	host.add_child(p)
	var key := "event" if listens else "poll"
	if title != "SightCasesLate":
		p.tracked.connect(func(t: AiTrack) -> void: (_adds[key] as Array).append(String(t.node.name)))
	return p


func _unit(host: Node3D, slot: int, at: Vector3, title: String) -> Node3D:
	var type := GameData.creature("ycro")
	var unit: Node3D = UNIT_SCENE.instantiate()
	unit.name = title
	unit.position = at
	unit.set("owner_slot", slot)
	unit.set("type", type)
	unit.set("model", type.model_id())
	unit.set("rules", RULES)
	unit.set("idle_aggro", false)
	host.add_child(unit)
	(unit.get("vision") as Vision).watching = false
	return unit


## One replan and one perception run of both, in the order AiSide runs them, then the comparison.
func _step(label: String) -> void:
	_event.discover()
	_poll_take_in(_poll)
	_poll.discover()
	_event.update_nodes(1)
	_poll.update_nodes(1)
	_poll_forget_checked(_poll)
	_poll_recall_seen(_poll)
	_compared += 1
	var a := _signature(_event)
	var b := _signature(_poll)
	if a != b:
		_lines.append("%s: intake=%s polling=%s" % [label, a, b])


static func _signature(p: AiPerception) -> String:
	var parts := PackedStringArray()
	for t: AiTrack in p.tracks.values():
		parts.append("%s:%s:%s:%s" % [t.node.name, "seen" if t.seen else "-", t.origin, t.age_seen])
	parts.sort()
	return ",".join(parts)


# ---- The reference: AiPerception._take_in_seen, _forget_checked and _recall_seen as they were before 055f f2 ----

func _poll_take_in(p: AiPerception) -> void:
	for node in VisionSides.seen_by(p.slot):
		if not p.tracks.has(node.get_instance_id()):
			p.add_node(node, &"seen")


func _poll_forget_checked(p: AiPerception) -> void:
	var lookers: Array = []
	for own: AiTrack in p.bodies(0):
		if own.is_valid():
			var eyes := VisionSides.of(own.node)
			var sight := eyes.range_m() if eyes != null else 0.0
			if sight > 0.0:
				lookers.append([own.node.global_position, sight * sight])
	if lookers.is_empty():
		return
	var gone: Array[AiTrack] = []
	for k in [1, 2, 3]:
		for t: AiTrack in p._bodies[k]:
			if not t.is_valid() or p.sees(t):
				continue
			for looker: Array in lookers:
				var at: Vector3 = looker[0]
				if Vector2(t.cur_pos.x - at.x, t.cur_pos.z - at.z).length_squared() <= float(looker[1]):
					gone.append(t)
					break
	for t in gone:
		_lost[t.id] = t.node
		_poll_forgotten += 1
		p._erase(t)


func _poll_recall_seen(p: AiPerception) -> void:
	if _lost.is_empty():
		return
	for id in _lost.keys():
		var held: Variant = _lost[id]
		if not is_instance_valid(held) or AiBody.is_dead(held as Node3D):
			_lost.erase(id)
			continue
		var node := held as Node3D
		if VisionSides.sees(p.slot, node):
			_lost.erase(id)
			var t := p.add_node(node, &"seen")
			if t != null:
				t.seen = true


# ---- VisionMemory announcements ----

## A mark that lapsed but was not dropped (nobody asked `ids` since) is announced again when the foe is seen again.
static func _lapsed_mark(observer: Node3D, foe: Node3D) -> int:
	var memory := VisionMemory.new()
	memory.forget_ticks = FORGET_TICKS
	var heard: Array[Node3D] = []
	var on_learned := func(_side: int, node: Node3D) -> void: heard.append(node)
	VisionSides.events.learned.connect(on_learned)
	memory.take_in([foe], 2, observer, 1000)
	memory.take_in([], 2, observer, 1001)
	memory.take_in([foe], 2, observer, 1002)
	memory.take_in([], 2, observer, 1003)
	memory.take_in([foe], 2, observer, 1003 + FORGET_TICKS)
	VisionSides.events.learned.disconnect(on_learned)
	return heard.size()


## A body that strikes twice while its first strike is remembered is announced once.
static func _strike_news(striker: Node3D) -> int:
	var memory := VisionMemory.new()
	memory.forget_ticks = FORGET_TICKS
	var heard: Array[Node3D] = []
	var on_learned := func(_side: int, node: Node3D) -> void: heard.append(node)
	VisionSides.events.learned.connect(on_learned)
	memory.expose_to(2, 2000, striker)
	memory.expose_to(2, 2001, striker)
	VisionSides.events.learned.disconnect(on_learned)
	return heard.size()
