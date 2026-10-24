extends "res://debug/suite/zone_case_base.gd"

## RFC-061h cases of rules_suite: the clouds (Rain of Frogs, Rain of Fire, Plague, Cloudkill, Bombardment) through ZoneAction, GroundZone,
## ZoneDropper, DropLauncher and the drops they make: the spell is in its god's book, the rates of a second, how long a drop flies, what it
## does where it ends (damage, fire, poison, stun, frogs that stick and slow), the cloud that chases, the bolts and what a cut cast does.
## No network: the server paths run as solo. `run(host)` adds its own bodies and removes them.

const SPELLS := {"grfr": "persephone", "rifr": "pyro", "galp": "charnel", "likc": "stratos", "rtem": "james"}
const KINDS := {"grfr": "RainOfFrogs", "rifr": "RainOfFire", "galp": "Plague", "likc": "Cloudkill", "rtem": "Bombardment"}
const TPS := 60.0


func run(host: Node3D) -> Dictionary:
	begin(host, "CloudCases")
	var out := {}
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			only = arg.trim_prefix("--case=")
	var cases := {"scenes": _scenes, "rules": _rules, "rates": _rates, "frog": _frog, "fire": _fire, "plague": _plague, "meteor": _meteor,
		"cloudkill": _cloudkill, "cast": _cast, "ai": _ai, "lights": _lights}
	for name in cases:
		if only.is_empty() or only == name:
			out["cloud_" + name] = await (cases[name] as Callable).call()
	finish()
	return out


## Each spell has its action and its zone scene, the zone scene is registered, nothing warns, and every cloud is in its god's book.
func _scenes() -> Dictionary:
	var checks := {}
	for tag in SPELLS:
		var spell := GameData.spell(tag)
		checks[tag + "_has_action"] = spell != null and spell.action != null
		var action := spell.action.instantiate() as ZoneAction if spell and spell.action else null
		checks[tag + "_is_zone_action"] = action != null
		if action != null:
			action.tag = tag
			checks[tag + "_kind"] = action.kind == KINDS[tag] and _spawner.zones.has(action.kind)
			checks[tag + "_no_warnings"] = action._get_configuration_warnings().is_empty()
			checks[tag + "_ground_pick"] = action.pick == SpellAction.Pick.GROUND
			action.free()
		var zone := (_spawner.zones[KINDS[tag]] as PackedScene).instantiate() as GroundZone
		checks[tag + "_zone_spell"] = zone != null and zone.spell == spell and zone.hold_is_spell_duration
		for child in zone.find_children("*", "", true, false):
			if child is ZoneDropper or child is DropLauncher or child is BoltLauncher or child is ZoneMover or child is CloudLook:
				checks[tag + "_" + str(child.name) + "_warns"] = child._get_configuration_warnings().is_empty()
		zone.free()
		var wizard := _wizard(1, Vector3(-500.0, 0.0, 500.0), str(SPELLS[tag]), 8)
		await _frames(2)
		var caster := Caster.of(wizard)
		checks[tag + "_in_book"] = caster.spellbook.index_of(tag) >= 0
		wizard.queue_free()
	for kind in ["RainFrog", "FireDrop", "PlagueDrop", "Meteor"]:
		checks[kind + "_registered"] = _spawner.projectiles.has(kind) and _spawner.projectiles[kind].can_instantiate()
	var meteor := (_spawner.projectiles["Meteor"] as PackedScene).instantiate()
	var marks: Array[PackedScene] = (meteor.get_node("Blast") as DropBlast).ground_marks
	var names := []
	for mark in marks:
		names.append(((mark.instantiate() as ScarMark).texture.resource_path.get_file()))
	checks["meteor_marks_gscr_ecrk"] = names == ["gscr.png", "ecrk.png"]
	meteor.free()
	var beam := load("res://data/fx/beams/lightning.tres") as BeamType
	checks["cloudkill_bolt_burns"] = beam != null and beam.scene.resource_path.ends_with("burning_beam_fx.tscn")
	checks["cloudkill_follows"] = (GameData.spell("likc").action.instantiate() as ZoneAction).follows_target
	checks["cloudkill_replicates"] = (_spawner.zones["Cloudkill"] as PackedScene).instantiate().get("replicates_position") == true
	await _frames(2)
	return _verdict("cloud_scenes", checks)


