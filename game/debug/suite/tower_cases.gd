extends RefCounted

## RFC-061a cases of rules_suite: the ten towers (Manalith and Shrine) as scenes. Their numbers, their regeneration, the mana they
## give to the side and its allies, who feeds a Manahoar, where Convert takes a creature, the guardian post, Teleport and the cast
## of the Shrine over a fount. No network: the server paths run as solo. `run(host)` adds its own bodies and removes them.
## Time is driven by calling the physics step of each piece with a chosen delta, so a case does not wait seconds.

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const ALTAR_SCENE := preload("res://scenes/map/props/altar.tscn")
const FOUNT_SCENE := preload("res://scenes/map/props/manafount.tscn")
const SOUL_SCENE := preload("res://scenes/souls/soul.tscn")
const SYSTEM_SCENE := preload("res://scenes/sacrifice/sacrifice_system.tscn")
const RULES := preload("res://data/match_rules.tres")
const MANAHOAR: CreatureType = preload("res://data/catalog/creatures/manahoar.tres")
const MANALITHS: Array[String] = ["mana", "pyma", "jman", "stam", "cama"]
const SHRINES: Array[String] = ["pcsh", "pasp", "jsac", "stsp", "casp"]
const MANA_TOLERANCE := 0.01

var _host: Node3D
var _root: Node3D


func run(host: Node3D) -> Dictionary:
	_host = host
	_root = Node3D.new()
	_root.name = "TowerCases"
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
	SideRelations.set_rows(_rows(), 3)
	var out := {}
	out["tower_scenes"] = _scenes()
	out["tower_regen"] = await _regen()
	out["tower_mana"] = await _mana()
	out["tower_manahoar"] = await _manahoar()
	out["tower_convert"] = await _convert()
	out["tower_guard_teleport"] = await _guard_teleport()
	out["tower_cast"] = await _cast()
	SideRelations.refresh()
	_root.queue_free()
	return out


## The ten scenes: 5000 health, the role of the tag, the rate and the 50 m sphere, a guard post, a ritual site only on a Shrine.
func _scenes() -> Dictionary:
	var checks := {}
	for tag in MANALITHS + SHRINES:
		var shrine := tag in SHRINES
		var tower := _packed(tag).instantiate() as CastTower
		var key := tag
		checks[key + "_type"] = tower != null and tower.type.max_health == 5000.0 and tower.type.role == (BuildingType.Role.SHRINE if shrine else BuildingType.Role.MANALITH)
		checks[key + "_rate"] = absf(tower.mana_source.rate - (8.333 if shrine else 33.333)) < 0.001 and is_equal_approx(tower.mana_source.reach_m(), 50.0)
		checks[key + "_audit"] = tower.mana_source.source_name() == (&"shrine" if shrine else &"manalith")
		checks[key + "_post"] = tower.guard_post != null and tower.guard_post.attach_point != null
		checks[key + "_regen"] = is_equal_approx((tower.find_child("HealthRegen", false, false) as HealthRegen).refill_s, 60.0)
		var sites := tower.find_children("*", "RitualSite", true, false)
		checks[key + "_site"] = sites.size() == (1 if shrine else 0) and (not shrine or (sites[0] as RitualSite).building == tower)
		checks[key + "_no_warnings"] = tower._get_configuration_warnings().is_empty()
		tower.free()
	return _verdict("tower_scenes", checks)


## From 1000 to 5000 in 48 s (83.3 per second), one second at a time.
func _regen() -> Dictionary:
	var checks := {}
	var tower := _tower("jman", 1, Vector3.ZERO)
	await _frames(2)
	var health := tower.health
	var regen := tower.find_child("HealthRegen", false, false) as HealthRegen
	checks["full_at_start"] = is_equal_approx(health.maximum, 5000.0) and is_equal_approx(health.current, 5000.0)
	health.current = 1000.0
	regen._physics_process(1.0)
	checks["rate_83"] = absf(health.current - 1000.0 - 5000.0 / 60.0) < 0.1
	for _second in 47:
		regen._physics_process(1.0)
	checks["full_in_48_s"] = absf(health.current - 5000.0) < 1.0
	regen._physics_process(1.0)
	checks["no_overheal"] = health.current <= 5000.0
	tower.queue_free()
	return _verdict("tower_regen", checks)


