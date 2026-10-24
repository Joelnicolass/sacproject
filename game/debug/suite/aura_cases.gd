extends "res://debug/suite/zone_case_base.gd"

## RFC-061f cases of rules_suite for Healing Aura: who carries it, who it heals and how fast, when it ends, the tail of the heal and that it is
## no shield. The creatures do not regenerate by themselves, so a heal is the only thing that moves their health. No network: the server
## paths run as solo. `run(host)` adds its own bodies and removes them.


func run(host: Node3D) -> Dictionary:
	begin(host, "AuraCases")
	var out := {}
	out["aura_heals"] = await _heals()
	finish()
	return out


## A creature of the wizard's side (it does not regenerate and has health to spare), at half its health.
func _half(at: Vector3, slot: int) -> UnitBody:
	var unit := _still(_unit("ycro", at, slot))
	var health := unit.get_node("Health") as Health
	health.setup(10000.0)
	health.current = 1000.0
	return unit


## The creature that was clicked carries it for 20 s (not the wizard); it and every creature of its side within 30 m heal 60 a second; an enemy,
## an ally of another side and a creature out of reach do not; the heal goes on 256 ticks after the ward ends; and the aura is no shield.
func _heals() -> Dictionary:
	var checks := {}
	var spell := GameData.spell("ruah")
	var wizard := _wizard(1, Vector3.ZERO, "persephone", 6)
	var wizard_far := _wizard(1, Vector3(0.0, 0.0, 300.0), "persephone", 6)
	var carrier := _half(Vector3(10.0, 0.0, 0.0), 1)
	var mate := _half(Vector3(10.0, 0.0, 20.0), 1)
	var far := _half(Vector3(10.0, 0.0, 60.0), 1)
	var foe := _half(Vector3(10.0, 0.0, -10.0), 3)
	var friend := _half(Vector3(10.0, 0.0, 10.0), 2)
	await _frames(3)
	for body in [wizard, wizard_far]:
		(body.get_node("Health") as Health).current = 5000.0
	var caster := Caster.of(wizard)
	var pool := wizard.get_node("ManaPool") as ManaPool
	pool.maximum = 10000.0
	pool.current = 5000.0
	var action := caster.action_for("ruah")
	checks["action"] = action is WardAction and (action as WardAction).target != null and caster.spellbook.index_of("ruah") >= 0
	checks["no_ward_yet"] = not Wards.of(carrier).ward_for(spell).is_on() and not Wards.of(wizard).ward_for(spell).is_on()
	caster.request_cast("ruah", carrier.global_position, carrier)
	checks["casting"] = caster.is_casting()
	var ticks := 0
	var ward := Wards.of(carrier).ward_for(spell)
	while not ward.is_on() and ticks < 400:
		await _frames(1)
		ticks += 1
	checks["carrier_wears_it"] = ward.is_on() and not Wards.of(wizard).ward_for(spell).is_on()
	checks["not_a_shield"] = not Afflictions.of(carrier).cc_protected() and not Wards.of(carrier).shielded()
	checks["twenty_seconds"] = absi(ward.ticks_left() - 1200) <= 1
	var bodies: Array[Node3D] = [carrier, mate, far, foe, friend, wizard, wizard_far]
	var before := {}
	for body in bodies:
		before[body] = (body.get_node("Health") as Health).current
	await _frames(60)
	var gained := {}
	for body in bodies:
		gained[body] = (body.get_node("Health") as Health).current - float(before[body])
	for body in [carrier, mate]:
		checks["heals_60_" + str(body.get_instance_id())] = gained[body] >= 57.0 and gained[body] <= 63.0
	var regen := float(gained[wizard_far])
	checks["wizard_heals_at_least_60"] = gained[wizard] >= 57.0 and regen < 20.0
	for body in [far, foe, friend]:
		checks["no_heal_" + str(body.get_instance_id())] = absf(gained[body]) < 0.01
	var count := 0
	while ward.is_on() and count < 1500:
		await _frames(1)
		count += 1
	checks["ends_at_1200"] = absi(count + 60 - 1200) <= 2
	var at_end := (mate.get_node("Health") as Health).current
	await _frames(100)
	checks["tail_keeps_healing"] = (mate.get_node("Health") as Health).current > at_end
	var tail := 100
	var last := (mate.get_node("Health") as Health).current
	while tail < 400:
		await _frames(1)
		tail += 1
		var now := (mate.get_node("Health") as Health).current
		if now == last:
			break
		last = now
	checks["tail_is_256"] = absi(tail - 256) <= 3
	for node: Node in bodies:
		node.queue_free()
	await _frames(2)
	return _verdict("aura_heals", checks)
