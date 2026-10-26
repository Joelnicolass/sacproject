extends RefCounted

## RFC-020d cases of rules_suite: the ring of doctors, the numbers of the ritual (SacrificeMath) and the
## wizard under ritual (GhostForm). `run(host)` adds its own bodies under `host` and removes them.

const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const ALTAR_SCENE := preload("res://scenes/map/props/altar.tscn")
const RULES := preload("res://data/match_rules.tres")
const GOD := "james"

var _host: Node3D
var _root: Node3D


func run(host: Node3D) -> Dictionary:
	_host = host
	_root = Node3D.new()
	_root.name = "RitualCases"
	_host.add_child(_root)
	var out := {}
	out["ritual_ring"] = _ring()
	out["ritual_numbers"] = _numbers()
	out["ghost_under_ritual"] = await _ghost_under_ritual()
	_root.queue_free()
	return out


## 4 points at 20 m in 45° + 90°·k; at progress 1 they are at 17 m and a quarter turn further; the
## next round starts where the last ended.
func _ring() -> Dictionary:
	var checks := {}
	var center := Vector3(100.0, 5.0, -40.0)
	var points: Array[Vector3] = []
	for k in 4:
		points.append(SacrificeMath.ring_point(center, k, 0.0))
	var all_20 := true
	var quarter := true
	var diagonal := true
	for k in 4:
		var offset := points[k] - center
		all_20 = all_20 and is_equal_approx(Vector2(offset.x, offset.z).length(), 20.0) and is_equal_approx(offset.y, 0.0)
		## 45° off an axis: |x| == |z|
		diagonal = diagonal and is_equal_approx(absf(offset.x), absf(offset.z))
		var next := points[(k + 1) % 4] - center
		quarter = quarter and absf(absf(Vector2(offset.x, offset.z).angle_to(Vector2(next.x, next.z))) - PI * 0.5) < 0.0001
	checks["four_at_20m"] = all_20 and points.size() == 4
	checks["diagonals_45deg"] = diagonal
	checks["quarter_apart"] = quarter
	var distinct := true
	for i in 4:
		for j in range(i + 1, 4):
			distinct = distinct and not points[i].is_equal_approx(points[j])
	checks["distinct"] = distinct
	var end0 := SacrificeMath.ring_point(center, 0, 1.0)
	var offset0 := end0 - center
	checks["end_17m"] = is_equal_approx(Vector2(offset0.x, offset0.z).length(), 17.0)
	checks["end_is_next_start_direction"] = absf(Vector2(offset0.x, offset0.z).normalized().dot(Vector2((points[1] - center).x, (points[1] - center).z).normalized()) - 1.0) < 0.0001
	checks["radius_20_until_4_fifths"] = is_equal_approx(Vector2((SacrificeMath.ring_point(center, 0, 0.8) - center).x, (SacrificeMath.ring_point(center, 0, 0.8) - center).z).length(), 20.0)
	## Round 1 of doctor 0 starts where round 0 of doctor 1 started.
	checks["next_round_same_set"] = SacrificeMath.ring_point(center, 4, 0.0).is_equal_approx(points[0]) and SacrificeMath.ring_point(center, 5, 0.0).is_equal_approx(points[1])
	checks["yaw_toward"] = is_equal_approx(SacrificeMath.yaw_toward(Vector3.ZERO, Vector3(0.0, 0.0, 5.0)), 0.0) and is_equal_approx(SacrificeMath.yaw_toward(Vector3.ZERO, Vector3(5.0, 3.0, 0.0)), PI * 0.5)
	return _verdict(checks)