## Ten seconds of mana: the Shrine 8.333/s, the Manalith 33.333/s, the altar 16.667/s; the side and its allies, not the enemy, not past 50 m.
func _mana() -> Dictionary:
	var checks := {}
	var shrine := _tower("jsac", 1, Vector3.ZERO)
	var near := _wizard(1, Vector3(49.0, 0.0, 0.0))
	var far := _wizard(1, Vector3(51.0, 0.0, 0.0))
	var ally := _wizard(2, Vector3(0.0, 0.0, 49.0))
	var foe := _wizard(3, Vector3(0.0, 0.0, -49.0))
	await _frames(2)
	_empty([near, far, ally, foe])
	shrine.mana_source._physics_process(10.0)
	checks["shrine_near"] = _close(_mana_of(near), 83.33)
	checks["shrine_far_zero"] = _mana_of(far) == 0.0
	checks["shrine_ally"] = _close(_mana_of(ally), 83.33)
	checks["shrine_enemy_zero"] = _mana_of(foe) == 0.0
	var manalith := _tower("jman", 1, Vector3(0.0, 0.0, 3.0))
	await _frames(2)
	near.global_position = Vector3(20.0, 0.0, 0.0)
	_empty([near])
	shrine.mana_source._physics_process(10.0)
	manalith.mana_source._physics_process(10.0)
	checks["shrine_plus_manalith"] = _close(_mana_of(near), 416.66)
	var altar := ALTAR_SCENE.instantiate() as Altar
	altar.owner_slot = 1
	altar.position = Vector3(0.0, 0.0, 400.0)
	_root.add_child(altar)
	var ally_near := _wizard(2, Vector3(20.0, 0.0, 400.0))
	await _frames(2)
	_empty([ally_near])
	altar.mana_source._physics_process(10.0)
	checks["altar_ally"] = _close(_mana_of(ally_near), 166.66)
	for node in [shrine, manalith, altar, near, far, ally, foe, ally_near]:
		node.queue_free()
	return _verdict("tower_mana", checks)


## A Manahoar is fed by Manaliths only, the allies' too: a Shrine alone gives it nothing.
func _manahoar() -> Dictionary:
	var checks := {}
	var shrine := _tower("jsac", 1, Vector3(900.0, 0.0, 0.0))
	var hoar := _unit(Vector3(920.0, 0.0, 0.0), 1)
	await _frames(2)
	var support := hoar.get_node("ManaSupport") as UnitManaSupport
	checks["is_manahoar"] = support.enabled
	checks["shrine_alone_zero"] = support.flame_rate() == 0.0
	var manalith := _tower("jman", 2, Vector3(900.0, 0.0, 30.0))
	await _frames(2)
	checks["ally_manalith_feeds"] = support.flame_rate() > 0.0
	shrine.queue_free()
	manalith.queue_free()
	hoar.queue_free()
	return _verdict("tower_manahoar", checks)


## Convert takes the creature to the closest altar or Shrine of the side; without either it is NO_ALTAR; the ritual holds the Shrine's site.
func _convert() -> Dictionary:
	var checks := {}
	var system := SYSTEM_SCENE.instantiate() as SacrificeSystem
	system.rules = RULES
	_root.add_child(system)
	var altar := ALTAR_SCENE.instantiate() as Altar
	altar.owner_slot = 1
	altar.position = Vector3(-600.0, 0.0, 60.0)
	_root.add_child(altar)
	var shrine := _tower("jsac", 1, Vector3(-600.0, 0.0, 20.0))
	await _frames(2)
	var from := Vector3(-600.0, 0.0, 0.0)
	var site := shrine.find_child("RitualSite", false, false) as RitualSite
	checks["shrine_closer"] = system.closest_own_site(1, from) == site
	checks["enemy_sees_none"] = system.closest_own_site(2, from) == null
	altar.state = Altar.State.DESTROYED
	checks["shrine_alone_arms"] = system.convert_arm_status(1, from) == "" and system.closest_own_site(1, from) == site
	var by := Node.new()
	_root.add_child(by)
	checks["site_occupied"] = site.occupy(by) and not site.is_free() and not site.occupy(by)
	site.release()
	checks["site_free_again"] = site.is_free()
	shrine.health.damage(99999.0, 2)
	checks["destroyed_not_standing"] = not site.is_standing() and system.convert_arm_status(1, from) == SacrificeSystem.NO_ALTAR
	by.free()
	system.queue_free()
	return _verdict("tower_convert", checks)


