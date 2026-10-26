class_name ExpectJudge
extends Node

## The criteria of a bench scene (RFC-053 §4, F370): reads BenchRules.expects, watches the bodies the runner put on the field
## (by their labels) and prints one line per criterion, `EXPECT PASS|FAIL <check> <value>`, then `EXPECT DONE PASS|FAIL`.
## It only listens (signals of the bodies) and reads: it never changes the simulation, so a bench with it keeps its digest.
## The runner (debug/ai/ai_match.gd) calls begin() once the field is ready, step() every tick and finish() at the end; with
## criteria it ends the run as soon as is_done(). BenchRules.trace_labels print TRACE lines (health, mode, target) every
## trace_every_s, for diagnostics. F376: its BenchProbe children measure the «probe» rows (IdleTruthProbe). Debug code.

const PREFIX := "EXPECT "
## The kinds decided at the end (or once every other one is): they count what must not happen.
const PASSIVE: Array[String] = ["spared", "uncast", "unharmed", "burst", "probe", "refused"]

var _rules: BenchRules
var _bodies: Dictionary = {}
var _rows: Array[Dictionary] = []
var _tick := 0
var _trace_ticks := 30
var _started := false
var _finished := false
var _probes: Array[BenchProbe] = []


## `bodies`: label -> Array[Node3D] (the groups and buildings of the rules).
func begin(rules: BenchRules, bodies: Dictionary) -> void:
	_rules = rules
	_bodies = bodies
	_started = true
	_trace_ticks = maxi(1, MatchClock.ticks_for(rules.trace_every_s))
	for child in get_children():
		if child is BenchProbe:
			_probes.append(child as BenchProbe)
			(child as BenchProbe).begin(bodies)
	print("SIDES mapa %s · stance(1,0) %s · stance(2,0) %s · stance(1,3) %s · stance(2,3) %s" % [
		MapCatalog.current_tag(), _stance(1, 0), _stance(2, 0), _stance(1, 3), _stance(2, 3)])
	for label in rules.trace_labels:
		for body: Node3D in _of(label):
			var carrier := body as UnitBody
			var ranged := carrier.weapons.ranged if carrier != null else null
			if ranged != null:
				ranged.fired.connect(_on_traced_fire.bind(body).unbind(3))
			var health := body.get_node_or_null("Health") as Health
			if health != null:
				health.hit.connect(_on_traced_hit.bind(body))
	for expect in rules.expects:
		var row := {"expect": expect, "decided": false, "ok": false, "value": "", "per": {}, "count": 0, "first_tick": -1}
		for body in _of(expect.subject):
			row["per"][body.get_instance_id()] = {"body": body, "from": 0 if expect.from == "start" else -1, "hit": -1, "count": 0, "picked": -1, "dropped": -1}
		_rows.append(row)
		_wire(row)


func has_expects() -> bool:
	return _rules != null and not _rules.expects.is_empty()


## Every criterion decided (the run can end).
func is_done() -> bool:
	if not has_expects():
		return false
	for row in _rows:
		if not row["decided"] and (not PASSIVE.has((row["expect"] as BenchExpect).kind) or _watching(row)):
			return false
	return true


## F372: a passive row whose `watch_s` has not passed yet (it keeps the run going and is not decided).
func _watching(row: Dictionary) -> bool:
	return _tick < MatchClock.ticks_for((row["expect"] as BenchExpect).watch_s)


## F371: the casts the AI's port starts (AiAudit.cast_noted), for «cast» and «uncast».
func listen_audit(audit: AiAudit) -> void:
	if audit != null and not audit.cast_noted.is_connected(_on_cast):
		audit.cast_noted.connect(_on_cast)
		audit.refused_noted.connect(_on_refused)
		for probe in _probes:
			probe.listen_audit(audit)


func step(tick: int) -> void:
	if not _started or _finished:
		return
	_tick = tick
	for probe in _probes:
		probe.step(tick)
	for row in _rows:
		if not row["decided"]:
			_poll(row)
	if not _rules.trace_labels.is_empty() and tick % _trace_ticks == 0:
		_trace()


