extends RefCounted

## RFC-024 024b cases of rules_suite: the score of sacengine updateTarget (state.d:12925-12935) against the
## numbers worked out by hand from it, the pick that follows from them, and what the side can see.
## `run(host)` puts its bodies under `host` and removes them at the end. Nothing here needs a floor: the
## bodies do not simulate (physics off), only their positions and the picker/vision answers matter.

const UNIT_SCENE := preload("res://scenes/world/units/unit.tscn")
const UnitOrders := preload("res://scenes/world/units/unit_orders.gd")
const RULES := preload("res://data/match_rules.tres")
const TOL := 0.0001
## The bodies of these cases live in their own group so bodies left by other cases never count.
const GROUP := "target_cases"

var _host: Node3D
var _root: Node3D


func run(host: Node3D) -> Dictionary:
	_host = host
	_root = Node3D.new()
	_root.name = "TargetCases"
	_host.add_child(_root)
	var out := {}
	out["target_score_near"] = _near()
	out["target_score_far"] = _far()
	out["target_score_attacker"] = _attacker()
	out["target_score_current"] = _current()
	out["target_score_building"] = _building()
	out["target_score_cutoff"] = _cutoff()
	out["target_pick_closest_wins"] = _pick_closest()
	out["target_pick_attacker_wins"] = _pick_attacker()
	out["target_pick_current_wins"] = _pick_current()
	out["target_pick_threshold"] = _pick_threshold()
	out["target_vision_side"] = _vision_side()
	out["target_vision_expiry"] = _vision_expiry()
	out["target_attacker_wiring"] = _wiring()
	out["target_pacifist"] = _pacifist()
	out["target_guard_no_jitter"] = await _guard()
	_root.free()
	return out


static func _same(a: float, b: float) -> bool:
	return absf(a - b) <= TOL


## Hand-worked from state.d:12926-12931: d = 20 < 100 -> s = 1 - 0.75*0.2 = 0.85; s*s = 0.7225; x1.25.
func _near() -> Dictionary:
	var plain := TargetPicker.score(20.0, 100.0, false, false, false)
	var steep := TargetPicker.score(99.9, 100.0, false, false, false)
	var checks := {
		"d20": _same(plain, 0.7225 * 1.25),
		"d0": _same(TargetPicker.score(0.0, 100.0, false, false, false), 1.25),
		"d99_9": _same(steep, pow(1.0 - 0.75 * 0.999, 2.0) * 1.25),
	}
	return _verdict(checks, {"d20": plain})


## d >= ref -> s = 0.25*ref/d: d = 250 -> 0.1; s*s = 0.01; x1.25. The branch starts AT ref (0.25 -> 0.0625).
func _far() -> Dictionary:
	var checks := {
		"d250": _same(TargetPicker.score(250.0, 100.0, false, false, false), 0.01 * 1.25),
		"d100": _same(TargetPicker.score(100.0, 100.0, false, false, false), 0.0625 * 1.25),
		"ref150_d300": _same(TargetPicker.score(300.0, 150.0, false, false, false), pow(0.25 * 0.5, 2.0) * 1.25),
		"d_near_to_far_drop": TargetPicker.score(99.99, 100.0, false, false, false) > TargetPicker.score(100.0, 100.0, false, false, false),
	}
	return _verdict(checks, {})


## Last attacker x1.2 (state.d:12932): d = 60 -> s = 1 - 0.45 = 0.55; 0.3025*1.25*1.2.
func _attacker() -> Dictionary:
	var value := TargetPicker.score(60.0, 100.0, false, true, false)
	return _verdict({"d60": _same(value, 0.3025 * 1.25 * 1.2)}, {"d60": value})


## Current target x1.3 (state.d:12933), alone and together with the attacker.
func _current() -> Dictionary:
	var only := TargetPicker.score(60.0, 100.0, false, false, true)
	var both := TargetPicker.score(60.0, 100.0, false, true, true)
	var checks := {
		"current": _same(only, 0.3025 * 1.25 * 1.3),
		"both": _same(both, 0.3025 * 1.25 * 1.2 * 1.3),
	}
	return _verdict(checks, {"current": only, "both": both})


