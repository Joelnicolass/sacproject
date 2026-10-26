extends RefCounted

## 055f f1 case of rules_suite: the named fields of AiTrack (kind, relation, site, fights, ready, free_fount and the questions built on
## them) give the same answers the flag and status words gave. LegacyTrackBits keeps the old words; for the four structures (free and
## busy top), five kinds of body and the four relations it compares every test the AI made on them, wizAttack's weight, the group and
## capture tests over a status OR, weightTriple over the old task commands, the order numbers, and over the 72 creature types that
## `has_passive(hmba)` finds the same Manahoar as `tag == "oham"`. Prints AI NAMES compared=<n> differ=<n> and each difference.

const LEGACY := preload("res://debug/suite/legacy_track_bits.gd")
const CREATURES_DIR := "res://data/catalog/creatures/"
const MANA_SOURCE: AbilityType = preload("res://data/catalog/abilities/hmba.tres")
var _sites := {AiTrack.Site.ALTAR: LEGACY.BLDG_ALTAR, AiTrack.Site.FOUNT: LEGACY.BLDG_FOUNT, AiTrack.Site.MANALITH: LEGACY.BLDG_MANALITH,
	AiTrack.Site.SHRINE: LEGACY.BLDG_SHRINE}
const DISTANCES: Array[float] = [5.0, 10.0, 145.0, 279.0, 300.0]

var _compared := 0
var _lines := PackedStringArray()
var _tactics: AiTactics = AiTactics.or_normal(null)


func run(_host: Node) -> Dictionary:
	_structures()
	_bodies()
	_relations()
	_claims()
	_weights()
	_orders()
	var types := _types()
	print("AI NAMES compared=%d differ=%d types=%d" % [_compared, _lines.size(), types])
	for line in _lines:
		print("AI NAMES   " + line)
	return {"ai_names": {"ok": types == 72 and _lines.is_empty(), "compared": _compared, "differ": _lines.size(), "notes": _lines}}


func _structures() -> void:
	for site: AiTrack.Site in _sites:
		var bfl: int = _sites[site]
		## only a fount has a top that can be busy (refresh_structure passes true for the others)
		for top_free in ([true, false] if site == AiTrack.Site.FOUNT else [true]):
			var t := AiTrack.new()
			t.kind = AiTrack.Kind.STRUCTURE
			t.site = site
			AiTrackFacts.apply_structure(t, top_free)
			var flags := LEGACY.structure_flags(bfl)
			var status := LEGACY.structure_status(bfl, site == AiTrack.Site.FOUNT, top_free)
			_track("%s top_free=%s" % [AiTrack.Site.keys()[site], top_free], t, flags, status)


func _bodies() -> void:
	var rows := [
		["wizard", AiTrack.Kind.WIZARD, true, false],
		["creature that fights", AiTrack.Kind.CREATURE, true, false],
		["pacifist creature", AiTrack.Kind.CREATURE, false, false],
		["Manahoar ready", AiTrack.Kind.MANAHOAR, false, true],
		["Manahoar not ready", AiTrack.Kind.MANAHOAR, false, false],
	]
	for row: Array in rows:
		var t := AiTrack.new()
		t.kind = row[1]
		t.fights = bool(row[2])
		t.ready = bool(row[3])
		var is_wizard: bool = row[1] == AiTrack.Kind.WIZARD
		_track(str(row[0]), t, LEGACY.body_flags(is_wizard), LEGACY.body_status(is_wizard, bool(row[2]), bool(row[3])))