## Prints what is left undecided as FAIL (and every «spared»), then the verdict. True when every criterion passed.
func finish() -> bool:
	if not has_expects() or _finished:
		return true
	_finished = true
	for row in _rows:
		if not row["decided"]:
			var expect: BenchExpect = row["expect"]
			if PASSIVE.has(expect.kind):
				_decide_passive(row)
			else:
				_decide(row, false, "sin_dato")
	var ok := true
	for row in _rows:
		ok = ok and bool(row["ok"])
	print(PREFIX + "DONE " + ("PASS" if ok else "FAIL"))
	return ok


func _of(label: String) -> Array:
	var found: Array = []
	## F373: «a|b» names the bodies of both labels.
	for part in label.split("|", false):
		for body: Variant in _bodies.get(part, []):
			if body != null and is_instance_valid(body) and not found.has(body):
				found.append(body)
	return found


## F373: the body is down: freed, its health at 0, or a wizard dying or a ghost.
static func _is_down(body: Variant) -> bool:
	if body == null or not is_instance_valid(body) or (body as Node).is_queued_for_deletion():
		return true
	var health := (body as Node).get_node_or_null("Health") as Health
	if health != null and health.is_dead():
		return true
	return body is WizardBody and ((body as WizardBody).is_ghost() or not (body as WizardBody).is_targetable())


## F373: the first tick a body of `label` was seen down (-1: none yet). Bodies are taken at begin, so a freed one still counts.
func _down_tick(row: Dictionary, key: String, label: String) -> int:
	var known: int = row.get(key, -1)
	if known >= 0:
		return known
	for part in label.split("|", false):
		for body: Variant in _bodies.get(part, []):
			if _is_down(body):
				row[key] = _tick
				return _tick
	return -1


func _wire(row: Dictionary) -> void:
	var expect: BenchExpect = row["expect"]
	var subjects := _of(expect.subject)
	if expect.kind == "spared" and expect.subject.is_empty():
		subjects = []
		for node in get_tree().get_nodes_in_group(&"unit"):
			subjects.append(node)
	if expect.kind == "struck" or expect.kind == "spared":
		for body: Node3D in subjects:
			if body.has_signal("struck"):
				body.connect("struck", _on_blow.bind(row, body).unbind(3))
			var carrier := body as UnitBody
			var ranged := carrier.weapons.ranged if carrier != null else null
			if ranged != null:
				ranged.fired.connect(_on_blow.bind(row, body).unbind(3))
	if expect.kind == "hurt":
		var slot := _slot_of(expect.subject)
		for body: Node3D in _of(expect.object):
			var health := body.get_node_or_null("Health") as Health
			if health != null:
				health.hit.connect(_on_object_hit.bind(row, slot).unbind(1))
	if expect.kind == "unharmed":
		var slot := _slot_of(expect.subject)
		for body: Node3D in _of(expect.object):
			var health := body.get_node_or_null("Health") as Health
			if health != null:
				health.hit.connect(_on_unharmed_hit.bind(row, slot, body).unbind(1))
	if expect.kind == "burst" and not FxBus.played.is_connected(_on_fx):
		FxBus.played.connect(_on_fx)
	if expect.kind == "dropped":
		for body: Node3D in _of(expect.object):
			var health := body.get_node_or_null("Health") as Health
			if health != null:
				health.hit.connect(_on_dropped_object_hit.bind(row).unbind(3))
	if expect.from == "hurt":
		for body: Node3D in subjects:
			var health := body.get_node_or_null("Health") as Health
			if health != null:
				health.hit.connect(_on_subject_hit.bind(row, body).unbind(3))


func _slot_of(label: String) -> int:
	for body: Variant in _bodies.get(label, []):
		if body != null and is_instance_valid(body) and "owner_slot" in body:
			return int(body.get("owner_slot"))
	return -1