## Guardian finds the post of the Shrine and its beam ends 2.5 m over it; Teleport accepts the Shrine as a building of the side.
func _guard_teleport() -> Dictionary:
	var checks := {}
	var shrine := _tower("jsac", 1, Vector3(-300.0, 0.0, 300.0))
	var wizard := _wizard(1, Vector3.ZERO)
	await _frames(2)
	var post := GuardPost.closest(_host.get_tree(), 1, Vector3(-300.0, 0.0, 280.0))
	checks["post_found"] = post != null and post.host == shrine and post.is_open()
	checks["post_height"] = post != null and post.attach_position().is_equal_approx(shrine.global_position + Vector3(0.0, 2.5, 0.0))
	checks["foe_finds_none"] = GuardPost.closest(_host.get_tree(), 2, shrine.global_position) == null
	var teleport := wizard.get_node("Caster").action_for("elet") as TeleportAction
	checks["teleport_accepts"] = teleport != null and teleport.is_building_of(1, shrine) and not teleport.is_building_of(2, shrine)
	shrine.health.damage(99999.0, 2)
	checks["dead_not_target"] = not teleport.is_building_of(1, shrine)
	shrine.queue_free()
	wizard.queue_free()
	return _verdict("tower_guard_teleport", checks)


## pcas is no longer «not implemented»: it raises the god's Shrine over a free fount (Persephone pcsh, James jsac), born rising (no body
## stops on it, no mana) and standing at the finish, with the dead and the living moved out of its box; an occupied fount is
## FOUNT_TAKEN; when the tower falls the fount is free on its own.
func _cast() -> Dictionary:
	var checks := {}
	var towers := Node3D.new()
	towers.name = "Towers"
	_root.add_child(towers)
	var spawner := StructureSpawner.new()
	spawner.spawn_path = NodePath("../Towers")
	_root.add_child(spawner)
	var fount := FOUNT_SCENE.instantiate() as ManafountBody
	fount.position = Vector3(500.0, 0.0, 500.0)
	_root.add_child(fount)
	var results := {}
	for god in ["persephone", "james"]:
		var wizard := _wizard(1, Vector3(515.0, 0.0, 500.0), god, 3)
		await _frames(2)
		var caster := wizard.get_node("Caster")
		var spell: SpellType = caster.get("spellbook").structure_by_tag("pcas")
		var action := caster.action_for("pcas") as StructureAction
		var index := int(caster.get("spellbook").structure_index_of("pcas"))
		checks[god + "_in_book"] = spell != null and action != null and action.arm_status(wizard, spell) == ""
		checks[god + "_not_implemented_gone"] = index >= 0 and caster.structure_status(index) != SpellAction.NOT_IMPLEMENTED
		spawner.scenes = [wizard.god_type.structure_for(spell).scene]
		var dead := Node3D.new()
		dead.name = "Corpse"
		dead.add_to_group(Corpse.GROUP)
		dead.position = fount.global_position + Vector3(1.0, 0.0, 0.5)
		_root.add_child(dead)
		var soul := SOUL_SCENE.instantiate() as Soul
		soul.position = fount.global_position + Vector3(-0.5, 0.0, 1.0)
		_root.add_child(soul)
		var unit := _unit(fount.global_position + Vector3(0.0, 0.0, -2.0), 2)
		await _frames(2)
		var aim := action.check(wizard, spell, fount.global_position, null, "")
		checks[god + "_aim_ok"] = aim.status.is_empty()
		action.begin(wizard, spell, aim)
		var rising := towers.get_child(0) as CastTower if towers.get_child_count() == 1 else null
		checks[god + "_born_rising"] = rising != null and rising.is_rising() and rising.collision_layer == 0
		checks[god + "_rising_no_mana"] = rising != null and rising.mana_source.process_mode == Node.PROCESS_MODE_DISABLED
		checks[god + "_finish_quiet"] = action.finish(wizard, spell, wizard).is_empty()
		var tower := towers.get_child(0) as CastTower if towers.get_child_count() == 1 else null
		checks[god + "_stands"] = tower != null and not tower.is_rising() and tower.collision_layer != 0
		results[god] = tower.type.tag if tower != null else ""
		checks[god + "_fount_taken"] = tower != null and not fount.is_free()
		## The dead on the fount go out of the footprint (a doctor could never reach them inside the box), onto the ground.
		var ring := (tower.footprint_m() + TowerRules.MARGIN_M - 0.01) if tower != null else INF
		for body: Node3D in [dead, soul, unit]:
			var flat := Vector2(body.global_position.x - fount.global_position.x, body.global_position.z - fount.global_position.z)
			checks[god + "_%s_pushed_out" % body.name] = flat.length() >= ring and absf(body.global_position.y) < 0.05
		dead.queue_free()
		soul.queue_free()
		unit.queue_free()
		checks[god + "_busy_fount"] = action.check(wizard, spell, fount.global_position, null, "").status == StructureAction.FOUNT_TAKEN
		## RFC-056: the fount is free the tick it falls; the ruin stays `linger_s` (so every peer sees it fall) and then goes.
		var linger := MatchClock.ticks_for(tower.linger_s) if tower != null else 0
		if tower != null:
			tower.health.damage(99999.0, 2)
		await _frames(1)
		var free_at_once := fount.is_free()
		await _frames(linger + 3)
		checks[god + "_fount_free_after_fall"] = free_at_once and fount.is_free() and towers.get_child_count() == 0
		wizard.queue_free()
	checks["shrine_models"] = results.get("persephone", "") == "pcsh" and results.get("james", "") == "jsac"
	fount.queue_free()
	spawner.queue_free()
	towers.queue_free()
	return _verdict("tower_cast", checks)


