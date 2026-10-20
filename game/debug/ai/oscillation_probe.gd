class_name OscillationProbe
extends BenchProbe

## A body that goes back and forth on the same spot (the AI's wizard or its creatures). A BenchProbe child of the ExpectJudge.
## Once per second of game time it samples the flat position of every wizard and creature; over the last `window_s` seconds it reads
## the path walked and the net displacement, and the reversals of the movement (two consecutive one-second steps longer than
## `min_step_m` whose directions point more than 90° apart). A window is «oscillating» when the path is over `min_path_m` and the
## net displacement under `max_net_m`, or when it has more than `max_flips` reversals. It measures:
##   osc_s      seconds of oscillating windows, the worst body of the row's subject;
##   osc_flips  the most reversals in one window, the worst body.
## And of each wizard (the requests his side's port starts, AiAudit.request_noted):
##   goal_flips    the most A→B→A returns of the goal the side gives him (AiTrack.ord_pos: a new goal within `return_m` of the
##                 one before the last, that one more than `apart_m` away) in `flip_window_s` seconds: the destination that flips
##                 every replan (altar ↔ fount);
##   rich_idle_s   the longest streak of seconds with at least `rich_souls` souls and `rich_mana_ratio` of his mana in which the side
##                 started no request (no summon, no spell): «se queda quieta con muchas almas»;
##   rich_unsummoned_s  the longest streak of seconds with a soul and the mana of the cheapest creature of his book he has the souls
##                 for, in which his side asked for no creature;
##   futile_casts  spells of his side on a body of another side whose loss since the side's previous spell on it, `futile_max_casts`
##                 times over, would not bring it down (a Rock on a Taurock that regenerates in between), the count.
## `--osc-trace=<slot>[,<slot>...]` prints an OSC line per second for the bodies of that slot with the AI's view of them (order, task, threat):
## a diagnostic. It only reads: the digest of the bench does not change. Debug code.

@export var window_s := 10
@export var min_path_m := 30.0
@export var max_net_m := 5.0
@export var max_flips := 4
@export var min_step_m := 1.0
@export var rich_souls := 4
@export var return_m := 10.0
@export var apart_m := 20.0
@export var flip_window_s := 60.0
@export_range(0.0, 1.0, 0.05) var rich_mana_ratio := 0.5
@export_range(1, 20) var futile_max_casts := 3

## instance id -> {"body", "samples": Array[Vector2], "osc": int, "flips_max": int, "first": int, "ctx": String}
var _records: Dictionary = {}
var _tick := 0
var _trace_slots: Array[int] = []
var _sides: Array = []
## slot -> tick of its side's last started request.
var _last_request: Dictionary = {}
## slot -> tick of its side's last started summon.
var _last_summon: Dictionary = {}
## "slot:target id" -> health of the target at the side's last spell on it.
var _cast_health: Dictionary = {}
## slot -> {"goals": the last two distinct goals, "returns": ticks of the returns, "worst": most returns in a window}.
var _goals: Dictionary = {}
## slot -> futile spells.
var _futile: Dictionary = {}
## slot -> [longest rich idle streak in seconds, current streak, tick it began of the longest].
var _rich: Dictionary = {}


func begin(_bodies: Dictionary) -> void:
	_records.clear()
	_trace_slots.clear()
	for part in str(DetCli.args().get("osc-trace", "")).split(",", false):
		_trace_slots.append(int(part))


func listen_audit(audit: AiAudit) -> void:
	if not audit.request_noted.is_connected(_on_request):
		audit.request_noted.connect(_on_request)


func _on_request(slot: int, _tag: String, target: Node, is_summon: bool) -> void:
	_last_request[slot] = _tick
	if is_summon:
		_last_summon[slot] = _tick
	if is_summon or target == null or not is_instance_valid(target) or not "owner_slot" in target or int(target.get("owner_slot")) == slot:
		return
	var health := target.get_node_or_null("Health") as Health
	if health == null or health.maximum <= 0.0:
		return
	var key := "%d:%d" % [slot, target.get_instance_id()]
	if _cast_health.has(key) and (float(_cast_health[key]) - health.current) * futile_max_casts < health.current:
		_futile[slot] = int(_futile.get(slot, 0)) + 1
	_cast_health[key] = health.current


func step(tick: int) -> void:
	_tick = tick
	if tick % MatchClock.ticks_for(1.0) != 0:
		return
	for node in get_tree().get_nodes_in_group(&"wizard"):
		if node is WizardBody:
			_rich_step(node as WizardBody)
			_goal_step(node as WizardBody)
	for group in [&"wizard", &"unit"]:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
				continue
			_sample(body)


func measures(measure: String) -> bool:
	return measure in ["osc_s", "osc_flips", "goal_flips", "rich_idle_s", "rich_unsummoned_s", "futile_casts"]


func value_of(expect: BenchExpect, bodies: Array) -> float:
	var worst := 0.0
	for body: Node3D in bodies:
		worst = maxf(worst, _value_for(expect.measure, body))
	return worst