## The plain numbers: the arc that lands on its goal at the time given, and the straight fall that does not.
func _rules() -> Dictionary:
	var checks := {}
	var start := Vector3(0.0, -1.0, 0.0)
	var goal := Vector3(40.0, 0.0, 30.0)
	var v := ZoneRules.launch_velocity(start, goal, 12.0, 20.0, true)
	var landing := start + v * 12.0 - Vector3(0.0, 0.5 * 20.0 * 144.0, 0.0)
	checks["lob_lands_on_goal"] = landing.distance_to(goal) < 1e-3
	checks["lob_goes_up"] = v.y > 100.0
	var fall := ZoneRules.launch_velocity(Vector3(5.0, 90.0, 5.0), Vector3(5.0, 0.0, 5.0), 2.0, 30.0, false)
	checks["fall_is_45"] = fall.is_equal_approx(Vector3(0.0, -45.0, 0.0))
	var line := ZoneRules.launch_velocity(Vector3(0.0, 90.0, 0.0), Vector3(30.0, 0.0, 0.0), 1.4, 0.0, false)
	checks["line_in_1_4"] = (Vector3(0.0, 90.0, 0.0) + line * 1.4).is_equal_approx(Vector3(30.0, 0.0, 0.0))
	return _verdict("cloud_rules", checks)


## Per second: in `seconds` of a cloud acting, `rate × seconds` drops are born (within a quarter), none before it acts and none after it.
func _rates() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, Vector3(-80.0, 0.0, 0.0), "persephone", 8)
	await _frames(2)
	var spells := _root.get_node("Spells")
	var seconds := 10.0
	for tag in ["grfr", "rifr", "galp", "rtem"]:
		var rate: float = {"grfr": 10.0, "rifr": 3.0, "galp": 3.0, "rtem": 2.0}[tag]
		var count := [0]
		var counter := func(_node: Node) -> void: count[0] += 1
		var zone := _cloud(KINDS[tag], Vector3(0.0, 0.0, 0.0), wizard, 30)
		zone.spell = zone.spell.duplicate()
		zone.spell.duration = seconds
		zone.hold_is_spell_duration = true
		spells.child_entered_tree.connect(counter)
		await _frames(25)
		checks[tag + "_none_while_casting"] = count[0] == 0 and zone.phase == GroundZone.Phase.CASTING
		zone.release()
		var started: int = count[0]
		await _frames(MatchClock.ticks_for(seconds) + 5)
		var born: int = count[0] - started
		checks[tag + "_rate"] = absf(float(born) - rate * seconds) <= maxf(rate * seconds * 0.25, 3.0 * sqrt(rate * seconds))
		checks[tag + "_stops"] = zone.phase >= GroundZone.Phase.ENDING
		var after: int = count[0]
		await _frames(30)
		checks[tag + "_none_after"] = count[0] == after
		spells.child_entered_tree.disconnect(counter)
		await _frames(MatchClock.ticks_for(1.5) + MatchClock.ticks_for(14.0))
		checks[tag + "_zone_freed"] = not is_instance_valid(zone)
		checks[tag + "_drops_gone"] = _host.get_tree().get_nodes_in_group(ZoneDrop.GROUP).is_empty()
	wizard.queue_free()
	await _frames(2)
	return _verdict("cloud_rates", checks)


