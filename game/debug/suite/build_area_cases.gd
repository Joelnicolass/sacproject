extends RefCounted

## 064 S1 cases of rules_suite: a structure over a manafount. Creatures and wizards never refuse it, a building on the BuildArea
## does; a fount with a tower answers fount_taken; the tower is born rising when the cast starts, cannot be hurt while it rises,
## goes when the cast is cut and stands when it ends with nobody left inside its box; the wizard stands still meanwhile; the push
## strength; and the preview's aim_for is the same answer as action_status. No network: the server paths run as solo. The cast is
## stepped by hand (Caster and StructureAction physics with 1/60 s), so a case does not wait seconds.

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const FOUNT_SCENE := preload("res://scenes/map/props/manafount.tscn")
const RULES := preload("res://data/match_rules.tres")
const RANGER: CreatureType = preload("res://data/catalog/creatures/ranger.tres")
const TICK := 1.0 / 60.0
const MAX_TICKS := 2000

var _host: Node3D
var _root: Node3D


func run(host: Node3D) -> Dictionary:
	_host = host
	_root = Node3D.new()
	_root.name = "BuildAreaCases"
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5000.0, 2.0, 5000.0)
	shape.shape = box
	shape.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(shape)
	_root.add_child(floor_body)
	_host.add_child(_root)
	var out := {}
	out["build_area_push"] = _push()
	out["build_area_rule"] = await _rule()
	out["build_area_cast"] = await _cast("james", "htlm", 1)
	out["build_area_shrine"] = await _cast("persephone", "pcas", 3)
	out["build_area_cut"] = await _cut()
	_root.queue_free()
	return out


## Criterion 3: pushAll(5, 15, 5) is 5 at 5 m, 2.5 at 10 m, 0 at 15 m and 7.5 at the middle.
func _push() -> Dictionary:
	var checks := {}
	checks["at_core"] = is_equal_approx(BodyNudge.push_speed(5.0, 5.0, 15.0, 5.0), 5.0)
	checks["at_10"] = is_equal_approx(BodyNudge.push_speed(10.0, 5.0, 15.0, 5.0), 2.5)
	checks["at_edge"] = is_equal_approx(BodyNudge.push_speed(15.0, 5.0, 15.0, 5.0), 0.0)
	checks["at_middle"] = is_equal_approx(BodyNudge.push_speed(0.0, 5.0, 15.0, 5.0), 7.5)
	return _verdict("build_area_push", checks)


## Criteria 1, 4, 5 and 6: who refuses and why, always the same answer from aim_for and action_status.
func _rule() -> Dictionary:
	var checks := {}
	var fount := _fount(Vector3(2000.0, 0.0, 0.0))
	var wizard := _wizard(1, fount.global_position + Vector3(10.0, 0.0, 0.0), "james", 1)
	var own := _unit(1, fount.global_position + Vector3(0.0, 0.0, 5.0))
	var foe := _unit(2, fount.global_position + Vector3(-8.0, 0.0, 0.0))
	await _frames(2)
	var caster := wizard.get_node("Caster") as Caster
	var at := fount.global_position
	checks["area_is_15"] = fount.build_area != null and is_equal_approx(fount.build_area.radius_m(), 15.0)
	checks["units_do_not_refuse"] = _same(caster, at, "") and caster.aim_for("htlm", at, null).site == fount
	checks["wizard_near_does_not_refuse"] = _same(caster, at, "")
	var building := Node3D.new()
	building.add_to_group(&"structure")
	_root.add_child(building)
	building.global_position = at + Vector3(0.0, 0.0, -10.0)
	checks["building_10_m_occupied"] = _same(caster, at, Refusal.OCCUPIED)
	building.global_position = at + Vector3(0.0, 0.0, -16.0)
	checks["building_16_m_ok"] = _same(caster, at, "")
	building.free()
	var by := Node3D.new()
	by.set_script(preload("res://debug/suite/slot_node.gd"))
	_root.add_child(by)
	fount.occupy(by.get_path())
	checks["taken_fount"] = _same(caster, at, Refusal.FOUNT_TAKEN) and caster.aim_for("htlm", at, null).site == fount
	fount.release(by.get_path())
	by.free()
	wizard.global_position = Vector3(-2000.0, 0.0, 0.0)
	var none := caster.aim_for("htlm", wizard.global_position, null)
	checks["no_fount"] = _same(caster, wizard.global_position, Refusal.NO_FOUNT) and none.site == null
	for node: Node in [fount, wizard, own, foe]:
		node.queue_free()
	await _frames(2)
	return _verdict("build_area_rule", checks)


