extends RefCounted

## RFC-061d cases of rules_suite: Animate Dead. The creature of an own corpse starts to rise as soon as the cast starts, takes `reviveTime`
## (300 ticks), climbs 2 m, turns twice, stands up with all its health and its soul goes; the effect everybody sees lasts as long; a cut cast
## does not undo it; the spell refuses a soul with no corpse, an enemy's, a dropped one, one already reviving, out of range, no mana.
## No network: the server paths run as solo. `run(host)` adds its own world and removes it.

const WORLD := preload("res://debug/suite/soul_world.gd")

var _w := WORLD.new()


func run(host: Node3D) -> Dictionary:
	_w.build(host, "AnimateDeadCases")
	var out := {}
	out["animate_dead_scene"] = _scene()
	out["animate_dead_revive"] = await _revive()
	out["animate_dead_cut_cast"] = await _cut_cast()
	out["animate_dead_refusals"] = await _refusals()
	_w.clear()
	return out


func _scene() -> Dictionary:
	var checks := {}
	var spell := GameData.spell("deda")
	var action := spell.action.instantiate() as AnimateDeadAction if spell != null and spell.action != null else null
	checks["action"] = action != null and action.pick == SpellAction.Pick.SOUL and action._get_configuration_warnings().is_empty()
	var revive := action.revive_scene.instantiate() as FastRevive if action != null and action.revive_scene != null else null
	checks["slow_knobs"] = revive != null and revive.revive_ticks == 300 and revive.rise_ticks == 150 and is_equal_approx(revive.turns, 2.0)
	if revive != null:
		revive.free()
	if action != null:
		action.free()
	return _w.verdict("animate_dead_scene", checks)


## The whole revival from the click: REVIVING at once, 300 ticks (+- 1), 2 m up, 2 turns, alive with all its health, the soul gone.
func _revive() -> Dictionary:
	var checks := {}
	var wizard := _w.wizard(1, Vector3.ZERO, "charnel")
	await _land(wizard)
	var dead := await _w.corpse_with_soul(Vector3(25.0, 0.0, 0.0), 1)
	var soul := _w.soul_of(dead)
	var health := dead.get_node("Health") as Health
	var caster := wizard.get_node("Caster") as Caster
	var pool := wizard.get_node("ManaPool") as ManaPool
	var mana := pool.current
	var y0 := dead.global_position.y
	checks["dead_before"] = dead.is_dead() and soul != null and health.current <= 0.0
	checks["spell_accepts_it"] = caster.action_status("deda", soul.global_position, soul).is_empty()
	var start := MatchClock.now()
	caster.request_cast("deda", soul.global_position, soul)
	checks["casting"] = caster.is_casting()
	checks["rises_at_once"] = dead.is_reviving() and soul.state == Soul.State.REVIVING
	var effect := _effect()
	checks["effect_born_with_it"] = effect != null and effect.ticks == 300
	var peak := 0.0
	var turned := 0.0
	var last_yaw := dead.rotation.y
	var done := -1
	var effect_alive_until := 0
	for _i in 340:
		await _w.frames(1)
		if is_instance_valid(effect) and not effect.is_queued_for_deletion():
			effect_alive_until = MatchClock.now() - start
		peak = maxf(peak, dead.global_position.y - y0)
		turned += absf(angle_difference(last_yaw, dead.rotation.y))
		last_yaw = dead.rotation.y
		if not dead.is_reviving():
			done = MatchClock.now() - start
			break
	checks["takes_300_ticks"] = absi(done - 300) <= 2
	checks["climbs_2_m"] = absf(peak - 2.0) <= 0.05
	checks["turns_twice"] = absf(turned - 4.0 * PI) <= 0.3
	checks["stands_alive"] = not dead.is_dead() and health.current == health.maximum
	await _w.frames(3)
	checks["soul_goes"] = not is_instance_valid(soul) or soul.is_queued_for_deletion()
	checks["mana_spent"] = absf(mana - pool.current - 300.0) <= 2.0
	checks["effect_lasts_as_long"] = absi(effect_alive_until - 300) <= 3
	await _w.frames(4)
	checks["effect_gone"] = _effect() == null
	wizard.queue_free()
	dead.queue_free()
	return _w.verdict("animate_dead_revive", checks)