## A blow that landed (struck) or a shot that left (fired) of `body` on `target`.
func _on_blow(target: Node3D, row: Dictionary, body: Node3D) -> void:
	if row["decided"] or _finished:
		return
	var expect: BenchExpect = row["expect"]
	if expect.kind == "spared":
		if _counts_as_spared_object(expect, target):
			row["count"] = int(row["count"]) + 1
			print("EXPECT_NOTE %s golpe de %s a %s (tick %d)" % [expect.check, body.name, target.name if target else "-", _tick])
		return
	var entry: Dictionary = row["per"].get(body.get_instance_id(), {})
	if entry.is_empty() or int(entry["from"]) < 0 or not _of(expect.object).has(target):
		return
	entry["count"] = int(entry["count"]) + 1
	if int(entry["count"]) >= expect.min_count and int(entry["hit"]) < 0:
		entry["hit"] = _tick


func _counts_as_spared_object(expect: BenchExpect, target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not expect.object.is_empty():
		return _of(expect.object).has(target)
	var health := target.get_node_or_null("Health") as Health
	return health != null and health.maximum <= 0.0


func _on_object_hit(amount: float, from_slot: int, row: Dictionary, slot: int) -> void:
	if row["decided"] or amount <= 0.0 or from_slot != slot or int(row["first_tick"]) >= 0:
		return
	row["first_tick"] = _tick


func _on_dropped_object_hit(row: Dictionary) -> void:
	row["first_tick"] = _tick


func _on_subject_hit(row: Dictionary, body: Node3D) -> void:
	var entry: Dictionary = row["per"].get(body.get_instance_id(), {})
	if not entry.is_empty() and int(entry["from"]) < 0:
		entry["from"] = _tick


func _poll(row: Dictionary) -> void:
	var expect: BenchExpect = row["expect"]
	var window := MatchClock.ticks_for(expect.within_s)
	match expect.kind:
		"hurt":
			var first := int(row["first_tick"])
			if first >= 0:
				_decide(row, first <= window, _seconds(first))
			elif _tick > window:
				_decide(row, false, "nunca")
			return
		"spared", "uncast", "unharmed", "burst", "probe", "refused":
			if is_done_except(row) and not _watching(row):
				_decide_passive(row)
			return
		"first_cast":
			if _tick > window:
				_decide(row, false, "nunca")
			return
		"killed":
			var down := _down_tick(row, "down_object", expect.object)
			if down >= 0:
				_decide(row, down <= window, _seconds(down))
			elif _tick > window:
				_decide(row, false, "nunca")
			return
		"died_before":
			var object_down := _down_tick(row, "down_object", expect.object)
			var subject_down := _down_tick(row, "down_subject", expect.subject)
			if object_down >= 0 or subject_down >= 0:
				var first_ok := object_down >= 0 and (subject_down < 0 or object_down < subject_down)
				_decide(row, first_ok, "%s %s / %s %s" % [expect.object, _seconds(object_down) if object_down >= 0 else "-", expect.subject, _seconds(subject_down) if subject_down >= 0 else "-"])
			elif _tick > window:
				_decide(row, false, "nadie")
			return
		"cast":
			var first := int(row["first_tick"])
			if first >= 0:
				_decide(row, first <= window, _seconds(first))
			elif _tick > window:
				_decide(row, false, "nunca (%d)" % int(row["count"]))
			return
	var objects := _of(expect.object)
	var times: Array[int] = []
	var failed := false
	var pending := false
	for id in row["per"]:
		var entry: Dictionary = row["per"][id]
		var body: Variant = entry["body"]
		var alive := body != null and is_instance_valid(body)
		if expect.from == "near" and int(entry["from"]) < 0 and alive:
			for other: Node3D in objects:
				if _flat(other.global_position, (body as Node3D).global_position) <= expect.near_m:
					entry["from"] = _tick
					break
		var target: Variant = body.get("target") if alive else null
		var has_object := target != null and is_instance_valid(target) and objects.has(target)
		var done := -1
		match expect.kind:
			"picked":
				if int(entry["from"]) >= 0 and has_object and int(entry["picked"]) < 0:
					entry["picked"] = _tick
				done = int(entry["picked"])
			"struck":
				done = int(entry["hit"])
			"dropped":
				if has_object and int(entry["picked"]) < 0:
					entry["picked"] = _tick
				if int(entry["picked"]) >= 0 and not has_object and int(entry["dropped"]) < 0:
					entry["dropped"] = _tick
					print("EXPECT_NOTE %s %s suelta el blanco a los %s (lo tomo a los %s)" % [expect.check, (body as Node).name if alive else "?", _seconds(_tick), _seconds(int(entry["picked"]))])
				entry["from"] = maxi(int(entry["picked"]), int(row["first_tick"])) if int(entry["picked"]) >= 0 else -1
				done = int(entry["dropped"])
		var start := int(entry["from"])
		if done >= 0 and start >= 0:
			times.append(done - start)
			if done - start > window:
				failed = true
		elif start >= 0 and _tick - start > window:
			failed = true
			times.append(window + 1)
		else:
			pending = true
	if expect.quantifier == "at_least":
		var in_time: Array[int] = []
		for t in times:
			if t <= window:
				in_time.append(t)
		in_time.sort()
		var open := 0
		for id in row["per"]:
			var entry: Dictionary = row["per"][id]
			if int(entry["picked"]) < 0 and not (int(entry["from"]) >= 0 and _tick - int(entry["from"]) > window):
				open += 1
		if in_time.size() >= expect.min_count:
			_decide(row, true, "%d/%d %s" % [in_time.size(), row["per"].size(), _seconds(in_time[expect.min_count - 1])])
		elif in_time.size() + open < expect.min_count:
			_decide(row, false, "%d/%d" % [in_time.size(), row["per"].size()])
		return
	var any := expect.quantifier == "any"
	if any:
		var best := -1
		for t in times:
			if t <= window and (best < 0 or t < best):
				best = t
		if best >= 0:
			_decide(row, true, _seconds(best))
		elif not pending and not times.is_empty():
			_decide(row, false, _seconds(times.min()))
		return
	if failed:
		_decide(row, false, _seconds(times.max()) if not times.is_empty() else "nunca")
	elif not pending and not times.is_empty():
		_decide(row, true, _seconds(times.max()))


## Every criterion but `row` is decided (a «spared» waits for them).
func is_done_except(row: Dictionary) -> bool:
	for other in _rows:
		if other != row and not other["decided"] and not PASSIVE.has((other["expect"] as BenchExpect).kind):
			return false
	return true


## F371: a cast of the AI's port. Only attack spells count (an ATTACK phase) on a body of `object`. F372: a row with a
## `spell` counts the casts of that spell only, whatever its kind, and with an empty `object` on any body; «first_cast» is decided
## by the first one.
func _on_cast(slot: int, tag: String, target: Node) -> void:
	if not _started or _finished:
		return
	var spell := GameData.spell(tag)
	var attack := spell != null and AiSpellEval.casts_in(spell, SpellType.AiPhase.ATTACK)
	print("EXPECT_NOTE cast slot %d %s -> %s%s (tick %d)" % [slot, tag, target.name if target != null else "-", "" if attack else " (no ataque)", _tick])
	if target == null:
		return
	for row in _rows:
		var expect: BenchExpect = row["expect"]
		if row["decided"] or not (expect.kind == "cast" or expect.kind == "uncast" or expect.kind == "first_cast"):
			continue
		if slot != _slot_of(expect.subject):
			continue
		if (expect.spell.is_empty() and not attack) or (not expect.spell.is_empty() and expect.spell != tag):
			continue
		var on_object := _of(expect.object).has(target)
		if expect.kind == "first_cast":
			_decide(row, on_object, "%s %s" % [_seconds(_tick), target.name])
			continue
		if not on_object and not (expect.object.is_empty() and not expect.spell.is_empty()):
			continue
		row["count"] = int(row["count"]) + 1
		if expect.kind == "cast" and int(row["count"]) >= expect.min_count and int(row["first_tick"]) < 0:
			row["first_tick"] = _tick


## 055f f5: a request of the AI's port the Caster refused, for «refused».
func _on_refused(slot: int, tag: String, reason: String) -> void:
	if not _started or _finished:
		return
	print("EXPECT_NOTE refused slot %d %s: %s (tick %d)" % [slot, tag, reason, _tick])
	for row in _rows:
		var expect: BenchExpect = row["expect"]
		if row["decided"] or expect.kind != "refused" or slot != _slot_of(expect.subject):
			continue
		if expect.spell.is_empty() or expect.spell == tag:
			row["count"] = int(row["count"]) + 1


func _on_unharmed_hit(amount: float, from_slot: int, row: Dictionary, slot: int, body: Node3D) -> void:
	if row["decided"] or _finished or amount <= 0.0 or from_slot != slot:
		return
	row["count"] = float(row["count"]) + amount
	print("EXPECT_NOTE %s %s pierde %.1f del slot %d (tick %d)" % [(row["expect"] as BenchExpect).check, body.name, amount, from_slot, _tick])


## F371: an FX played somewhere; a «burst» row counts the ones of its `fx` near a body of its `object`.
func _on_fx(_kind: StringName, fx: Resource, at: Vector3) -> void:
	var fx_name := FxWire.label_of(fx)
	if not _started or _finished:
		return
	for row in _rows:
		var expect: BenchExpect = row["expect"]
		if row["decided"] or expect.kind != "burst" or fx_name != expect.fx:
			continue
		for body: Node3D in _of(expect.object):
			var d := SplashDamage.box_distance(body, at)
			if d <= expect.near_m:
				row["count"] = int(row["count"]) + 1
				print("EXPECT_NOTE %s %s a %.1f m de %s (tick %d)" % [expect.check, fx_name, d, body.name, _tick])
				break


static func _count_of(row: Dictionary) -> float:
	return float(row["count"])


static func _count_text(row: Dictionary) -> String:
	var value: Variant = row["count"]
	return "%.1f" % float(value) if value is float else str(value)


## A passive row: its count against max_count, or (F376) its probe's number against max_value, then the probe's notes.
func _decide_passive(row: Dictionary) -> void:
	var expect: BenchExpect = row["expect"]
	if expect.kind != "probe":
		_decide(row, _count_of(row) <= expect.max_count, _count_text(row))
		return
	for probe in _probes:
		if probe.measures(expect.measure):
			var bodies := _of(expect.subject)
			var value := probe.value_of(expect, bodies)
			_decide(row, value <= expect.max_value + 1e-6, "%.2f (max %.2f)" % [value, expect.max_value])
			for line in probe.notes_of(expect, bodies):
				print("EXPECT_NOTE %s %s" % [expect.check, line])
			return
	_decide(row, false, "sin_sonda")


func _decide(row: Dictionary, ok: bool, value: String) -> void:
	row["decided"] = true
	row["ok"] = ok
	row["value"] = value
	print("%s%s %s %s" % [PREFIX, "PASS" if ok else "FAIL", (row["expect"] as BenchExpect).check, value])


func _trace() -> void:
	for label in _rules.trace_labels:
		for body: Node3D in _of(label):
			var health := body.get_node_or_null("Health") as Health
			var target: Variant = body.get("target")
			var target_name: String = String((target as Node).name) if target != null and is_instance_valid(target) else "-"
			var stunned := body.get_node_or_null("Afflictions/Stunned")
			print("TRACE %s %s vida %.1f/%.0f modo %s blanco %s aturdido %s" % [
				_seconds(_tick), body.name, health.current if health else 0.0, health.maximum if health else 0.0,
				str(body.get("mode")), target_name, str(stunned.call("is_on")) if stunned != null and stunned.has_method("is_on") else "-"])


func _on_traced_fire(target: Node3D, body: Node3D) -> void:
	print("TRACE_SHOT %s %s → %s" % [_seconds(_tick), body.name, target.name if target != null and is_instance_valid(target) else "-"])


func _on_traced_hit(amount: float, from_slot: int, _was_full: bool, body: Node3D) -> void:
	print("TRACE_HIT %s %s pierde %.1f (del slot %d)" % [_seconds(_tick), body.name, amount, from_slot])


static func _stance(a: int, b: int) -> String:
	return ["neutral", "aliado", "enemigo"][SideRelations.stance(a, b)]


static func _seconds(ticks: int) -> String:
	return "%.2fs" % (float(ticks) / MatchClock.TICKS_PER_SECOND_F)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
