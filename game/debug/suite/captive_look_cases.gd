extends RefCounted

## RFC-055 055a-5 cases of rules_suite: what a creature a Sac Doctor holds looks like. A creature with a ragdoll hangs from its anchor while
## it is held, stays lying while a Convert doctor pumps it, goes back to its clips when let go alive and falls where it hangs when the doctor
## dies. Headless draws no model, so captive_world.gd mounts the baked one by hand and binds the RagdollDriver to it.
## Physics scenes move the determinism digests: this runs AFTER DETERMINISM_CASES and DEATH_CASES. `run(host)` adds its own floor and bodies
## under `host` and removes them at the end. No network: everything runs as solo.

const WORLD := preload("res://debug/suite/captive_world.gd")
const METRICS := preload("res://debug/bodies/ragdoll_metrics.gd")
## The highest a bone may be over the floor once a body lies (m).
const LYING_MAX_M := 0.7

var _w := WORLD.new()


func run(host: Node3D) -> Dictionary:
	_w.setup(host)
	await _w.wait_frames(2)
	var out := {}
	out["captive_pure_table"] = _pure_table()
	out["captive_hang"] = await _hang()
	out["captive_let_go_alive"] = await _let_go_alive()
	out["captive_dies_hanging"] = await _dies_hanging()
	out["captive_convert_keeps_lying"] = await _convert_keeps_lying()
	out["captive_late_join"] = await _late_join()
	_w.root.queue_free()
	return out


## CaptiveRules is the table of the plan, row by row: [was, now, can_hang, lies_as_ragdoll, look].
func _pure_table() -> Dictionary:
	var m := UnitBody.Mode
	var look := CaptiveRules.Look
	var rows := [
		[m.IDLE, m.HELD, true, false, look.HANG], [m.IDLE, m.HELD, false, false, look.CLIPS],
		[m.REVIVING, m.HELD, true, true, look.HANG_APPEAR], [m.REVIVING, m.HELD, false, false, look.CLIPS],
		[m.DEAD, m.REVIVING, true, true, look.KEEP_LYING], [m.DEAD, m.REVIVING, false, false, look.STAND_APPEAR],
		[m.HELD, m.IDLE, true, false, look.LET_GO], [m.HELD, m.IDLE, false, false, look.LET_GO],
		[m.REVIVING, m.IDLE, true, false, look.STAND_APPEAR], [m.REVIVING, m.IDLE, false, false, look.LET_GO],
		[m.HELD, m.DEAD, true, false, look.NONE], [m.IDLE, m.DEAD, false, false, look.NONE],
		[m.HELD, m.HELD, true, false, look.HANG],  # a peer that joins late: already held, the model binds now
	]
	var checks := {}
	for i in rows.size():
		var row: Array = rows[i]
		checks["row_%d" % i] = CaptiveRules.on_change(row[0], row[1], row[2], row[3]) == row[4]
	return _w.verdict(checks)


## Taken by a doctor, a creature with a ragdoll hangs by its anchor, follows the body up and shows no clip of the captive.
func _hang() -> Dictionary:
	var s := await _w.hanging(WORLD.RULES)
	var ragdoll: RagdollDriver = s.driver
	var model: BodyModel = s.model
	var checks := {"can_hang": ragdoll.can_hang(), "taken": s.taken}
	checks["hangs"] = ragdoll.pose() == RagdollDriver.Pose.HANG and ragdoll.is_running()
	checks["no_captive_clip"] = s.unit.captive_role.is_empty()
	checks["anchor_follows"] = model.hang_bone != null and model.hang_bone.global_position.y > 1.0
	checks["no_nan"] = not METRICS.has_nan(_w.bone_points(model))
	_w.release(s)
	return _w.verdict(checks)