## The wizard dies right after the cast starts: the creature goes on rising (the original starts the revival with the cast).
func _cut_cast() -> Dictionary:
	var checks := {}
	var wizard := _w.wizard(1, Vector3.ZERO, "charnel")
	await _land(wizard)
	var dead := await _w.corpse_with_soul(Vector3(25.0, 0.0, 0.0), 1)
	var soul := _w.soul_of(dead)
	(wizard.get_node("Caster") as Caster).request_cast("deda", soul.global_position, soul)
	await _w.frames(3)
	(wizard.get_node("Health") as Health).damage(99999.0, 3)
	await _w.frames(320)
	checks["still_revives"] = not dead.is_dead() and not dead.is_reviving()
	wizard.queue_free()
	dead.queue_free()
	return _w.verdict("animate_dead_cut_cast", checks)


func _refusals() -> Dictionary:
	var checks := {}
	var wizard := _w.wizard(1, Vector3.ZERO, "charnel")
	await _land(wizard)
	var caster := wizard.get_node("Caster") as Caster
	var own := await _w.corpse_with_soul(Vector3(20.0, 0.0, 0.0), 1)
	var enemy := await _w.corpse_with_soul(Vector3(0.0, 0.0, 20.0), 3)
	var dropped := await _w.corpse_with_soul(Vector3(-20.0, 0.0, 0.0), 1)
	var far := await _w.corpse_with_soul(Vector3(100.0, 0.0, 0.0), 1)
	var free := _w.free_soul(Vector3(0.0, 0.0, -20.0))
	var own_soul := _w.soul_of(own)
	var enemy_soul := _w.soul_of(enemy)
	var dropped_soul := _w.soul_of(dropped)
	var far_soul := _w.soul_of(far)
	dropped_soul.dropped = true
	checks["own_ok"] = caster.action_status("deda", own_soul.global_position, own_soul).is_empty()
	checks["not_an_enemy_soul"] = caster.action_status("deda", enemy_soul.global_position, enemy_soul) == SpellAction.BAD_TARGET
	checks["not_a_dropped_soul"] = caster.action_status("deda", dropped_soul.global_position, dropped_soul) == SpellAction.BAD_TARGET
	checks["not_a_soul_without_corpse"] = caster.action_status("deda", free.global_position, free) == SpellAction.BAD_TARGET
	checks["not_the_body"] = caster.action_status("deda", own.global_position, own) == SpellAction.BAD_TARGET
	checks["out_of_range"] = caster.action_status("deda", far_soul.global_position, far_soul) == SpellAction.OUT_OF_RANGE
	var pool := wizard.get_node("ManaPool") as ManaPool
	pool.current = 100.0
	checks["no_mana"] = caster.action_status("deda", own_soul.global_position, own_soul) == SpellAction.NO_MANA
	pool.current = pool.maximum
	caster.request_cast("deda", own_soul.global_position, own_soul)
	await _w.frames(2)
	var again := caster.action_for("deda").check(wizard, GameData.spell("deda"), own_soul.global_position, own_soul, "")
	checks["not_one_already_reviving"] = again.status == SpellAction.BAD_TARGET
	for body: Node in [wizard, own, enemy, dropped, far, free]:
		if is_instance_valid(body):
			body.queue_free()
	return _w.verdict("animate_dead_refusals", checks)


func _effect() -> AnimateDeadFx:
	for child in _w.spells.get_children():
		if child is AnimateDeadFx and not child.is_queued_for_deletion():
			return child as AnimateDeadFx
	return null


func _land(wizard: WizardBody) -> void:
	await _w.until(func() -> bool: return wizard.is_on_floor(), 180)