## A building keeps the bare score: no 1.25, no 1.2, no 1.3 (state.d:12930).
func _building() -> Dictionary:
	var plain := TargetPicker.score(20.0, 100.0, true, true, true)
	return _verdict({"bare": _same(plain, 0.7225)}, {"bare": plain})


## scoreCutoff (state.d:12961-12963): with the best weight the score at that distance is the threshold.
func _cutoff() -> Dictionary:
	var checks := {}
	var details := {}
	for pair in [[0.25, 100.0], [0.25, 150.0], [0.1, 100.0], [0.5, 100.0]]:
		var threshold: float = pair[0]
		var ref: float = pair[1]
		var cutoff := TargetPicker.score_cutoff(threshold, ref)
		var at_cutoff := TargetPicker.score(cutoff, ref, false, true, true)
		checks["t%s_r%d" % [threshold, int(ref)]] = _same(at_cutoff, threshold)
		details["cut_t%s_r%d" % [threshold, int(ref)]] = cutoff
	checks["zero_threshold_all"] = is_inf(TargetPicker.score_cutoff(0.0, 100.0))
	return _verdict(checks, details)


## Closer foe: 20 m (0.7225*1.25 = 0.9031) against a far one that hit first at 60 m (0.4538): the near one.
func _pick_closest() -> Dictionary:
	var set := _scene(Vector3.ZERO, [Vector3(20.0, 0.0, 0.0), Vector3(60.0, 0.0, 0.0)])
	var picker: TargetPicker = set["picker"]
	var near: Node3D = set["foes"][0]
	var far: Node3D = set["foes"][1]
	picker.note_attacker(far)
	var chosen := picker.pick((set["body"] as Node3D).global_position)
	var near_score := _score_of(picker, near)
	var far_score := _score_of(picker, far)
	var checks := {
		"chose_near": chosen == near,
		"near_score": _same(near_score, 0.7225 * 1.25),
		"far_score": _same(far_score, 0.3025 * 1.25 * 1.2),
	}
	_clean(set)
	return _verdict(checks, {"chosen": chosen.name if chosen else "-", "near": near_score, "far": far_score})


## The attacker's x1.2 can overturn a small gap: 50 m (0.3906*1.25 = 0.4883) against 53 m that hit first
## (0.3630*1.25*1.2 = 0.5445): the attacker wins.
func _pick_attacker() -> Dictionary:
	var set := _scene(Vector3.ZERO, [Vector3(50.0, 0.0, 0.0), Vector3(53.0, 0.0, 0.0)])
	var picker: TargetPicker = set["picker"]
	var far: Node3D = set["foes"][1]
	var before := picker.pick(Vector3.ZERO)
	picker.note_attacker(far)
	var after := picker.pick(Vector3.ZERO)
	var checks := {
		"nearest_without_attacker": before == set["foes"][0],
		"attacker_wins": after == far,
		"attacker_score": _same(_score_of(picker, far), pow(1.0 - 0.75 * 0.53, 2.0) * 1.25 * 1.2),
	}
	_clean(set)
	return _verdict(checks, {})


## The current target's x1.3 (hysteresis): the one at 50 m wins alone (0.4883); the one at 54 m, as the
## current target, scores 0.3540*1.25*1.3 = 0.5753 and keeps it.
func _pick_current() -> Dictionary:
	var set := _scene(Vector3.ZERO, [Vector3(50.0, 0.0, 0.0), Vector3(54.0, 0.0, 0.0)])
	var picker: TargetPicker = set["picker"]
	var body: UnitBody = set["body"]
	var first: Node3D = set["foes"][0]
	var second: Node3D = set["foes"][1]
	var without := picker.pick(Vector3.ZERO)
	body.target = second
	var with := picker.pick(Vector3.ZERO)
	var checks := {
		"nearest_without_target": without == first,
		"current_sticks": with == second,
		"current_score": _same(_score_of(picker, second), pow(1.0 - 0.75 * 0.54, 2.0) * 1.25 * 1.3),
	}
	body.target = null
	_clean(set)
	return _verdict(checks, {})