## Let go alive: the ragdoll is off, the skeleton is back at rest for the clips and the creature answers orders again.
func _let_go_alive() -> Dictionary:
	var s := await _w.hanging(WORLD.RULES)
	var ragdoll: RagdollDriver = s.driver
	var skeleton: Skeleton3D = s.model.skeleton()
	Captive.of(s.unit).release()
	await _w.wait_frames(10)
	var checks := {"alive": not s.unit.is_dead() and s.unit.is_in_group("unit"), "idle": s.unit.mode == UnitBody.Mode.IDLE}
	checks["ragdoll_off"] = ragdoll.pose() == RagdollDriver.Pose.OFF and not ragdoll.is_running()
	checks["at_rest"] = skeleton.get_bone_global_pose(10).is_equal_approx(skeleton.get_bone_global_rest(10))
	_w.release(s)
	return _w.verdict(checks)


## The doctor dies holding it (the rule says it dies): the ragdoll that hung falls where it is, settles and freezes lying.
func _dies_hanging() -> Dictionary:
	var rules := WORLD.RULES.duplicate() as MatchRules
	rules.carried_dies_when_dropped = true
	var s := await _w.hanging(rules)
	var ragdoll: RagdollDriver = s.driver
	var corpse: Corpse = s.unit.corpse()
	s.doctor.kill(2)
	await _w.wait_until(func() -> bool: return corpse.is_settled)
	var checks := {"dead": s.unit.is_dead(), "falls": ragdoll.pose() == RagdollDriver.Pose.FALL}
	await _w.wait_until(func() -> bool: return not ragdoll.is_running())
	checks["froze_as_fall"] = not ragdoll.is_running() and ragdoll.pose() == RagdollDriver.Pose.FALL
	checks["lies_flat"] = METRICS.top_ratio(_w.bone_points(s.model), s.unit.global_position.y, 1.0) < LYING_MAX_M
	_w.release(s)
	return _w.verdict(checks)


## A corpse lying as a ragdoll stays lying while a Convert doctor pumps it, and hangs as soon as the doctor takes it.
func _convert_keeps_lying() -> Dictionary:
	var body := _w.make_unit(Vector3(0.0, 0.0, 6.0))
	var model := _w.mount_model(body)
	var ragdoll := _w.driver_of(body)
	ragdoll.bind_model(model)
	var carrier := _w.make_doctor(WORLD.RULES)
	await _w.wait_frames(5)
	(body.find_child("Health", false, false) as Health).damage(99999.0, 1)
	var corpse := body.corpse()
	await _w.wait_until(func() -> bool: return corpse.is_settled)
	await _w.wait_until(func() -> bool: return not ragdoll.is_running())
	var lying := model.skeleton().get_bone_global_pose(10)
	var captive := Captive.of(body)
	var checks := {"revived": captive.revive(10.0, 0.5)}
	await _w.wait_frames(40)
	checks["still_lying"] = body.is_reviving() and ragdoll.pose() == RagdollDriver.Pose.FALL and not ragdoll.is_running()
	checks["did_not_move"] = lying.is_equal_approx(model.skeleton().get_bone_global_pose(10))
	checks["taken"] = captive.take(carrier)
	await _w.wait_until(func() -> bool: return ragdoll.pose() == RagdollDriver.Pose.HANG)
	checks["hangs_when_taken"] = ragdoll.pose() == RagdollDriver.Pose.HANG
	body.free()
	carrier.free()
	return _w.verdict(checks)


## A model that binds after the creature was already taken (a peer that joins late) hangs at once, without a fade.
func _late_join() -> Dictionary:
	var body := _w.make_unit(Vector3(0.0, 0.0, 6.0))
	var carrier := _w.make_doctor(WORLD.RULES)
	await _w.wait_frames(20)
	var checks := {"taken": Captive.of(body).take(carrier)}
	await _w.wait_frames(10)
	var ragdoll := _w.driver_of(body)
	ragdoll.bind_model(_w.mount_model(body))
	await _w.wait_frames(10)
	checks["hangs"] = body.is_held() and ragdoll.pose() == RagdollDriver.Pose.HANG
	body.free()
	carrier.free()
	return _w.verdict(checks)