## Every test the AI made on the words of a track, against the named field that replaces it.
func _track(label: String, t: AiTrack, flags: int, status: int) -> void:
	_same(label, "altar (flags & 0x200)", (flags & LEGACY.ALTAR) != 0, t.is_altar())
	_same(label, "structure (flags & 0x20)", (flags & LEGACY.STRUCTURE) != 0, t.kind == AiTrack.Kind.STRUCTURE)
	if t.kind == AiTrack.Kind.STRUCTURE:
		## CAPTURABLE is 0x100, the bit of WIZARD too: the AI only asked it of structures.
		_same(label, "capturable (flags & 0x100)", (flags & LEGACY.CAPTURABLE) != 0, t.capturable())
	_same(label, "ready (status & 0x1000)", (status & LEGACY.READY) != 0, t.ready)
	_same(label, "manalith (status & 0x4000)", (status & LEGACY.MANALITH) != 0, t.site == AiTrack.Site.MANALITH)
	_same(label, "free fount (status & 0x8000)", (status & LEGACY.UNBUILT) != 0, t.free_fount)
	_same(label, "tower (capture_task:64)", ((status & LEGACY.MANALITH) != 0 or ((status & 0x40000) != 0 and (flags & LEGACY.ALTAR) == 0))
		and (flags & LEGACY.STRUCTURE) != 0, t.kind == AiTrack.Kind.STRUCTURE and t.is_tower())
	_same(label, "altar or manalith (ghost)", (flags & LEGACY.ALTAR) != 0 or (status & LEGACY.MANALITH) != 0,
		t.is_altar() or t.site == AiTrack.Site.MANALITH)
	_same(label, "inert (status == 0)", status == 0, t.is_inert())
	_same(label, "wizard (status & 0xc)", (status & 0xc) != 0, t.is_wizard())
	_same(label, "wizard (status & 0x20000)", (status & 0x20000) != 0, t.is_wizard())
	_same(label, "wizard (status & 8)", (status & 8) != 0, t.is_wizard())
	_same(label, "fights (status & 1)", (status & LEGACY.ACTIVE) != 0, t.fights)
	_same(label, "fights (status & 9)", (status & 9) != 0, t.fights)
	_same(label, "fights (status & 3)", (status & 0x3) != 0, t.fights)
	## 055f f5 changed what the two factors read (it fights, it has an ability it can pay) instead of the bits only a wizard or a
	## ready Manahoar had; fed those old readings, the ramp and the factors still give the old numbers.
	if t.is_body():
		var old_reading := AiTrack.new()
		old_reading.fights = t.is_wizard()
		for thr in [280.0, 140.0]:
			for d in DISTANCES:
				for doctor in [false, true]:
					_same(label, "attack_weight d=%s thr=%s doctor=%s" % [d, thr, doctor], LEGACY.attack_weight(d, thr, status, doctor),
						AiField.attack_weight(d, thr, old_reading, t.ready, _tactics, doctor))


## The relation of a track and its old category, and the relation tests (own, own or ally, enemy).
func _relations() -> void:
	for relation: AiTrack.Relation in [AiTrack.Relation.OWN, AiTrack.Relation.ALLY, AiTrack.Relation.NEUTRAL, AiTrack.Relation.ENEMY]:
		var flags := LEGACY.relation_flags(relation)
		var t := AiTrack.new()
		t.relation = relation
		var label := str(AiTrack.Relation.keys()[relation])
		_same(label, "category", LEGACY.category(flags), t.category())
		_same(label, "own (flags & 1)", (flags & LEGACY.OWN) != 0, t.relation == AiTrack.Relation.OWN)
		_same(label, "own or ally (flags & 3)", (flags & (LEGACY.OWN | LEGACY.ALLY)) != 0,
			t.relation == AiTrack.Relation.OWN or t.relation == AiTrack.Relation.ALLY)
		_same(label, "enemy (flags & 4)", (flags & LEGACY.ENEMY) != 0, t.relation == AiTrack.Relation.ENEMY)
		for seen in [false, true]:
			t.seen = seen
			var with_seen := flags | (LEGACY.SEEN if seen else 0)
			_same(label, "followed seen=%s (flags & 0x81)" % seen, (with_seen & (LEGACY.OWN | LEGACY.SEEN)) != 0,
				t.relation == AiTrack.Relation.OWN or t.seen)