## A frog: it falls 90 m in 82 ticks, sits 0.5 s and jumps; the one that touches a creature sticks (×0.6 each, ×0.36 for two) and bursts
## 5 s later for 90; nothing else is hurt by it.
func _frog() -> Dictionary:
	var checks := {}
	var spell := GameData.spell("grfr")
	var wizard := _wizard(1, Vector3(-300.0, 0.0, 0.0), "persephone", 8)
	var frog := _drop("RainFrog", Vector3(0.0, 90.0, 0.0), Vector3(0.0, 0.0, 0.0), 2.0, spell, wizard)
	var t := 0
	while frog.status == ZoneDrop.Status.FLYING and t < 400:
		await _frames(1)
		t += 1
	checks["lands_at_82"] = absi(t - 82) <= 2
	checks["sits"] = frog.status == ZoneDrop.Status.RESTING and absf(frog.global_position.y) < 0.01
	var sat := 0
	while frog.status == ZoneDrop.Status.RESTING and sat < 100:
		await _frames(1)
		sat += 1
	checks["sits_half_a_second"] = absi(sat - MatchClock.ticks_for(0.5) - 1) <= 2
	checks["jumps"] = frog.status == ZoneDrop.Status.FLYING and frog.velocity.y > 0.0
	frog.finish(null)
	await _frames(2)
	var body := _still(_tough(Vector3(60.0, 0.0, 0.0), 3))
	var health := body.get_node("Health") as Health
	var other := _still(_tough(Vector3(80.0, 0.0, 0.0), 3))
	await _frames(3)
	var before := health.current
	var first := _drop("RainFrog", Vector3(60.0, 4.0, 0.0), Vector3(60.0, 0.0, 0.0), 2.0, spell, wizard)
	var second := _drop("RainFrog", Vector3(60.2, 4.5, 0.1), Vector3(60.2, 0.0, 0.1), 2.0, spell, wizard)
	var stuck := 0
	while stuck < 200 and (first.status != ZoneDrop.Status.ATTACHED or second.status != ZoneDrop.Status.ATTACHED):
		await _frames(1)
		stuck += 1
	checks["both_stick"] = first.status == ZoneDrop.Status.ATTACHED and second.status == ZoneDrop.Status.ATTACHED
	await _frames(2)
	var clinging := Clinging.of(body)
	checks["counted"] = clinging.count_of(Clinging.FROGS) == 2
	checks["slow_x0_36"] = absf(body.speed_factor - 0.36) < 0.001
	checks["not_hurt_yet"] = health.current >= before - 0.5
	var ticks := 0
	while is_instance_valid(first) and not first.is_queued_for_deletion() and ticks < 600:
		await _frames(1)
		ticks += 1
	await _frames(MatchClock.ticks_for(0.5))
	checks["bursts_at_5_s"] = absi(ticks - MatchClock.ticks_for(5.0)) <= 6
	var resist := health.resistance(Health.SPLASH_SPELL)
	var took := before - health.current
	checks["two_frogs_180"] = absf(took - 2.0 * 90.0 * resist) <= 2.0 * 90.0 * resist * TOLERANCE + 1.0
	checks["other_untouched"] = (other.get_node("Health") as Health).current >= (other.get_node("Health") as Health).maximum - 0.5
	await _frames(MatchClock.ticks_for(1.0))
	checks["pace_back"] = absf(body.speed_factor - 1.0) < 0.001
	for node: Node in [wizard, body, other]:
		node.queue_free()
	await _frames(2)
	return _verdict("cloud_frog", checks)


