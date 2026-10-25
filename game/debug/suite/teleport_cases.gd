extends RefCounted

## RFC-021c cases of rules_suite: where the group lands (TeleportMath), how the formation is kept, who travels
## and what TeleportAction accepts, plus a whole cast through the Caster. No network: the server paths run as
## solo. `run(host)` adds its own floor and bodies under `host` and removes them at the end.

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const STRUCTURE_SCENE := preload("res://scenes/structures/buildings/_jman.tscn")
const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const UNIT_ORDERS := preload("res://scenes/units/unit_orders.gd")
const RULES := preload("res://data/match_rules.tres")
const GOD := "james"
const TAG := "nmuh"
const FLYER := "bhrw"
const RADIUS := 30.0

var _host: Node3D
var _root: Node3D


func run(host: Node3D) -> Dictionary:
	_host = host
	_root = Node3D.new()
	_root.name = "TeleportCases"
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1200.0, 2.0, 1200.0)
	shape.shape = box
	shape.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(shape)
	_root.add_child(floor_body)
	_host.add_child(_root)
	await _frames(2)
	var out := {}
	out["teleport_landing"] = _landing()
	out["teleport_offsets"] = _offsets()
	out["teleport_carry"] = await _carry()
	out["teleport_action"] = await _action()
	out["teleport_cast"] = await _cast()
	_root.queue_free()
	return out


## `radius` from the building toward the wizard; without land there, or right over the building, the building
## itself (state.d:10215-10228).
func _landing() -> Dictionary:
	var checks := {}
	var building := Vector3(100.0, 5.0, 200.0)
	var spot := TeleportMath.landing(Vector3(100.0, 5.0, 300.0), building, RADIUS)
	checks["thirty_toward_start"] = spot.is_equal_approx(Vector3(100.0, 5.0, 230.0))
	var diagonal := TeleportMath.landing(Vector3(160.0, 9.0, 280.0), building, RADIUS)
	checks["diagonal_is_on_the_circle"] = is_equal_approx(Vector2(diagonal.x - 100.0, diagonal.z - 200.0).length(), RADIUS) and diagonal.y == 5.0
	var no_land := func(_x: float, z: float) -> bool: return z > 250.0
	checks["no_land_goes_to_building"] = TeleportMath.landing(Vector3(100.0, 5.0, 300.0), building, RADIUS, no_land) == building
	var land := func(_x: float, z: float) -> bool: return z < 250.0
	checks["land_keeps_the_spot"] = TeleportMath.landing(Vector3(100.0, 5.0, 300.0), building, RADIUS, land) == spot
	checks["over_the_building_goes_to_building"] = TeleportMath.landing(Vector3(100.0, 9.0, 200.0), building, RADIUS) == building
	checks["radius_is_a_parameter"] = is_equal_approx(TeleportMath.landing(Vector3(0.0, 0.0, 100.0), Vector3.ZERO, 12.0).z, 12.0)
	return _verdict("teleport_landing", checks)


## nueva = pos - inicio + destino (state.d:10317); a walker with no land there goes to the landing spot, a flier does not.
func _offsets() -> Dictionary:
	var checks := {}
	var start := Vector3(10.0, 3.0, 20.0)
	var destination := Vector3(-300.0, 8.0, 400.0)
	var members: Array[Vector3] = [start, start + Vector3(5.0, 0.0, 2.0), start + Vector3(-7.0, 0.0, 9.0), start + Vector3(12.0, 0.0, -11.0)]
	var moved: Array[Vector3] = []
	for member in members:
		moved.append(TeleportMath.carried(member, start, destination, false))
	var same := true
	for i in members.size():
		var was := Vector2(members[i].x - start.x, members[i].z - start.z)
		var now := Vector2(moved[i].x - destination.x, moved[i].z - destination.z)
		same = same and was.is_equal_approx(now) and moved[i].y == members[i].y
	checks["formation_kept"] = same
	var holes := func(x: float, _z: float) -> bool: return x > -296.0
	checks["walker_without_land_goes_to_landing"] = TeleportMath.carried(members[2], start, destination, false, holes) == destination
	checks["flier_keeps_its_slot"] = TeleportMath.carried(members[2], start, destination, true, holes).is_equal_approx(Vector3(destination.x - 7.0, start.y, destination.z + 9.0))
	checks["radius_on_the_plane"] = TeleportMath.in_radius(Vector3(30.0, 99.0, 0.0), Vector3.ZERO, RADIUS) and not TeleportMath.in_radius(Vector3(30.1, 0.0, 0.0), Vector3.ZERO, RADIUS)
	return _verdict("teleport_offsets", checks)


