extends RefCounted

## 055g g3 cases of rules_suite: the ritual is a thin root with parts you can take away and a RitualType per class.
##   - types_table: Desecrate and Convert differ only by their .tres (fields, ending); a kind with no type is inert; the four parts
##     exist, point at the ritual and come before Phases in the tree;
##   - rounds_by_type: Desecrate ends when the wizard whose altar it is is gone, Convert after int(max health / per round) + 1 rounds;
##   - lift_reaches_hang: stepping Lift for the setup time puts the creature exactly on the hanging point over the site;
##   - watch_aborts: Watch cancels a ritual whose creature is not held, on the tick; without the part nothing cancels it;
##   - payoff_purse: a completed ritual (both classes) pays its souls to the caster and sends the creature away; without Payoff, nothing;
##   - no_drain_without_part: Drain takes life from the wizard of a Desecrate and from nobody in a Convert; the Shoot state with no
##     Drain part takes nothing and does not fail.
## Prints RITUAL PARTS <case>=<bool>.

const RITUAL_SCENE := preload("res://scenes/sacrifice/ritual.tscn")
const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const RULES := preload("res://data/match_rules.tres")
const GOD := "james"

var _host: Node3D
var _root: Node3D


func run(host: Node3D) -> Dictionary:
	_host = host
	_root = Node3D.new()
	_root.name = "RitualPartsCases"
	_host.add_child(_root)
	var results := {}
	results["types_table"] = _types_table()
	results["rounds_by_type"] = _rounds_by_type()
	results["lift_reaches_hang"] = _lift_reaches_hang()
	results["watch_aborts"] = await _watch_aborts()
	results["payoff_purse"] = _payoff_purse()
	results["no_drain_without_part"] = _no_drain_without_part()
	await _frames(2)
	_root.queue_free()
	var ok := true
	for case_name: String in results:
		var passed: bool = results[case_name]
		ok = ok and passed
		print("RITUAL PARTS %s=%s" % [case_name, passed])
	return {"ritual_parts": {"ok": ok, "cases": results}}


func _types_table() -> bool:
	var ritual := RITUAL_SCENE.instantiate() as Ritual
	var ok := ritual.types.size() == 2
	ritual.kind = Ritual.Kind.DESECRATE
	var desecrate := ritual.type()
	ok = ok and desecrate.kind == Ritual.Kind.DESECRATE and desecrate.ending == RitualType.Ending.TARGET_WIZARD_GONE
	ok = ok and desecrate.drains_target_wizard and desecrate.collapses_target_altar and desecrate.marks_target_ghost
	ok = ok and not desecrate.counts_as_conversion
	ritual.kind = Ritual.Kind.CONVERT
	var convert := ritual.type()
	ok = ok and convert.kind == Ritual.Kind.CONVERT and convert.ending == RitualType.Ending.CREATURE_HEALTH_ROUNDS
	ok = ok and not convert.drains_target_wizard and not convert.collapses_target_altar and not convert.marks_target_ghost
	ok = ok and convert.counts_as_conversion and convert != desecrate
	for part: Node in [ritual.lift, ritual.watch, ritual.drain, ritual.payoff]:
		ok = ok and part != null and part.get("ritual") == ritual and part.get_index() < ritual.phases.get_index()
	ritual.types = []
	var inert := ritual.type()
	ok = ok and inert == RitualType.inert() and not inert.drains_target_wizard and not inert.collapses_target_altar
	ok = ok and not inert.marks_target_ghost and not inert.counts_as_conversion
	ritual.free()
	return ok


func _rounds_by_type() -> bool:
	var wizard := _wizard(6, Vector3(10.0, 0.1, 10.0))
	var desecrate := _ritual(Ritual.Kind.DESECRATE)
	desecrate.target_wizard = wizard
	var ok := not desecrate.type().is_last_round(desecrate)
	(wizard.health as Health).damage(99999.0, 2)
	ok = ok and desecrate.type().is_last_round(desecrate)
	var unit := _unit(2, Vector3(60.0, 0.1, 60.0))
	var convert := _ritual(Ritual.Kind.CONVERT)
	convert.creature = unit
	var health := unit.get_node("Health") as Health
	var rounds := SacrificeMath.convert_rounds(health.maximum, RULES.convert_health_per_round)
	for index in rounds:
		convert.round_index = index
		ok = ok and convert.type().is_last_round(convert) == (index == rounds - 1)
	## The dead wizard of the Desecrate above does not end a Convert early.
	convert.target_wizard = wizard
	convert.round_index = 0
	ok = ok and (rounds == 1 or not convert.type().is_last_round(convert))
	for node: Node in [wizard, desecrate, unit, convert]:
		node.queue_free()
	return ok


func _lift_reaches_hang() -> bool:
	var site := Vector3(40.0, 3.0, 40.0)
	var ritual := _ritual(Ritual.Kind.DESECRATE, site)
	var unit := _unit(2, site + Vector3(5.0, -1.0, 3.0))
	ritual.creature = unit
	var hang := site + Vector3(0.0, SacrificeFacts.of_rules(RULES).hang_up_m, 0.0)
	var delta := 0.1
	var steps := int(RULES.ritual_setup_s / delta) + 1
	var halfway := INF
	for index in steps:
		ritual.elapsed += delta
		ritual.lift.step(delta)
		if index == steps / 2:
			halfway = unit.global_position.distance_to(hang)
	var ok := unit.global_position.is_equal_approx(hang) and halfway > 0.1 and unit.velocity == Vector3.ZERO
	ritual.queue_free()
	unit.queue_free()
	return ok