## A drop of fire: 84 ticks in a straight line (no gravity); 500 to the body it ends on, less by distance to the others within 5 m, and a
## fire on all of them.
func _fire() -> Dictionary:
	var checks := {}
	var spell := GameData.spell("rifr")
	var wizard := _wizard(1, Vector3(-300.0, 0.0, 0.0), "pyro", 8)
	var free := _drop("FireDrop", Vector3(150.0, 60.0, 0.0), Vector3(180.0, 0.0, 0.0), 1.4, spell, wizard)
	var ended := {"at": Vector3.ZERO, "n": 0}
	free.ended.connect(func(_b: Node3D, at: Vector3) -> void: ended["at"] = at)
	var t := 0
	var mid := Vector3.ZERO
	while is_instance_valid(free) and not free.is_queued_for_deletion() and t < 300:
		await _frames(1)
		t += 1
		if t == 42:
			mid = free.global_position
	checks["flies_84"] = absi(t - 84) <= 2
	checks["straight_midpoint"] = mid.distance_to(Vector3(165.0, 30.0, 0.0)) < 1.0
	checks["lands_on_goal"] = (ended["at"] as Vector3).distance_to(Vector3(180.0, 0.0, 0.0)) < 1.0
	var a := _still(_tough(Vector3(200.0, 0.0, 0.0), 3))
	var b := _still(_tough(Vector3(202.0, 0.0, 0.0), 3))
	var far := _still(_tough(Vector3(212.0, 0.0, 0.0), 3))
	await _frames(3)
	var hp := {}
	for body in [a, b, far]:
		hp[body] = (body.get_node("Health") as Health).current
	var drop := _drop("FireDrop", Vector3(200.0, 40.0, 0.0), Vector3(200.0, 0.0, 0.0), 1.4, spell, wizard)
	drop.ended.connect(func(_b: Node3D, at: Vector3) -> void: ended["at"] = at)
	await _frames(MatchClock.ticks_for(1.4) + 4)
	var resist := (a.get_node("Health") as Health).resistance(Health.SPLASH_SPELL)
	var took_a := float(hp[a]) - (a.get_node("Health") as Health).current
	checks["direct_500"] = absf(took_a - 500.0 * resist) <= 500.0 * resist * TOLERANCE + 0.5
	var want_b := 500.0 * (1.0 - SplashDamage.box_distance(b, ended["at"]) / 5.0) * resist
	var took_b := float(hp[b]) - (b.get_node("Health") as Health).current
	checks["splash_falls_off"] = absf(took_b - want_b) <= want_b * TOLERANCE + 0.5 and took_b < took_a
	checks["far_untouched"] = hp[far] == (far.get_node("Health") as Health).current
	checks["fire_on_reached"] = a.get_node_or_null("Burning") != null and b.get_node_or_null("Burning") != null and far.get_node_or_null("Burning") == null
	for node: Node in [wizard, a, b, far]:
		node.queue_free()
	await _frames(2)
	return _verdict("cloud_fire", checks)


## A drop of plague: 62 a second to the body it ends on for 10 s, contagious and with no regeneration; a weaker dose to those within 5 m,
## nothing to those beyond.
func _plague() -> Dictionary:
	var checks := {}
	var spell := GameData.spell("galp")
	var wizard := _wizard(1, Vector3(-300.0, 0.0, 0.0), "charnel", 8)
	var a := _still(_tough(Vector3(300.0, 0.0, 0.0), 3))
	var b := _still(_tough(Vector3(303.0, 0.0, 0.0), 3))
	var far := _still(_tough(Vector3(312.0, 0.0, 0.0), 3))
	await _frames(3)
	var drop := _drop("PlagueDrop", Vector3(300.0, 6.0, 0.0), Vector3(300.0, 0.0, 0.0), 2.0, spell, wizard)
	await _frames(MatchClock.ticks_for(1.0))
	var poison_a := Poisoning.of(a)
	var poison_b := Poisoning.of(b)
	checks["drop_gone"] = not is_instance_valid(drop) or drop.is_queued_for_deletion()
	checks["direct_62"] = poison_a.is_poisoned() and poison_a.damage_sum() == 62
	checks["splash_weaker"] = poison_b.is_poisoned() and poison_b.damage_sum() < 7 and poison_b.damage_sum() >= 1
	checks["far_clean"] = not Poisoning.of(far).is_poisoned()
	checks["no_regeneration"] = poison_a.regeneration_factor() == 0.0
	var dose := poison_a.get_child(0) as Poisoned
	checks["contagious"] = dose != null and dose.infectious
	var hp := (a.get_node("Health") as Health).current
	await _frames(MatchClock.ticks_for(2.0))
	var lost := hp - (a.get_node("Health") as Health).current
	checks["about_2_s_of_dose"] = lost > 0.0 and absf(lost - 124.0 * (a.get_node("Health") as Health).resistance(Health.SPLASH_SPELL)) <= 124.0
	await _frames(MatchClock.ticks_for(10.0))
	checks["ends_at_10_s"] = not poison_a.is_poisoned()
	for node: Node in [wizard, a, b, far]:
		node.queue_free()
	await _frames(2)
	return _verdict("cloud_plague", checks)