## The wizard and the living creatures of his side within 30 m go; the far, the enemy, the dead, the Sac Doctor,
## the guardian and the held do not. The order is lost, unless it is guard or retreat.
func _carry() -> Dictionary:
	var checks := {}
	var wizard := _wizard(Vector3(0.0, 0.0, 0.0))
	var caster := wizard.get_node("Caster")
	var action: TeleportAction = caster.action_for("elet")
	var spell: SpellType = caster.get("spellbook").structure_by_tag("elet")
	var building := _structure(Vector3(400.0, 0.0, 0.0), 1)
	var pack1 := _unit(Vector3(5.0, 0.0, 3.0), 1)
	var pack2 := _unit(Vector3(-12.0, 0.0, 8.0), 1)
	var pack3 := _unit(Vector3(20.0, 0.0, -15.0), 1)
	var stray := _unit(Vector3(-60.0, 0.0, 0.0), 1)
	var edge := _unit(Vector3(31.0, 0.0, 0.0), 1)
	var enemy := _unit(Vector3(4.0, 0.0, 4.0), 2)
	var doctor := _unit(Vector3(6.0, 0.0, -6.0), 1)
	doctor.add_to_group("doctor")
	var rooted := _unit(Vector3(-6.0, 0.0, -6.0), 1)
	rooted.add_to_group("rooted")
	var held := _unit(Vector3(-8.0, 0.0, 6.0), 1)
	held.mode = UnitBody.Mode.HELD
	var dead := _unit(Vector3(8.0, 0.0, 6.0), 1)
	var mover := _unit(Vector3(9.0, 0.0, 9.0), 1)
	var guard := _unit(Vector3(-9.0, 0.0, -9.0), 1)
	await _frames(3)
	dead.get_node("Health").damage(99999.0, 2)
	mover.get_node("Orders").command = UNIT_ORDERS.Command.MOVE
	guard.get_node("Orders").command = UNIT_ORDERS.Command.GUARD
	await _frames(2)
	var before := {}
	for body in [wizard, pack1, pack2, pack3, stray, edge, enemy, doctor, rooted, held, dead, mover, guard]:
		before[body] = body.global_position
	checks["wizard_first"] = action.travelers(wizard, RADIUS)[0] == wizard
	var members := action.travelers(wizard, RADIUS)
	checks["who_travels"] = members.size() == 6 and members.has(pack1) and members.has(pack2) and members.has(pack3) and members.has(mover) and members.has(guard)
	checks["who_stays"] = not members.has(stray) and not members.has(edge) and not members.has(enemy) and not members.has(doctor) and not members.has(rooted) and not members.has(held) and not members.has(dead)
	var aim := action.check(wizard, spell, Vector3.ZERO, building, "")
	action.begin(wizard, spell, aim)
	checks["finish_is_silent"] = action.finish(wizard, spell, building).is_empty()
	await _frames(2)
	var landing := Vector3(370.0, 0.0, 0.0)
	var wizard_flat := Vector2(wizard.global_position.x - 400.0, wizard.global_position.z).length()
	checks["wizard_thirty_from_building"] = absf(wizard_flat - RADIUS) < 0.5 and wizard.global_position.x < 400.0
	var kept := true
	for member in [pack1, pack2, pack3, mover, guard]:
		var was: Vector3 = before[member] - before[wizard]
		var now: Vector3 = member.global_position - wizard.global_position
		kept = kept and Vector2(was.x - now.x, was.z - now.z).length() < 0.5
	checks["formation_kept"] = kept
	var stayed := true
	for member in [stray, edge, enemy, doctor, rooted, held, dead]:
		stayed = stayed and Vector2(member.global_position.x - before[member].x, member.global_position.z - before[member].z).length() < 0.5
	checks["others_did_not_move"] = stayed
	checks["move_order_lost"] = mover.get_node("Orders").command == UNIT_ORDERS.Command.NONE and not mover.ordered
	checks["guard_order_kept"] = guard.get_node("Orders").command == UNIT_ORDERS.Command.GUARD
	checks["landing_near"] = landing.distance_to(Vector3(wizard.global_position.x, 0.0, wizard.global_position.z)) < 6.0
	for node in [wizard, building, pack1, pack2, pack3, stray, edge, enemy, doctor, rooted, held, dead, mover, guard]:
		if is_instance_valid(node):
			node.queue_free()
	return _verdict("teleport_carry", checks)