## The status OR of a group or of the free bodies of a claim, against has_fighter / has_wizard and the needs of a capture record.
func _claims() -> void:
	var bodies := [
		[AiTrack.Kind.WIZARD, true, false], [AiTrack.Kind.CREATURE, true, false], [AiTrack.Kind.CREATURE, false, false],
		[AiTrack.Kind.MANAHOAR, false, true],
	]
	## every subset of those four bodies
	for mask in 16:
		var status_or := 0
		var fighter := false
		var wizard := false
		for i in bodies.size():
			if mask & (1 << i):
				var row: Array = bodies[i]
				var is_wizard: bool = row[0] == AiTrack.Kind.WIZARD
				status_or |= LEGACY.body_status(is_wizard, bool(row[1]), bool(row[2]))
				fighter = fighter or bool(row[1])
				wizard = wizard or is_wizard
		var label := "subset %d" % mask
		_same(label, "group fights (status_or & 1)", (status_or & 1) != 0, fighter)
		_same(label, "group wizard (status_or & 8)", (status_or & 8) != 0, wizard)
		for need: Array in [[1, true, false], [2, false, true], [9, true, true]]:
			var old_takes := (int(need[0]) & status_or) == int(need[0])
			var new_takes := not ((bool(need[1]) and not fighter) or (bool(need[2]) and not wizard))
			_same(label, "capture needs %d" % int(need[0]), old_takes, new_takes)


func _weights() -> void:
	var pairs := [[AiTask.Kind.IDLE, LEGACY.COMMAND_IDLE], [AiTask.Kind.GUARD, LEGACY.COMMAND_GUARD],
		[AiTask.Kind.CAPTURE, LEGACY.COMMAND_CAPTURE], [AiTask.Kind.FOCUS, LEGACY.COMMAND_FOCUS]]
	for pair: Array in pairs:
		for ratio in [0.0, 0.1666666716337204, 0.5, 0.75, 1.0]:
			for aggression in [0.0, 0.25, 0.5, 1.0]:
				var old := LEGACY.weight_triple(int(pair[1]), ratio, aggression)
				var now := AiField.weight_triple(pair[0], ratio, aggression)
				_same("%s r=%s a=%s" % [AiTask.Kind.keys()[pair[0]], ratio, aggression], "weight_triple", old, now)
	## the kinds keep the numbers the brains compared (guard 1, capture 2, focus 3)
	_same("task kinds", "guard capture focus", [1, 2, 3], [AiTask.Kind.GUARD, AiTask.Kind.CAPTURE, AiTask.Kind.FOCUS])


func _orders() -> void:
	var want := {"MOVE_NEAR": 2, "GUARD": 3, "MOVE": 4, "REFILL": 5, "ATTACK": 6, "ADVANCE": 7, "TAKE_SOUL": 34}
	for key: String in want:
		_same("AiOrder", key, int(want[key]), int(AiCommandPort.AiOrder[key]))


## Over every creature type of the catalog: the Manahoar of has_passive(hmba) is the one of tag "oham", and fights is the old ACTIVE.
func _types() -> int:
	var count := 0
	for file in DirAccess.get_files_at(CREATURES_DIR):
		if not file.ends_with(".tres"):
			continue
		var type := load(CREATURES_DIR + file) as CreatureType
		if type == null:
			continue
		count += 1
		_same(file, "manahoar", type.tag == "oham", AiTrackFacts.kind_of_type(type, MANA_SOURCE) == AiTrack.Kind.MANAHOAR)
		_same(file, "fights", LEGACY.type_active(type), AiTrackFacts.fights_of(type))
	return count


func _same(label: String, what: String, old: Variant, now: Variant) -> void:
	_compared += 1
	if typeof(old) != typeof(now) and not (old is Array and now is Array):
		_lines.append("%s %s: old %s (%s) new %s (%s)" % [label, what, str(old), type_string(typeof(old)), str(now), type_string(typeof(now))])
	elif old != now:
		_lines.append("%s %s: old %s new %s" % [label, what, str(old), str(now)])