## A meteorite: it leaves the earth, goes up and comes down 720 ticks after, 400 to the body it ends on, a stun on the others within 5 m, and
## the land is as it was.
func _meteor() -> Dictionary:
	var checks := {}
	var spell := GameData.spell("rtem")
	var wizard := _wizard(1, Vector3(-300.0, 0.0, 400.0), "james", 8)
	var a := _still(_tough(Vector3(400.0, 0.0, 400.0), 3))
	var b := _still(_tough(Vector3(402.5, 0.0, 400.0), 3))
	var far := _still(_tough(Vector3(412.0, 0.0, 400.0), 3))
	await _frames(3)
	var land_before := ZoneGround.height(_host, 400.0, 400.0, 0.0)
	var rock := _drop("Meteor", Vector3(-290.0, -1.0, 400.0), Vector3(400.0, 0.0, 400.0), 12.0, spell, wizard)
	var hp := {}
	for body in [a, b, far]:
		hp[body] = (body.get_node("Health") as Health).current
	await _frames(30)
	checks["rises_first"] = is_instance_valid(rock) and rock.velocity.y > 100.0 and rock.global_position.y > 0.0
	var t := 30
	var peak := 0.0
	while is_instance_valid(rock) and not rock.is_queued_for_deletion() and t < 900:
		await _frames(1)
		t += 1
		if is_instance_valid(rock):
			peak = maxf(peak, rock.global_position.y)
	checks["lands_at_720"] = absi(t - MatchClock.ticks_for(12.0)) <= 3
	checks["arc_peak"] = peak > 300.0
	var resist := (a.get_node("Health") as Health).resistance(Health.SPLASH_SPELL)
	var took_a := float(hp[a]) - (a.get_node("Health") as Health).current
	checks["direct_400"] = absf(took_a - 400.0 * resist) <= 400.0 * resist * TOLERANCE + 0.5
	checks["near_stunned"] = (b.get_node("Afflictions/Stunned") as Stunned).cooldown_ticks() > 0
	checks["far_not_stunned"] = (far.get_node("Afflictions/Stunned") as Stunned).cooldown_ticks() == 0
	checks["far_untouched"] = hp[far] == (far.get_node("Health") as Health).current
	checks["land_unchanged"] = ZoneGround.height(_host, 400.0, 400.0, 0.0) == land_before
	for node: Node in [wizard, a, b, far]:
		node.queue_free()
	await _frames(2)
	return _verdict("cloud_meteor", checks)