## The contract: found by tag, what it aims at, any distance, only an own standing building.
func _action() -> Dictionary:
	var checks := {}
	var wizard := _wizard(Vector3(0.0, 0.0, 0.0))
	var caster := wizard.get_node("Caster")
	var action: TeleportAction = caster.action_for("elet")
	var spell: SpellType = caster.get("spellbook").structure_by_tag("elet")
	checks["found"] = action is TeleportAction and action.pick == SpellAction.Pick.OWN_BUILDING and action.prompt == "Elegí un edificio propio"
	checks["no_warnings"] = action != null and action._get_configuration_warnings().is_empty()
	checks["armed_in_tab"] = caster.structure_status(int(caster.get("spellbook").structure_index_of("elet"))).is_empty()
	var near := _structure(Vector3(100.0, 0.0, 0.0), 1)
	var far := _structure(Vector3(500.0, 0.0, 500.0), 1)
	var enemy := _structure(Vector3(50.0, 0.0, 0.0), 2)
	var own_unit := _unit(Vector3(10.0, 0.0, 10.0), 1)
	var dying := _structure(Vector3(60.0, 0.0, 60.0), 1)
	await _frames(2)
	dying.get_node("Health").damage(99999.0, 2)
	checks["own_building_ok"] = action.check(wizard, spell, Vector3.ZERO, near, "").status.is_empty()
	checks["any_distance"] = action.check(wizard, spell, Vector3.ZERO, far, "").status.is_empty() and spell.cast_range_m >= 700.0
	checks["enemy_building_invalid"] = action.check(wizard, spell, Vector3.ZERO, enemy, "").status == SpellAction.BAD_TARGET
	checks["creature_invalid"] = action.check(wizard, spell, Vector3.ZERO, own_unit, "").status == SpellAction.BAD_TARGET
	checks["ground_invalid"] = action.check(wizard, spell, Vector3(30.0, 0.0, 30.0), null, "").status == SpellAction.BAD_TARGET
	checks["wizard_invalid"] = action.check(wizard, spell, Vector3.ZERO, wizard, "").status == SpellAction.BAD_TARGET
	checks["dead_building_invalid"] = action.check(wizard, spell, Vector3.ZERO, dying, "").status == SpellAction.BAD_TARGET
	checks["no_mana"] = action.check(wizard, spell, Vector3.ZERO, near, SpellAction.NO_MANA).status == SpellAction.NO_MANA
	checks["cooling_wins"] = action.check(wizard, spell, Vector3.ZERO, near, SpellAction.COOLING).status == SpellAction.COOLING
	var before := own_unit.global_position
	action.begin(wizard, spell, action.check(wizard, spell, Vector3.ZERO, near, ""))
	action.cancel()
	checks["cancel_forgets"] = action.finish(wizard, spell, null) == SpellAction.BAD_TARGET and own_unit.global_position.is_equal_approx(before)
	var bare := TeleportAction.new()
	checks["tag_warns"] = bare._get_configuration_warnings().size() == 1
	bare.free()
	for node in [wizard, near, far, enemy, own_unit, dying]:
		if is_instance_valid(node):
			node.queue_free()
	return _verdict("teleport_action", checks)