func _packed(tag: String) -> PackedScene:
	return load("res://scenes/structures/buildings/_%s.tscn" % tag)


func _tower(tag: String, slot: int, at: Vector3) -> CastTower:
	var tower := _packed(tag).instantiate() as CastTower
	tower.owner_slot = slot
	tower.position = at
	_root.add_child(tower)
	return tower


func _wizard(slot: int, at: Vector3, god := "james", level := 1) -> WizardBody:
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = slot
	wizard.god_type = GameData.god(god)
	wizard.level = level
	wizard.position = at
	_root.add_child(wizard)
	## The wizard reads its seat's god when it enters; the case says it again.
	wizard.god_type = GameData.god(god)
	return wizard


func _unit(at: Vector3, slot: int) -> UnitBody:
	var type := MANAHOAR
	var unit := UNIT_SCENE.instantiate() as UnitBody
	unit.owner_slot = slot
	unit.type = MANAHOAR
	unit.model = type.model_id() if type else ""
	unit.rules = RULES
	unit.idle_aggro = false
	unit.position = at
	_root.add_child(unit)
	return unit


func _empty(wizards: Array) -> void:
	for wizard: WizardBody in wizards:
		var pool := wizard.get_node("ManaPool") as ManaPool
		pool.maximum = 10000.0
		pool.current = 0.0


func _mana_of(wizard: WizardBody) -> float:
	return (wizard.get_node("ManaPool") as ManaPool).current


func _close(value: float, expected: float) -> bool:
	return absf(value - expected) <= expected * MANA_TOLERANCE


## Three sides: seats 1 and 2 are allies, seat 3 is the enemy of both.
func _rows() -> Array:
	return [
		{"id": 0, "allies": 0b011, "enemies": 0b100, "assignment": 1},
		{"id": 1, "allies": 0b011, "enemies": 0b100, "assignment": 2},
		{"id": 2, "allies": 0b100, "enemies": 0b011, "assignment": 3},
	]


func _frames(count: int) -> void:
	for _i in count:
		await _host.get_tree().physics_frame


func _verdict(name: String, checks: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		if checks[key] is bool and not checks[key]:
			ok = false
			print("tower_cases: falla %s.%s" % [name, key])
	checks["ok"] = ok
	return checks