## Cloudkill: the cloud reaches the body it follows at 3 m/s, 22 m over its middle, and about two bolts a second fall; a bolt does 900 to the
## body it reaches and a splash that falls off in 5 m, and one on the bare land only the splash.
func _cloudkill() -> Dictionary:
	var checks := {}
	var spell := GameData.spell("likc")
	var wizard := _wizard(1, Vector3(-300.0, 0.0, -300.0), "stratos", 8)
	var target := _still(_tough(Vector3(30.0, 0.0, 0.0), 3))
	await _frames(3)
	var zone := _cloud("Cloudkill", Vector3.ZERO, wizard, 0, target.get_path())
	zone.spell = zone.spell.duplicate()
	zone.spell.duration = 14.0
	var shots := _root.get_node("Shots")
	var bolts := [0]
	shots.child_entered_tree.connect(func(_n: Node) -> void: bolts[0] += 1)
	zone.release()
	var last := zone.global_position
	var fastest := 0.0
	var ticks := 0
	while ticks < MatchClock.ticks_for(13.0):
		await _frames(1)
		ticks += 1
		if is_instance_valid(zone):
			fastest = maxf(fastest, zone.global_position.distance_to(last))
			last = zone.global_position
		if ticks == 60:
			checks["moves_about_3_m_in_1_s"] = zone.global_position.distance_to(Vector3.ZERO) > 2.4 and zone.global_position.distance_to(Vector3.ZERO) < 3.1
	var cloud := zone.get_node("CloudAt") as Marker3D
	checks["arrives"] = zone.global_position.distance_to(BodyNudge.center(target)) < 0.06
	checks["cloud_22_over"] = absf(cloud.global_position.y - (BodyNudge.center(target).y + 22.0)) < 0.06
	checks["never_faster_than_3"] = fastest <= 3.0 / TPS + 0.001
	checks["about_2_bolts_a_second"] = absf(float(bolts[0]) - 26.0) <= 10.0
	zone.cancel()
	await _frames(MatchClock.ticks_for(2.0))
	var a := _still(_tough(Vector3(700.0, 0.0, 700.0), 3))
	var b := _still(_tough(Vector3(703.0, 0.0, 700.0), 3))
	var far := _still(_tough(Vector3(720.0, 0.0, 700.0), 3))
	await _frames(3)
	var hp := {}
	for body in [a, b, far]:
		hp[body] = (body.get_node("Health") as Health).current
	## Still casting: its own dropper rests, only the launcher under test throws.
	var z2 := _cloud("Cloudkill", Vector3(700.0, 0.0, 700.0), wizard, 0)
	var launcher := z2.get_node("Bolts") as BoltLauncher
	var end_at := BodyNudge.center(a)
	launcher._launch(Vector3(700.0, 0.0, 700.0), a)
	await _frames(MatchClock.ticks_for(0.3))
	var direct := (a.get_node("Health") as Health)
	var resist := direct.resistance(Health.DIRECT_SPELL)
	checks["bolt_900"] = absf(float(hp[a]) - direct.current - 900.0 * resist) <= 900.0 * resist * TOLERANCE + 0.5
	var want_b := 900.0 * (1.0 - SplashDamage.box_distance(b, end_at) / 5.0) * (b.get_node("Health") as Health).resistance(Health.SPLASH_SPELL)
	var took_b := float(hp[b]) - (b.get_node("Health") as Health).current
	checks["splash_falls_off"] = absf(took_b - want_b) <= want_b * TOLERANCE + 0.5 and took_b > 0.0
	checks["far_untouched"] = hp[far] == (far.get_node("Health") as Health).current
	var hp_a := direct.current
	launcher._launch(Vector3(701.5, 0.0, 700.0), null)
	await _frames(MatchClock.ticks_for(0.3))
	checks["land_bolt_splash_only"] = direct.current < hp_a and (a.get_node("Health") as Health).current > float(hp[a]) - 2000.0
	z2.cancel()
	for node: Node in [wizard, target, a, b, far]:
		node.queue_free()
	await _frames(2)
	checks["spell_numbers"] = spell.damage == 900 and spell.damage_range == 5.0 and spell.speed == 3.0 and spell.duration == 30.0
	return _verdict("cloud_cloudkill", checks)