## Drain per round with 1 and 4 souls, rounds of Convert, the push and the schedule.
func _numbers() -> Dictionary:
	var checks := {}
	checks["health_1_soul"] = is_equal_approx(SacrificeMath.desecrate_health(1), 400.0)
	checks["health_4_souls"] = is_equal_approx(SacrificeMath.desecrate_health(4), 1000.0)
	checks["mana_1_soul"] = is_equal_approx(SacrificeMath.desecrate_mana(1), 80.0)
	checks["mana_4_souls"] = is_equal_approx(SacrificeMath.desecrate_mana(4), 200.0)
	checks["rules_match_original"] = is_equal_approx(RULES.desecrate_health_per_round, 200.0) and is_equal_approx(RULES.desecrate_mana_per_round, 40.0)
	checks["convert_rounds_540"] = SacrificeMath.convert_rounds(540.0) == 1
	checks["convert_rounds_800"] = SacrificeMath.convert_rounds(800.0) == 2
	checks["convert_rounds_4500"] = SacrificeMath.convert_rounds(4500.0) == 9
	## The drain window: 250 ticks of 1/60 s inside the 4.5 s of shooting.
	checks["drain_window_fits_shoot"] = RULES.ritual_drain_start_s + RULES.ritual_drain_s <= RULES.ritual_shoot_s + 0.001
	checks["drain_per_second_1_soul"] = absf(SacrificeMath.desecrate_health(1) / RULES.ritual_drain_s - 96.0) < 0.1
	checks["round_is_13_5"] = is_equal_approx(RULES.ritual_walk_s + RULES.ritual_shoot_s + RULES.ritual_wait_s, 13.5) and is_equal_approx(RULES.ritual_setup_s, 5.0)
	checks["push_full_at_inner"] = is_equal_approx(BodyNudge.push_speed(5.0, 5.0, 20.0, 20.0), 20.0)
	checks["push_half_at_12_5"] = is_equal_approx(BodyNudge.push_speed(12.5, 5.0, 20.0, 20.0), 10.0)
	checks["push_none_at_edge"] = is_equal_approx(BodyNudge.push_speed(20.0, 5.0, 20.0, 20.0), 0.0) and is_equal_approx(BodyNudge.push_speed(25.0, 5.0, 20.0, 20.0), 0.0)
	var at_setup := SacrificeMath.schedule(4.9)
	var at_walk := SacrificeMath.schedule(5.0)
	var at_shoot := SacrificeMath.schedule(5.0 + 4.5 + 1.0)
	var at_wait := SacrificeMath.schedule(5.0 + 9.0 + 0.5)
	var round_two := SacrificeMath.schedule(5.0 + 13.5 * 2.0 + 1.0)
	checks["schedule_setup"] = at_setup["phase"] == &"setup" and at_setup["round"] == 0
	checks["schedule_walk"] = at_walk["phase"] == &"walk" and at_walk["round"] == 0
	checks["schedule_shoot"] = at_shoot["phase"] == &"shoot" and is_equal_approx(at_shoot["t"], 1.0)
	checks["schedule_wait"] = at_wait["phase"] == &"wait"
	checks["schedule_round_2"] = round_two["round"] == 2 and round_two["phase"] == &"walk"
	return _verdict(checks)


## A wizard that dies with a ritual on his altar vanishes (GONE) even with an altar in play; without
## the ritual he rises as a ghost. A ghost with a ritual on his altar turns back with at least 1 life.
func _ghost_under_ritual() -> Dictionary:
	var checks := {}
	var altar := ALTAR_SCENE.instantiate() as Altar
	altar.owner_slot = 1
	_root.add_child(altar)
	var free_wizard := _wizard(Vector3(0.0, 0.1, 10.0))
	var ritual_wizard := _wizard(Vector3(10.0, 0.1, 10.0))
	var ghost_wizard := _wizard(Vector3(20.0, 0.1, 10.0))
	await _frames(5)
	var free_ghost := free_wizard.ghost as GhostForm
	var ritual_ghost := ritual_wizard.ghost as GhostForm
	var ghost_ghost := ghost_wizard.ghost as GhostForm
	ritual_ghost.add_desecration()
	checks["under_ritual_flag"] = ritual_ghost.under_ritual and ritual_ghost.desecrations == 1
	ritual_ghost.remove_desecration()
	checks["flag_clears"] = not ritual_ghost.under_ritual and ritual_ghost.desecrations == 0
	ritual_ghost.add_desecration()
	(free_wizard.health as Health).damage(99999.0, 2)
	(ritual_wizard.health as Health).damage(99999.0, 2)
	var guard := 0
	while guard < 1800 and (free_ghost.stage == GhostForm.Stage.DYING or ritual_ghost.stage == GhostForm.Stage.DYING):
		await _frames(1)
		guard += 1
	checks["free_wizard_rises"] = free_ghost.stage == GhostForm.Stage.RISING or free_ghost.stage == GhostForm.Stage.GHOST
	checks["ritual_wizard_vanishes"] = ritual_ghost.stage == GhostForm.Stage.GONE
	checks["vanish_is_4s"] = is_equal_approx(ritual_ghost.vanish_seconds(), RULES.wizard_vanish_ritual_s)
	## A ghost with a ritual on his altar turns back to the body with at least 1 life.
	var health := ghost_wizard.health as Health
	health.current = 0.0
	ghost_ghost.stage = GhostForm.Stage.GHOST
	await _frames(3)
	checks["ghost_stays_without_ritual"] = ghost_ghost.stage == GhostForm.Stage.GHOST
	ghost_ghost.add_desecration()
	await _frames(3)
	checks["ghost_forced_back"] = ghost_ghost.stage == GhostForm.Stage.UNGHOSTING or ghost_ghost.stage == GhostForm.Stage.ALIVE
	checks["back_with_1_life"] = health.current >= 1.0
	for node in [free_wizard, ritual_wizard, ghost_wizard, altar]:
		if is_instance_valid(node):
			node.free()
	return _verdict(checks)


func _wizard(at: Vector3) -> WizardBody:
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = 1
	wizard.god = GOD
	wizard.position = at
	_root.add_child(wizard)
	return wizard


func _frames(count: int) -> void:
	for _i in count:
		await _host.get_tree().physics_frame


func _verdict(checks: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		if checks[key] is bool and not checks[key]:
			ok = false
			print("ritual_cases: falla %s" % key)
	checks["ok"] = ok
	return checks