## Beyond the cutoff (85.6 m at 0.25) nothing is picked even in plain sight; at threshold 0 everything seen is.
func _pick_threshold() -> Dictionary:
	var set := _scene(Vector3.ZERO, [Vector3(90.0, 0.0, 0.0)])
	var picker: TargetPicker = set["picker"]
	var strict := picker.pick(Vector3.ZERO, 0.25)
	var loose := picker.pick(Vector3.ZERO, 0.0)
	var checks := {
		"beyond_cutoff": strict == null,
		"threshold_zero": loose == set["foes"][0],
		"score_below": TargetPicker.score(90.0, 100.0, false, false, false) < 0.25,
	}
	_clean(set)
	return _verdict(checks, {})


## A foe out of the sight of every body of the side is not picked; once an ally at its side sees it, it is,
## although it is farther than the picker's own sight (the whole side shares what it has seen).
func _vision_side() -> Dictionary:
	var vision := _vision()
	var set := _scene(Vector3.ZERO, [Vector3(130.0, 0.0, 0.0)])
	var picker: TargetPicker = set["picker"]
	var foe: Node3D = set["foes"][0]
	vision.observe(set["body"])
	var alone := picker.pick(Vector3.ZERO, 0.0)
	var seen_alone := vision.is_visible_to(1, foe)
	var ally := _unit(1, Vector3(120.0, 0.0, 0.0), "Ally")
	vision.observe(ally)
	var together := picker.pick(Vector3.ZERO, 0.0)
	var checks := {
		"unseen_not_picked": alone == null,
		"unseen_not_visible": not seen_alone,
		"ally_sees": vision.is_visible_to(1, foe),
		"seen_picked_beyond_own_sight": together == foe,
		"own_side_always_visible": vision.is_visible_to(2, foe),
		"other_side_does_not_share": not vision.is_visible_to(3, foe),
	}
	ally.free()
	_clean(set)
	vision.free()
	return _verdict(checks, {})


## A foe is visible 384 ticks after its mark and not after (state.d:29692); a building stays for good.
func _vision_expiry() -> Dictionary:
	var vision := _vision()
	var set := _scene(Vector3.ZERO, [Vector3(40.0, 0.0, 0.0)])
	var foe: Node3D = set["foes"][0]
	vision.observe(set["body"])
	var marked := vision.is_visible_to(1, foe)
	vision.tick += SideVision.SEEN_TICKS - 2
	var still := vision.is_visible_to(1, foe)
	vision.tick += 4
	var gone := not vision.is_visible_to(1, foe)
	var structure := Node3D.new()
	structure.name = "FakeStructure"
	structure.add_to_group("structure")
	_root.add_child(structure)
	vision.mark(1, structure)
	var building_mark := vision.last_seen_tick(1, structure)
	vision.tick += 100000
	var checks := {
		"marked": marked,
		"still_at_383": still,
		"gone_after_384": gone,
		"building_permanent": building_mark >= SideVision.PERMANENT,
	}
	structure.free()
	_clean(set)
	vision.free()
	return _verdict(checks, {})


## A strike of A on B (MeleeAttack.struck) makes A visible to B's side and B remember A as last attacker.
func _wiring() -> Dictionary:
	var vision := _vision()
	var a := _unit(1, Vector3.ZERO, "Hitter")
	var b := _unit(2, Vector3(300.0, 0.0, 0.0), "Hit")
	var before := vision.is_visible_to(2, a)
	a.emit_signal("struck", b, 25.0, 0.8, 0.1)
	var picker_b := b.get_node("TargetPicker") as TargetPicker
	var checks := {
		"unseen_before": not before,
		"visible_after": vision.is_visible_to(2, a),
		"last_attacker": picker_b.last_attacker_id == a.get_instance_id(),
		"a_not_marked_by_b": not vision.is_visible_to(1, b),
	}
	a.free()
	b.free()
	vision.free()
	return _verdict(checks, {})