## Criterion 2 and Q6: a whole cast with still bodies between 3 and 10 m. The tower is there from the start, rising and unhurt; the
## wizard does not walk; at the end it stands and no live body is inside its box or nearer than footprint + margin.
func _cast(god: String, tag: String, level: int) -> Dictionary:
	var checks := {}
	var key := tag + "_"
	var setup := await _scene(god, level)
	var fount: ManafountBody = setup["fount"]
	var wizard: WizardBody = setup["wizard"]
	var towers: Node3D = setup["towers"]
	var caster := wizard.get_node("Caster") as Caster
	var bodies: Array[Node3D] = [wizard]
	for spot: Vector3 in [Vector3(3.0, 0.0, 0.0), Vector3(0.0, 0.0, 6.0), Vector3(-7.0, 0.0, -1.0), Vector3(2.0, 0.0, -10.0)]:
		bodies.append(_unit(1 if bodies.size() % 2 == 0 else 2, fount.global_position + spot))
	await _frames(2)
	var index := caster.spellbook.structure_index_of(tag)
	caster.request_structure(index, fount.global_position)
	var tower := towers.get_child(0) as CastTower if towers.get_child_count() == 1 else null
	checks[key + "born_at_start"] = caster.is_casting() and tower != null and tower.is_rising() and not fount.is_free()
	checks[key + "rising_unhurt"] = tower != null and tower.health.damage(1000.0, 2) == 0.0 and not tower.is_targetable()
	checks[key + "wizard_stands"] = caster.holds_wizard()
	var ticks := 0
	var action := caster.action_for(tag) as StructureAction
	while caster.is_casting() and ticks < MAX_TICKS:
		action._physics_process(TICK)
		caster._physics_process(TICK)
		ticks += 1
		if ticks == 300 and tower != null:
			checks[key + "progress_mid"] = tower.build_progress > 0.2 and tower.build_progress < 0.9
	checks[key + "cast_ended"] = not caster.is_casting() and ticks > 300 and ticks < MAX_TICKS
	checks[key + "tower_stands"] = tower != null and is_instance_valid(tower) and not tower.is_rising() and tower.is_targetable()
	if tower != null and is_instance_valid(tower):
		var box := tower.global_transform * tower.hit_box()
		var reach := tower.footprint_m() + TowerRules.MARGIN_M - 0.01
		var inside := 0
		var near := 0
		for body in bodies:
			inside += 1 if BodyNudge.box(body).intersects(box) else 0
			near += 1 if Vector2(body.global_position.x - tower.global_position.x, body.global_position.z - tower.global_position.z).length() < reach else 0
		checks[key + "none_inside_box"] = inside == 0
		checks[key + "none_near"] = near == 0
		tower.queue_free()
	for body in bodies:
		body.queue_free()
	await _teardown(setup)
	return _verdict("build_area_cast", checks)


## Q6: a cut cast frees the rising tower and the fount; the wizard walks again.
func _cut() -> Dictionary:
	var checks := {}
	var setup := await _scene("james", 1)
	var fount: ManafountBody = setup["fount"]
	var wizard: WizardBody = setup["wizard"]
	var towers: Node3D = setup["towers"]
	var caster := wizard.get_node("Caster") as Caster
	caster.request_structure(caster.spellbook.structure_index_of("htlm"), fount.global_position)
	var action := caster.action_for("htlm") as StructureAction
	for _i in 60:
		action._physics_process(TICK)
		caster._physics_process(TICK)
	checks["rising_before_cut"] = towers.get_child_count() == 1 and (towers.get_child(0) as CastTower).is_rising()
	caster._interrupt()
	await _frames(2)
	checks["tower_gone"] = towers.get_child_count() == 0
	checks["fount_free"] = fount.is_free()
	checks["wizard_free"] = not caster.holds_wizard() and not caster.is_casting()
	wizard.queue_free()
	await _teardown(setup)
	return _verdict("build_area_cut", checks)


## A fount, the tower spawner, and a wizard of `god` at 12 m with mana to spare.
func _scene(god: String, level: int) -> Dictionary:
	var towers := Node3D.new()
	towers.name = "Towers"
	_root.add_child(towers)
	var fount := _fount(Vector3(0.0, 0.0, 2000.0))
	var wizard := _wizard(1, fount.global_position + Vector3(12.0, 0.0, 0.0), god, level)
	await _frames(2)
	var spawner := StructureSpawner.new()
	spawner.spawn_path = NodePath("../Towers")
	for tag in ["htlm", "pcas"]:
		var spell := wizard.get_node("Caster").get("spellbook").structure_by_tag(tag) as SpellType
		if spell != null and wizard.god_type.structure_for(spell) != null:
			spawner.scenes.append(wizard.god_type.structure_for(spell).scene)
	_root.add_child(spawner)
	var pool := wizard.get_node("ManaPool") as ManaPool
	pool.maximum = 10000.0
	pool.current = 10000.0
	return {"fount": fount, "wizard": wizard, "towers": towers, "spawner": spawner}


func _teardown(setup: Dictionary) -> void:
	for key in ["fount", "spawner", "towers"]:
		(setup[key] as Node).queue_free()
	await _frames(2)


## aim_for and action_status give the same `status` at `point`.
func _same(caster: Caster, point: Vector3, status: String) -> bool:
	var aim := caster.aim_for("htlm", point, null)
	return aim.status == status and caster.action_status("htlm", point, null) == aim.status


func _fount(at: Vector3) -> ManafountBody:
	var fount := FOUNT_SCENE.instantiate() as ManafountBody
	fount.position = at
	_root.add_child(fount)
	return fount


func _wizard(slot: int, at: Vector3, god: String, level: int) -> WizardBody:
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = slot
	wizard.god_type = GameData.god(god)
	wizard.level = level
	wizard.position = at
	_root.add_child(wizard)
	wizard.god_type = GameData.god(god)
	var pool := wizard.get_node("ManaPool") as ManaPool
	pool.maximum = 10000.0
	pool.current = 10000.0
	return wizard


func _unit(slot: int, at: Vector3) -> UnitBody:
	var unit := UNIT_SCENE.instantiate() as UnitBody
	unit.owner_slot = slot
	unit.type = RANGER
	unit.model = RANGER.model_id()
	unit.rules = RULES
	unit.idle_aggro = false
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
			print("build_area_cases: falla %s.%s" % [name, key])
	checks["ok"] = ok
	return checks