## The whole thing through the Caster: the casting time, mana 800 and the cooldown; and the cases of the RFC where
## the wizard dies in the middle (nobody moves) and the building falls in the middle (the last destination stands).
func _cast() -> Dictionary:
	var checks := {}
	## A whole cast.
	var wizard := _wizard(Vector3(0.0, 0.0, 0.0))
	var caster := wizard.get_node("Caster")
	var book: Node = caster.get("spellbook")
	var mana: Node = wizard.get_node("ManaPool")
	var building := _structure(Vector3(300.0, 0.0, 0.0), 1)
	var pack := _unit(Vector3(8.0, 0.0, 5.0), 1)
	await _frames(3)
	mana.set("current", float(mana.get("maximum")))
	var mana_before := float(mana.get("current"))
	checks["starts"] = str(caster.call("_try_cast", "elet", building.global_position, building.get_path())) == "Teleport"
	checks["casting"] = caster.is_casting()
	var frames := 0
	while caster.is_casting() and frames < 400:
		await _frames(1)
		frames += 1
	checks["casting_time_frames"] = frames >= 70 and frames <= 80
	await _frames(2)
	checks["jumped"] = absf(Vector2(wizard.global_position.x - 300.0, wizard.global_position.z).length() - RADIUS) < 0.5
	checks["pack_with_wizard"] = Vector2(pack.global_position.x - wizard.global_position.x, pack.global_position.z - wizard.global_position.z).distance_to(Vector2(8.0, 5.0)) < 0.5
	checks["mana_spent"] = mana_before - float(mana.get("current")) > 700.0
	var index := int(book.call("structure_index_of", "elet"))
	checks["cooldown_after"] = float(book.call("structure_cooldown", index)) > 10.0
	checks["cooling_answer"] = str(caster.call("_try_cast", "elet", building.global_position, building.get_path())) == SpellAction.COOLING
	## The wizard dies in the middle: nobody moves.
	var mortal := _wizard(Vector3(0.0, 0.0, 450.0))
	mortal.owner_slot = 1
	var mortal_pack := _unit(Vector3(4.0, 0.0, 454.0), 1)
	var anchor := _structure(Vector3(300.0, 0.0, 450.0), 1)
	await _frames(3)
	mortal.get_node("ManaPool").set("current", float(mortal.get_node("ManaPool").get("maximum")))
	var mortal_caster := mortal.get_node("Caster")
	checks["mortal_starts"] = str(mortal_caster.call("_try_cast", "elet", anchor.global_position, anchor.get_path())) == "Teleport"
	await _frames(20)
	var mortal_home := mortal.global_position
	var pack_home := mortal_pack.global_position
	mortal.get_node("Health").damage(99999.0, 2)
	await _frames(100)
	checks["wizard_died_pack_stays"] = mortal_pack.global_position.distance_to(pack_home) < 1.0
	checks["wizard_died_body_stays"] = Vector2(mortal.global_position.x - mortal_home.x, mortal.global_position.z - mortal_home.z).length() < 1.0
	checks["wizard_died_cast_over"] = not mortal_caster.is_casting()
	## The building falls in the middle: the jump happens to the last destination.
	var third := _wizard(Vector3(0.0, 0.0, -450.0))
	var third_building := _structure(Vector3(300.0, 0.0, -450.0), 1)
	await _frames(3)
	third.get_node("ManaPool").set("current", float(third.get_node("ManaPool").get("maximum")))
	var third_caster := third.get_node("Caster")
	checks["third_starts"] = str(third_caster.call("_try_cast", "elet", third_building.global_position, third_building.get_path())) == "Teleport"
	await _frames(20)
	third_building.free()
	var waited := 0
	while third_caster.is_casting() and waited < 400:
		await _frames(1)
		waited += 1
	await _frames(2)
	checks["building_fell_still_jumps"] = absf(Vector2(third.global_position.x - 300.0, third.global_position.z + 450.0).length() - RADIUS) < 0.5
	for node in [wizard, building, pack, mortal, mortal_pack, anchor, third, third_building]:
		if is_instance_valid(node):
			node.queue_free()
	return _verdict("teleport_cast", checks)


func _wizard(at: Vector3) -> WizardBody:
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = 1
	wizard.god = GOD
	_root.add_child(wizard)
	wizard.global_position = at
	return wizard


func _structure(at: Vector3, slot := 1) -> Node3D:
	var structure := STRUCTURE_SCENE.instantiate() as Node3D
	structure.set("owner_slot", slot)
	structure.position = at
	_root.add_child(structure)
	return structure


func _unit(at: Vector3, slot: int) -> UnitBody:
	var type := GameData.creature(TAG)
	var unit := UNIT_SCENE.instantiate() as UnitBody
	unit.owner_slot = slot
	unit.type = GameData.creature(TAG)
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


func _verdict(name: String, checks: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		if checks[key] is bool and not checks[key]:
			ok = false
			print("teleport_cases: falla %s.%s" % [name, key])
	checks["ok"] = ok
	return checks
