extends "res://debug/suite/zone_case_base.gd"

## RFC-061f cases of rules_suite for Demonic Rift: how often a spirit leaves, who it goes for and how hard it hits, when the rift closes, and
## what a cut cast does. No network: the server paths run as solo. `run(host)` adds its own bodies and removes them.


func run(host: Node3D) -> Dictionary:
	begin(host, "RiftCases")
	var out := {}
	out["rift_spirits"] = await _spirits()
	out["rift_cast"] = await _cast()
	finish()
	return out


## A spirit every 20 ticks while there are creatures to go for and every 60 when there are none; each creature takes 500 once and no ally,
## nobody out of 75 m and nobody twice; no more than the maximum; the rift closes by itself when the last spirit is gone.
func _spirits() -> Dictionary:
	var checks := {}
	var spell := GameData.spell("tfir")
	var wizard := _wizard(1, Vector3.ZERO, "charnel", 6)
	var foes: Array[UnitBody] = [_tough(Vector3(25.0, 0.0, 0.0), 3), _tough(Vector3(30.0, 0.0, 6.0), 3), _tough(Vector3(28.0, 0.0, -8.0), 3)]
	var far := _tough(Vector3(300.0, 0.0, 0.0), 3)
	var ally := _tough(Vector3(24.0, 0.0, 2.0), 2)
	await _frames(3)
	var hits := {}
	for body in foes + [far, ally]:
		(body.get_node("Health") as Health).hurt.connect(func(amount: float, _kind: StringName, _slot: int) -> void: hits[body] = hits.get(body, []) + [amount])
	var zone := _zone("DemonicRift", PackedVector3Array([wizard.global_position]), wizard, 0, 0, Vector3(28.0, 0.0, 0.0))
	var spawner := zone.get_node("Spirits") as RiftSpawner
	spawner.max_spirits = 6
	checks["open_ended"] = zone.open_ended and spell.effect_range == 75.0 and spell.damage == 500 and spell.speed == 18.0
	zone.release()
	var spawned_at: Array[int] = []
	var seen := 0
	var ticks := 0
	var peak := 0
	while is_instance_valid(zone) and not zone.is_queued_for_deletion() and ticks < 3000:
		await _frames(1)
		ticks += 1
		if is_instance_valid(spawner) and spawner.spawned() > seen:
			seen = spawner.spawned()
			spawned_at.append(ticks)
		peak = maxi(peak, _host.get_tree().get_nodes_in_group(RiftSpirit.GROUP).size())
	checks["six_spirits"] = spawned_at.size() == 6
	var gaps: Array[int] = []
	for i in range(1, spawned_at.size()):
		gaps.append(spawned_at[i] - spawned_at[i - 1])
	checks["every_20_with_foes"] = gaps.size() >= 2 and absi(gaps[0] - 20) <= 1 and absi(gaps[1] - 20) <= 1
	checks["every_60_without"] = gaps.size() >= 5 and absi(gaps[3] - 60) <= 1 and absi(gaps[4] - 60) <= 1
	for foe in foes:
		var want := 500.0 * (foe.get_node("Health") as Health).resistance(Health.DIRECT_SPELL)
		var taken: Array = hits.get(foe, [])
		checks["hit_once_" + str(foe.get_instance_id())] = taken.size() == 1 and absf(float(taken[0]) - want) <= want * TOLERANCE + 0.5
	checks["far_untouched"] = not hits.has(far)
	checks["ally_untouched"] = not hits.has(ally)
	checks["zone_closed"] = not is_instance_valid(zone) or zone.is_queued_for_deletion()
	checks["spirits_gone"] = _host.get_tree().get_nodes_in_group(RiftSpirit.GROUP).is_empty()
	checks["peak_at_most_24"] = peak >= 1 and peak <= 24
	var full := (_spawner.zones["DemonicRift"] as PackedScene).instantiate() as GroundZone
	checks["default_is_24"] = (full.get_node("Spirits") as RiftSpawner).max_spirits == 24
	full.free()
	for node: Node in foes + [wizard, far, ally]:
		node.queue_free()
	await _frames(2)
	return _verdict("rift_spirits", checks)


## The cast: the rift is born under the wizard at the start (not at the click), and a cast that is cut closes it without a spirit.
func _cast() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, Vector3(-30.0, 0.0, 60.0), "charnel", 6)
	var foe := _tough(Vector3(10.0, 0.0, 60.0), 3)
	await _frames(3)
	var caster := Caster.of(wizard)
	var pool := wizard.get_node("ManaPool") as ManaPool
	pool.maximum = 10000.0
	pool.current = 5000.0
	checks["in_book"] = caster.spellbook.index_of("tfir") >= 0
	caster.request_cast("tfir", foe.global_position, null)
	await _frames(2)
	var zones := _zones()
	checks["one_zone"] = zones.size() == 1
	var zone: GroundZone = zones[0] if not zones.is_empty() else null
	if zone != null:
		checks["under_the_wizard"] = absf(zone.global_position.x - wizard.global_position.x) < 0.01 and absf(zone.global_position.z - wizard.global_position.z) < 0.01
		checks["looks_at_the_click"] = zone.aim_point.distance_to(foe.global_position) < 0.01
		checks["still_casting"] = zone.phase == GroundZone.Phase.CASTING
	await _frames(40)
	(wizard.get_node("Health") as Health).damage(99999.0, 3)
	await _frames(5)
	checks["cut_closes_it"] = zone == null or zone.cancelled
	await _frames(100)
	checks["no_spirit"] = _host.get_tree().get_nodes_in_group(RiftSpirit.GROUP).is_empty()
	checks["no_damage"] = (foe.get_node("Health") as Health).current == (foe.get_node("Health") as Health).maximum
	checks["zone_gone"] = _zones().is_empty()
	for node: Node in [wizard, foe]:
		node.queue_free()
	await _frames(2)
	return _verdict("rift_cast", checks)