func _watch_aborts() -> bool:
	## Called by hand: a creature nobody holds cancels the ritual.
	var direct := _ritual(Ritual.Kind.DESECRATE)
	var direct_unit := _unit(2, Vector3(80.0, 0.1, 80.0))
	direct.creature = direct_unit
	direct.captive = Captive.of(direct_unit)
	direct.watch.step()
	var ok := direct.outcome == Ritual.Outcome.ABORTED
	## On the tick: with the part the ritual is cancelled, without it nothing watches.
	var watched := _running_ritual(Vector3(100.0, 0.1, 100.0))
	var unwatched := _running_ritual(Vector3(120.0, 0.1, 120.0))
	unwatched.remove_child(unwatched.watch)
	unwatched.watch.free()
	unwatched.watch = null
	await _frames(3)
	ok = ok and watched.outcome == Ritual.Outcome.ABORTED and unwatched.outcome == Ritual.Outcome.RUNNING
	for node: Node in [direct, direct_unit, watched, unwatched]:
		node.queue_free()
	return ok


func _payoff_purse() -> bool:
	var ok := true
	for kind: Ritual.Kind in [Ritual.Kind.DESECRATE, Ritual.Kind.CONVERT]:
		var caster := _wizard(7, Vector3(140.0, 0.1, 140.0))
		var purse := caster.get_node("SoulPurse") as SoulPurse
		var before := purse.count
		var paid := _ritual(kind)
		paid.caster_slot = 7
		paid.target_slot = 5
		paid.souls = 4
		paid.creature = _unit(5, Vector3(150.0, 0.1, 150.0))
		paid.complete()
		ok = ok and paid.outcome == Ritual.Outcome.COMPLETED and purse.count == before + 4
		ok = ok and paid.creature.is_queued_for_deletion()
		var unpaid := _ritual(kind)
		unpaid.caster_slot = 7
		unpaid.souls = 4
		unpaid.creature = _unit(5, Vector3(160.0, 0.1, 160.0))
		unpaid.remove_child(unpaid.payoff)
		unpaid.payoff.free()
		unpaid.payoff = null
		unpaid.complete()
		ok = ok and unpaid.outcome == Ritual.Outcome.COMPLETED and purse.count == before + 4
		ok = ok and not unpaid.creature.is_queued_for_deletion()
		for node: Node in [caster, paid, unpaid, unpaid.creature]:
			node.queue_free()
	return ok


func _no_drain_without_part() -> bool:
	var wizard := _wizard(5, Vector3(180.0, 0.1, 180.0))
	var health := wizard.health as Health
	var desecrate := _ritual(Ritual.Kind.DESECRATE)
	desecrate.target_wizard = wizard
	desecrate.caster_slot = 2
	desecrate.souls = 3
	var before := health.current
	desecrate.drain.apply(0.5)
	var ok := health.current < before
	## A Convert drains nobody even with the part.
	var convert := _ritual(Ritual.Kind.CONVERT)
	convert.target_wizard = wizard
	convert.souls = 3
	var after_desecrate := health.current
	convert.drain.apply(0.5)
	ok = ok and health.current == after_desecrate
	## The Shoot state with no Drain part: the same stretch of the round takes nothing and does not fail.
	var bare := _ritual(Ritual.Kind.DESECRATE)
	bare.target_wizard = wizard
	bare.souls = 3
	bare.remove_child(bare.drain)
	bare.drain.free()
	bare.drain = null
	bare.phases.transition(&"Shoot")
	(bare.phases.get_node("Shoot") as RitualStep).physics_update(0.5)
	ok = ok and health.current == after_desecrate and bare.drain == null
	for node: Node in [wizard, desecrate, convert, bare]:
		node.queue_free()
	return ok


## A ritual already in its setup with a creature nobody holds, on its own: the tick runs Lift and Watch.
func _running_ritual(at: Vector3) -> Ritual:
	var ritual := _ritual(Ritual.Kind.DESECRATE, at)
	var unit := _unit(2, at + Vector3(2.0, 0.0, 2.0))
	ritual.creature = unit
	ritual.captive = Captive.of(unit)
	ritual.phase = Ritual.Phase.SETUP
	return ritual


func _ritual(kind: Ritual.Kind, at := Vector3.ZERO) -> Ritual:
	var ritual := RITUAL_SCENE.instantiate() as Ritual
	ritual.kind = kind
	ritual.position = at
	_root.add_child(ritual)
	return ritual


func _wizard(slot: int, at: Vector3) -> WizardBody:
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = slot
	wizard.god = GOD
	wizard.position = at
	_root.add_child(wizard)
	return wizard


func _unit(slot: int, at: Vector3) -> UnitBody:
	var type := GameData.creature("nmuh")
	var unit := UNIT_SCENE.instantiate() as UnitBody
	unit.owner_slot = slot
	unit.type = type
	unit.model = type.model_id() if type else ""
	unit.rules = RULES
	unit.idle_aggro = false
	unit.target_groups = PackedStringArray()
	unit.position = at
	_root.add_child(unit)
	return unit


func _frames(count: int) -> void:
	for _i in count:
		await _host.get_tree().physics_frame