## The cast through the book: the cloud is born when the cast starts and rains when it ends; mana and cooldown are taken; a cast that is cut
## rains nothing and leaves no zone.
func _cast() -> Dictionary:
	var checks := {}
	var spell := GameData.spell("grfr")
	var wizard := _wizard(1, Vector3(-30.0, 0.0, -800.0), "persephone", 8)
	var waiting := 0
	while not _zones().is_empty() and waiting < 600:
		await _frames(1)
		waiting += 1
	await _frames(3)
	var caster := Caster.of(wizard)
	var pool := wizard.get_node("ManaPool") as ManaPool
	pool.maximum = 10000.0
	pool.current = 5000.0
	var index := caster.spellbook.index_of("grfr")
	checks["arm_ok"] = index >= 0 and caster.arm_status(index).is_empty()
	var drops := [0]
	var spells := _root.get_node("Spells")
	spells.child_entered_tree.connect(func(node: Node) -> void: drops[0] += 1 if node is ZoneDrop else 0)
	caster.request_cast("grfr", Vector3(0.0, 0.0, -800.0), null)
	checks["casting"] = caster.is_casting() and _zones().size() == 1
	var zone: GroundZone = _zones()[0] if not _zones().is_empty() else null
	var waited := 0
	while is_instance_valid(zone) and zone.phase == GroundZone.Phase.CASTING and waited < 600:
		await _frames(1)
		waited += 1
	checks["cloud_while_casting"] = zone != null and zone.cast_ticks > 0 and absi(waited - zone.cast_ticks) <= 2 and drops[0] == 0
	await _frames(MatchClock.ticks_for(1.5))
	checks["rains_after_cast"] = is_instance_valid(zone) and zone.phase == GroundZone.Phase.ACTIVE and drops[0] > 0
	checks["mana_spent"] = pool.current < 5000.0 - float(spell.mana_cost) * 0.9
	checks["cooling"] = caster.spellbook.cooldown(index) > 0.0
	zone.cancel()
	await _frames(MatchClock.ticks_for(1.5))
	var wizard_2 := _wizard(1, Vector3(-30.0, 0.0, 800.0), "persephone", 8)
	await _frames(3)
	var caster_2 := Caster.of(wizard_2)
	(wizard_2.get_node("ManaPool") as ManaPool).maximum = 10000.0
	(wizard_2.get_node("ManaPool") as ManaPool).current = 5000.0
	drops[0] = 0
	caster_2.request_cast("grfr", Vector3(0.0, 0.0, 800.0), null)
	await _frames(40)
	(wizard_2.get_node("Health") as Health).damage(99999.0, 3)
	await _frames(MatchClock.ticks_for(4.0))
	checks["cut_no_rain"] = drops[0] == 0
	checks["cut_no_zone"] = _zones().is_empty()
	for node: Node in [wizard, wizard_2]:
		node.queue_free()
	await _frames(2)
	return _verdict("cloud_cast", checks)


