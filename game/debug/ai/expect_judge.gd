class_name ExpectJudge
extends Node

## The criteria of a bench scene (RFC-053 §4, F370): reads BenchRules.expects, watches the bodies the runner put on the field
## (by their labels) and prints one line per criterion, `EXPECT PASS|FAIL <check> <value>`, then `EXPECT DONE PASS|FAIL`.
## It only listens (signals of the bodies) and reads: it never changes the simulation, so a bench with it keeps its digest.
## The runner (debug/ai/ai_match.gd) calls begin() once the field is ready, step() every tick and finish() at the end; with
## criteria it ends the run as soon as is_done(). BenchRules.trace_labels print TRACE lines (health, mode, target) every
## trace_every_s, for diagnostics. Debug code.

const PREFIX := "EXPECT "

var _rules: BenchRules
var _bodies: Dictionary = {}
var _rows: Array[Dictionary] = []
var _tick := 0
var _trace_ticks := 30
var _started := false
var _finished := false


## `bodies`: label -> Array[Node3D] (the groups and buildings of the rules).
func begin(rules: BenchRules, bodies: Dictionary) -> void:
	_rules = rules
	_bodies = bodies
	_started = true
	_trace_ticks = maxi(1, MatchClock.ticks_for(rules.trace_every_s))
	print("SIDES mapa %s · stance(1,0) %s · stance(2,0) %s · stance(1,3) %s · stance(2,3) %s" % [
		MapCatalog.current_tag(), _stance(1, 0), _stance(2, 0), _stance(1, 3), _stance(2, 3)])
	for label in rules.trace_labels:
		for body: Node3D in _of(label):
			var ranged := body.get_node_or_null("RangedAttack")
			if ranged != null:
				ranged.connect("fired", _on_traced_fire.bind(body).unbind(3))
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
		if not row["decided"] and (row["expect"] as BenchExpect).kind != "spared":
			return false
	return true


func step(tick: int) -> void:
	if not _started or _finished:
		return
	_tick = tick
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
			if expect.kind == "spared":
				_decide(row, int(row["count"]) <= expect.max_count, str(row["count"]))
			else:
				_decide(row, false, "sin_dato")
	var ok := true
	for row in _rows:
		ok = ok and bool(row["ok"])
	print(PREFIX + "DONE " + ("PASS" if ok else "FAIL"))
	return ok


func _of(label: String) -> Array:
	var found: Array = []
	for body: Variant in _bodies.get(label, []):
		if body != null and is_instance_valid(body):
			found.append(body)
	return found


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
			var ranged := body.get_node_or_null("RangedAttack")
			if ranged != null:
				ranged.connect("fired", _on_blow.bind(row, body).unbind(3))
	if expect.kind == "hurt":
		var slot := _slot_of(expect.subject)
		for body: Node3D in _of(expect.object):
			var health := body.get_node_or_null("Health") as Health
			if health != null:
				health.hit.connect(_on_object_hit.bind(row, slot).unbind(1))
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
		"spared":
			if is_done_except(row):
				_decide(row, int(row["count"]) <= expect.max_count, str(row["count"]))
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
		if other != row and not other["decided"] and (other["expect"] as BenchExpect).kind != "spared":
			return false
	return true


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