func notes_of(expect: BenchExpect, bodies: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	var rows: Array = []
	for body: Node3D in bodies:
		var value := _value_for(expect.measure, body)
		if value > 0.0:
			rows.append([value, body])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for row: Array in rows.slice(0, 8):
		var body := row[1] as Node3D
		var record: Dictionary = _records.get(body.get_instance_id(), {})
		if expect.measure in ["rich_idle_s", "rich_unsummoned_s"]:
			var key := int(body.get("owner_slot")) * (1 if expect.measure == "rich_idle_s" else -1)
			lines.append("%s %.0f s sin %s con almas y mana, desde %s" % [body.name, float(row[0]),
				"pedir nada" if expect.measure == "rich_idle_s" else "convocar", ExpectJudge._seconds(int((_rich.get(key, [0, 0, 0]) as Array)[2]))])
			continue
		if expect.measure == "goal_flips":
			lines.append("%s %.0f vueltas al destino anterior en %.0f s; ultimas %s" % [body.name, float(row[0]), flip_window_s,
				str((_goals.get(int(body.get("owner_slot")), {}) as Dictionary).get("ctx", ""))])
			continue
		if expect.measure == "futile_casts":
			lines.append("%s %.0f hechizos sobre un blanco que no bajaba" % [body.name, float(row[0])])
			continue
		lines.append("%s %.0f; %d s oscilando desde %s; peor ventana %s" % [body.name, float(row[0]), int(record.get("osc", 0)),
			ExpectJudge._seconds(int(record.get("first", 0))), str(record.get("ctx", ""))])
	return lines


func _value_for(measure: String, body: Node3D) -> float:
	var slot := int(body.get("owner_slot"))
	if measure == "rich_idle_s":
		return float((_rich.get(slot, [0, 0, 0]) as Array)[0])
	if measure == "rich_unsummoned_s":
		return float((_rich.get(-slot, [0, 0, 0]) as Array)[0])
	if measure == "futile_casts":
		return float(_futile.get(slot, 0))
	if measure == "goal_flips":
		return float((_goals.get(slot, {}) as Dictionary).get("worst", 0))
	var record: Dictionary = _records.get(body.get_instance_id(), {})
	if measure == "osc_flips":
		return float(record.get("flips_max", 0))
	return float(record.get("osc", 0))


## One second of a wizard: with souls and mana and no request of his side in the last second, his rich idle streak grows.
func _rich_step(wizard: WizardBody) -> void:
	var slot := wizard.owner_slot
	var purse := wizard.get_node_or_null("SoulPurse")
	var souls := int(purse.get("count")) if purse != null else 0
	var max_mana := AiPerception._mana_max(wizard)
	var mana := AiPerception._mana_now(wizard)
	var rich := not wizard.is_ghost() and souls >= rich_souls and max_mana > 0.0 and mana >= rich_mana_ratio * max_mana
	## for the summon streak: souls and the mana of the cheapest creature of his book he has the souls for
	var can_summon := not wizard.is_ghost() and souls >= 1 and mana >= _cheapest_summon(wizard, souls)
	_streak(slot, rich and _tick - int(_last_request.get(slot, -1000000)) > MatchClock.ticks_for(1.0))
	## the summon streak is kept under -slot
	_streak(-slot, can_summon and _tick - int(_last_summon.get(slot, -1000000)) > MatchClock.ticks_for(1.0))


## The mana of the cheapest creature (not the Manahoar) of the wizard's book that costs at most `souls` souls; INF with none.
static func _cheapest_summon(wizard: WizardBody, souls: int) -> float:
	var book := wizard.get_node_or_null("Spellbook") as Spellbook
	var best := INF
	if book == null:
		return best
	for i in book.creature_count():
		var type := book.creature_at(i)
		if type != null and type.tag != AiPerception.MAHO_TAG and type.souls <= souls:
			best = minf(best, maxf(1.0, float(type.mana_cost)))
	return best


func _streak(key: int, grows: bool) -> void:
	var row: Array = _rich.get(key, [0, 0, 0])
	if grows:
		row[1] = int(row[1]) + 1
		if int(row[1]) > int(row[0]):
			row[0] = row[1]
			row[2] = _tick - MatchClock.ticks_for(float(int(row[1])))
	else:
		row[1] = 0
	_rich[key] = row


## One second of a wizard's goal (what his side ordered him): an A→B→A return is counted.
func _goal_step(wizard: WizardBody) -> void:
	var side := _side_of(wizard.owner_slot)
	if side == null:
		return
	var track: AiTrack
	for t: AiTrack in side.perception.tracks.values():
		if t.node == wizard:
			track = t
			break
	if track == null:
		return
	var row: Dictionary = _goals.get(wizard.owner_slot, {"goals": [], "returns": [], "worst": 0, "ctx": ""})
	var goals: Array = row["goals"]
	var goal := Vector2(track.ord_pos.x, track.ord_pos.z)
	if goals.is_empty() or (goals[-1] as Vector2).distance_to(goal) > 3.0:
		if goals.size() == 2 and (goals[0] as Vector2).distance_to(goal) <= return_m and (goals[0] as Vector2).distance_to(goals[1]) > apart_m:
			var returns: Array = row["returns"]
			returns.append(_tick)
			while not returns.is_empty() and _tick - int(returns[0]) > MatchClock.ticks_for(flip_window_s):
				returns.pop_front()
			if returns.size() > int(row["worst"]):
				row["worst"] = returns.size()
				row["ctx"] = "a los %s entre (%.0f, %.0f) y (%.0f, %.0f)" % [ExpectJudge._seconds(_tick), goal.x, goal.y,
					(goals[1] as Vector2).x, (goals[1] as Vector2).y]
		goals.append(goal)
		if goals.size() > 2:
			goals.pop_front()
	_goals[wizard.owner_slot] = row


func _sample(body: Node3D) -> void:
	var id := body.get_instance_id()
	if not _records.has(id):
		_records[id] = {"body": body, "samples": [], "osc": 0, "flips_max": 0, "first": 0, "ctx": "", "worst_path": 0.0}
	var record: Dictionary = _records[id]
	var samples: Array = record["samples"]
	samples.append(Vector2(body.global_position.x, body.global_position.z))
	if samples.size() > window_s + 1:
		samples.pop_front()
	if _trace_slots.has(int(body.get("owner_slot"))):
		print("OSC %s %s %s" % [ExpectJudge._seconds(_tick), body.name, _ai_view(body)])
	if samples.size() < window_s + 1:
		return
	var path := 0.0
	var flips := 0
	var last_step := Vector2.ZERO
	for i in range(1, samples.size()):
		var step_v: Vector2 = samples[i] - samples[i - 1]
		path += step_v.length()
		if step_v.length() > min_step_m:
			if last_step != Vector2.ZERO and step_v.dot(last_step) < 0.0:
				flips += 1
			last_step = step_v
	var net := (samples[-1] as Vector2).distance_to(samples[0])
	record["flips_max"] = maxi(int(record["flips_max"]), flips)
	if (path > min_path_m and net < max_net_m) or flips > max_flips:
		if int(record["osc"]) == 0:
			record["first"] = _tick
		record["osc"] = int(record["osc"]) + 1
		if path > float(record["worst_path"]):
			record["worst_path"] = path
			record["ctx"] = "a los %s: camino %.1f m, neto %.1f m, %d vueltas" % [ExpectJudge._seconds(_tick), path, net, flips]


## What the side of the body knows and orders about it (diagnostic, only with --osc-trace).
func _ai_view(body: Node3D) -> String:
	var side := _side_of(int(body.get("owner_slot")))
	var pos := "(%.1f, %.1f)" % [body.global_position.x, body.global_position.z]
	if side == null:
		return pos
	var track: AiTrack
	for t: AiTrack in side.perception.tracks.values():
		if t.node == body:
			track = t
			break
	if track == null:
		return pos + " sin track"
	var task := "-"
	if track.record != null:
		for child in side.board.tasks:
			if (child as AiTask).records.has(track.record):
				task = AiTask.Kind.keys()[(child as AiTask).kind()]
				break
	var text := "%s ost %d ord (%.1f, %.1f) tarea %s" % [pos, track.ord_state, track.ord_pos.x, track.ord_pos.z, task]
	if track.record != null and track.record.leader != null:
		text += " lider %s" % track.record.leader.node.name if track.record.leader.is_valid() else ""
	if body is WizardBody:
		var brain := side.brain
		text += " amenaza %.2f ratio %.2f walks %d cola %d" % [track.threat, side.stance.enemy_ratio(), brain.line_walks, track.cast_queue.size()]
		if not track.cast_queue.is_empty():
			var e: Dictionary = track.cast_queue[0]
			var spell: Resource = e["spell"]
			var tgt: AiTrack = e["target"]
			text += " [%s -> %s]" % [str(spell.get("tag")) if spell != null else "-", tgt.node.name if tgt != null and tgt.is_valid() else "-"]
	elif body is UnitBody:
		var unit := body as UnitBody
		var orders := unit.get_node_or_null("Orders")
		text += " modo %s orden %s blanco %s" % [UnitBody.Mode.keys()[unit.mode], str(orders.get("command")) if orders != null else "-",
			unit.target.name if unit.target != null and is_instance_valid(unit.target) else "-"]
	return text


func _side_of(slot: int) -> AiSide:
	if _sides.is_empty():
		_collect_sides(get_tree().root)
	for side: AiSide in _sides:
		if side.slot == slot:
			return side
	return null


func _collect_sides(node: Node) -> void:
	if node is AiSide:
		_sides.append(node)
	for child in node.get_children():
		_collect_sides(child)