## A pacifist (Farmer) never picks: closest_foe returns null before it asks the picker.
func _pacifist() -> Dictionary:
	var farmer := _unit(1, Vector3.ZERO, "Farmer", "zepe")
	var foe := _unit(2, Vector3(10.0, 0.0, 0.0), "Foe")
	var picked := farmer.closest_foe(Vector3.ZERO)
	var checks := {"null": picked == null, "has_picker": farmer.get_node_or_null("TargetPicker") != null}
	farmer.free()
	foe.free()
	return _verdict(checks, {})


## A GUARD_AREA unit at its anchor with a foe the side sees 150 m away (an ally stands next to the foe): it does
## not leave. Over 30 s its mode never changes and it stays within 2 m of the anchor. Before the fix the
## guard threshold was ~0 at the anchor, the foe was picked at any range and the unit ran out and back.
func _guard() -> Dictionary:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(800.0, 2.0, 800.0)
	shape.shape = box
	shape.position = Vector3(100.0, -1.0, 0.0)
	floor_body.add_child(shape)
	_root.add_child(floor_body)
	var vision := _vision()
	var guard := _unit(1, Vector3(0.0, 0.2, 0.0), "Guard")
	var ally := _unit(1, Vector3(140.0, 0.2, 20.0), "Spotter")
	var foe := _unit(2, Vector3(150.0, 0.2, 0.0), "Far", "nmuh")
	for body in [guard, ally, foe]:
		body.set_physics_process(true)
	for _f in 20:
		await _host.get_tree().physics_frame
	var anchor := guard.global_position
	guard.get_node("Orders").call("give", UnitOrders.Command.GUARD_AREA, null, anchor, Vector2.ZERO, 0.0)
	var changes := 0
	var last_mode := int(guard.mode)
	var farthest := 0.0
	var seen := false
	for _tick in 1800:
		await _host.get_tree().physics_frame
		seen = seen or vision.is_visible_to(1, foe)
		if int(guard.mode) != last_mode:
			changes += 1
			last_mode = int(guard.mode)
		farthest = maxf(farthest, Vector2(guard.global_position.x - anchor.x, guard.global_position.z - anchor.z).length())
	var checks := {
		"foe_seen_by_side": seen,
		"no_mode_changes": changes == 0,
		"stays_at_anchor": farthest <= 2.0,
	}
	var out := _verdict(checks, {"mode_changes": changes, "farthest_m": farthest})
	for node in [guard, ally, foe, vision, floor_body]:
		node.free()
	return out


func _vision() -> SideVision:
	var vision := SideVision.new()
	vision.name = "TestVision"
	vision.observer_groups = PackedStringArray([GROUP])
	vision.seen_groups = PackedStringArray([GROUP])
	_root.add_child(vision)
	return vision


func _unit(slot: int, at: Vector3, label: String, tag := "ycro") -> UnitBody:
	var unit: UnitBody = UNIT_SCENE.instantiate()
	unit.name = "%s%d" % [label, slot]
	unit.creature_tag = tag
	unit.owner_slot = slot
	unit.rules = RULES
	unit.idle_aggro = false
	unit.position = at
	unit.target_groups = PackedStringArray([GROUP])
	_root.add_child(unit)
	unit.add_to_group(GROUP)
	unit.set_physics_process(false)
	return unit


## A Trogg of slot 1 at `at` and one Druid of slot 2 per spot.
func _scene(at: Vector3, spots: Array) -> Dictionary:
	var body := _unit(1, at, "Picker")
	var picker := body.get_node("TargetPicker") as TargetPicker
	picker.record_scores = true
	var foes: Array[Node3D] = []
	for k in spots.size():
		foes.append(_unit(2, spots[k], "Foe%d" % k, "nmuh"))
	return {"body": body, "picker": picker, "foes": foes}


func _clean(set: Dictionary) -> void:
	(set["body"] as Node).free()
	for foe in set["foes"]:
		(foe as Node).free()


static func _score_of(picker: TargetPicker, node: Node3D) -> float:
	for entry in picker.last_scores:
		if entry["node"] == node:
			return float(entry["score"])
	return -1.0


static func _verdict(checks: Dictionary, details: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		if not bool(checks[key]):
			ok = false
	var out := details.duplicate()
	out["ok"] = ok
	out["checks"] = checks
	return out