## Every spell lights its surroundings with its colour: the clouds and the drop of fire carry an ActorLight with no shadow, and each burst that
## makes a light (the frogs', the fire's, the meteorite's, the plague's) has its FxLightSpec; Cloudkill's bolt uses the lightning flash.
func _lights() -> Dictionary:
	var checks := {}
	for kind in ["RainOfFrogs", "RainOfFire", "Plague", "Cloudkill"]:
		var zone := (_spawner.zones[kind] as PackedScene).instantiate()
		var light := zone.get_node_or_null("CloudAt/Light") as ActorLight
		checks[kind + "_cloud_light"] = light != null and not light.shadow_enabled and light.light_energy > 0.0
		_root.add_child(zone)
		await _frames(2)
		## A cloud is a volume, not a flat oval: twenty layers, each in another place of the noise, each a thin veil, pushed far off the sphere.
		var look := zone.get_node("CloudAt/Cloud") as CloudLook
		var multimesh := look.layers.multimesh
		var seeds := {}
		for i in look.layer_count:
			seeds[look.layer_seed(i)] = true
		var material := (multimesh.mesh as SphereMesh).material as ShaderMaterial
		checks[kind + "_layers_differ"] = look.layer_count == 20 and seeds.size() == 20 and look.layer_drift >= 1.0
		checks[kind + "_lumpy"] = (material.shader.get_shader_uniform_list().size() > 0) and float(material.get_shader_parameter("noise_amount") if material.get_shader_parameter("noise_amount") != null else 0.324) >= 0.25
		checks[kind + "_thin_veil"] = float(material.get_shader_parameter("layer_alpha")) <= 0.2
		zone.queue_free()
	var fire := (_spawner.projectiles["FireDrop"] as PackedScene).instantiate()
	var fire_light := fire.get_node_or_null("Light") as ActorLight
	checks["fire_drop_light"] = fire_light != null and not fire_light.shadow_enabled
	fire.free()
	for name in ["frog_burst", "fireball_blast", "meteor_hit", "plague_burst"]:
		var type := load("res://data/fx/%s.tres" % name) as ParticleType
		checks[name + "_has_light"] = type != null and type.light != null and type.light.energy > 0.0
	var bolt := load("res://data/fx/beams/lightning.tres") as BeamType
	checks["bolt_flash"] = bolt != null and bolt.light != null
	return _verdict("cloud_lights", checks)


## The AI sees the five without breaking: no `ai_use`, and its evaluator gives a finite rating.
func _ai() -> Dictionary:
	var checks := {}
	var perception := AiPerception.new()
	perception.name = "CloudCasesPerception"
	perception.profile = load("res://data/ai/profile_original.tres")
	perception.slot = 1
	_root.add_child(perception)
	var wizard := _wizard(1, Vector3(-400.0, 0.0, -400.0), "pyro", 8)
	var foe := _tough(Vector3(-380.0, 0.0, -400.0), 3)
	await _frames(3)
	var stance := AiStance.new()
	stance.recs[0].manaliths = 1
	var groups := AiGroups.new()
	groups.perception = perception
	groups.profile = perception.profile
	_root.add_child(groups)
	var eval := AiSpellEval.new(perception, stance, groups, perception.profile)
	var track := perception.add_node(wizard, &"event")
	var foe_track := perception.add_node(foe, &"event")
	groups.rebuild()
	for tag in SPELLS:
		var spell := GameData.spell(tag)
		checks[tag + "_ai_none"] = spell.ai_use == SpellType.AiUse.NONE
		if track != null and foe_track != null:
			var rated := eval.rate(track, spell, foe_track, 0.0)
			checks[tag + "_rates_finite"] = is_finite(rated) and rated >= 0.0
	stance.free()
	for node: Node in [perception, groups, wizard, foe]:
		node.queue_free()
	await _frames(2)
	return _verdict("cloud_ai", checks)


## A cloud zone made through the spawner, as the action does, at `at`; `follow` is the body it chases.
func _cloud(kind: String, at: Vector3, wizard: Node3D, cast_ticks: int, follow := NodePath()) -> GroundZone:
	var data := {
		"x": at.x, "y": at.y, "z": at.z, "points": PackedVector3Array([at]), "aim": at, "follow": str(follow),
		"slot": wizard.get("owner_slot"), "caster": str(wizard.get_path()), "cast_ticks": cast_ticks, "arm_ticks": 0,
	}
	return _spawner.spawn_projectile(kind, data) as GroundZone


## A drop made through the spawner, as a DropLauncher does.
func _drop(kind: String, start: Vector3, goal: Vector3, fall_s: float, spell: SpellType, wizard: Node3D) -> ZoneDrop:
	return _spawner.spawn_projectile(kind, {
		"x": start.x, "y": start.y, "z": start.z, "goal": goal, "fall_s": fall_s, "slot": wizard.get("owner_slot"),
		"caster": str(wizard.get_path()), "damage": float(spell.damage), "damage_range": spell.damage_range, "effect_range": spell.effect_range}) as ZoneDrop
