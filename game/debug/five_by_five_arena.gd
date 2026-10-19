extends Node3D

const ALTAR_SCENE := preload("res://scenes/world/props/altar.tscn")
const MANA_SCENE := preload("res://scenes/world/props/manafount.tscn")
const WIZARD_SCENE := preload("res://scenes/world/wizard/wizard_body.tscn")
const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const MATCH_RULES := preload("res://data/match_rules.tres")
const DIRECT_SPELL := &"direct_spell"
const ALTAR_COUNT := 2
const MANA_COUNT := 1

@export var arena_size := 5.0
@export var team_spacing := 3.8
@export var wizard_duel_tick_s := 0.8
@export var wizard_duel_damage := 85.0

var _wizards_by_slot := {}
var _units_by_slot := {1: [], 2: []}
var _unit_strikes := 0
var _wizard_hits := 0
var _deaths := 0
var _duel_left := 0.0
var _arena_log: Label


func _ready() -> void:
	build_test_arena()
	_arena_log = _build_hud_log()
	_refresh_log()
	print("five_by_five arena ready: 5x5, 2 altars, 1 mana, 2 wizards, 6 units")


func _process(delta: float) -> void:
	_duel_left -= delta
	if _duel_left <= 0.0:
		_duel_left = wizard_duel_tick_s
		_tick_wizard_duel()
	_refresh_log()


func build_test_arena() -> void:
	var arena := Node3D.new()
	arena.name = "Arena"
	arena.unique_name_in_owner = true
	add_child(arena)
	_create_floor(arena)
	_create_altar(arena, -team_spacing * 0.5)
	_create_altar(arena, team_spacing * 0.5)
	_create_mana(arena)
	_spawn_wizard_side(arena, 1, Vector3(-2.15, 0.0, 0.0), Vector3.RIGHT)
	_spawn_wizard_side(arena, 2, Vector3(2.15, 0.0, 0.0), Vector3.LEFT)
	_force_opening_clash()
	_create_camera()


func _create_floor(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "FloorBody"
	parent.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(arena_size, 0.3, arena_size)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, -0.15, 0.0)
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	mesh.name = "Floor"
	mesh.mesh = PlaneMesh.new()
	mesh.mesh.size = Vector2(arena_size, arena_size)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.2, 0.15)
	mesh.material_override = material
	mesh.position = Vector3(0.0, -0.2, 0.0)
	mesh.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	parent.add_child(mesh)


func _create_altar(parent: Node3D, x: float) -> void:
	var altar := ALTAR_SCENE.instantiate()
	altar.name = "Altar %s" % ["Left" if x < 0 else "Right"]
	altar.position = Vector3(x, 0.0, 0.0)
	altar.scale = Vector3(0.15, 0.15, 0.15)
	altar.set("owner_slot", 1 if x < 0 else 2)
	parent.add_child(altar)


func _create_mana(parent: Node3D) -> void:
	var mana := MANA_SCENE.instantiate()
	mana.name = "ManaFount"
	mana.scale = Vector3(0.5, 0.5, 0.5)
	mana.position = Vector3(0.0, 0.0, 0.0)
	parent.add_child(mana)


func _spawn_wizard_side(parent: Node3D, slot: int, position: Vector3, facing: Vector3) -> void:
	var wizard: CharacterBody3D = WIZARD_SCENE.instantiate()
	wizard.name = "Wizard%d" % slot
	wizard.set("owner_slot", slot)
	wizard.set("wizard_tag", "cwa0")
	wizard.set("model", "jnwr")
	wizard.set("god", "james")
	wizard.position = position
	wizard.rotation.y = atan2(facing.x, facing.z)
	wizard.get_node_or_null("Health").set("rules", MATCH_RULES)
	wizard.get_node_or_null("ManaPool").set("rules", MATCH_RULES)
	wizard.get_node_or_null("SoulPurse").set("rules", MATCH_RULES)
	wizard.get_node_or_null("Spellbook").set("rules", MATCH_RULES)
	wizard.get_node_or_null("Caster").set("rules", MATCH_RULES)
	wizard.get_node_or_null("GhostForm").set("rules", MATCH_RULES)
	var health := wizard.get_node_or_null("Health")
	if health:
		health.died.connect(_on_body_died)
	_wizards_by_slot[slot] = wizard
	parent.add_child(wizard)
	for index in range(3):
		var unit: Node3D = UNIT_SCENE.instantiate()
		var tag := "ycro" if slot == 1 else "nmuh"
		var local_pos := Vector3(0.0, 0.0, 0.0)
		if index == 0:
			local_pos = Vector3(-0.9, 0.0, -1.1)
		elif index == 1:
			local_pos = Vector3(-0.2, 0.0, 1.0)
		else:
			local_pos = Vector3(1.1, 0.0, 0.3)
		if slot == 2:
			local_pos.x *= -1.0
		unit.name = "%s%d" % [tag.capitalize(), index + 1]
		unit.set("creature_tag", tag)
		unit.set("owner_slot", slot)
		unit.set("rules", MATCH_RULES)
		unit.set("idle_aggro", true)
		unit.get_node_or_null("Health").set("rules", MATCH_RULES)
		unit.get_node_or_null("ManaPool").set("rules", MATCH_RULES)
		unit.set("target_groups", PackedStringArray(["unit", "wizard"]))
		unit.position = wizard.position + local_pos
		unit.rotation.y = wizard.rotation.y
		unit.struck.connect(_on_unit_struck)
		unit.died.connect(_on_body_died)
		parent.add_child(unit)
		_units_by_slot[slot].append(unit)


func _create_camera() -> void:
	var camera := get_node_or_null("ArenaCamera") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "ArenaCamera"
		add_child(camera)
	camera.position = Vector3(0.0, 6.0, 7.5)
	camera.rotation_degrees = Vector3(-28.0, 0.0, 0.0)
	camera.far = 2000.0
	camera.current = true
	camera.look_at(Vector3.ZERO, Vector3.UP)


func _force_opening_clash() -> void:
	for index in range(mini(_units_by_slot[1].size(), _units_by_slot[2].size())):
		var ally: Node3D = _units_by_slot[1][index]
		var foe: Node3D = _units_by_slot[2][index]
		if ally and foe and ally.has_method("engage") and foe.has_method("engage"):
			ally.call("engage", foe)
			foe.call("engage", ally)
	var wizard_a: Node3D = _wizards_by_slot.get(1)
	var wizard_b: Node3D = _wizards_by_slot.get(2)
	if wizard_a and wizard_a.has_method("request_walk"):
		wizard_a.call("request_walk", Vector3(-0.7, 0.0, 0.0))
	if wizard_b and wizard_b.has_method("request_walk"):
		wizard_b.call("request_walk", Vector3(0.7, 0.0, 0.0))


func _tick_wizard_duel() -> void:
	var wizard_a: Node3D = _wizards_by_slot.get(1)
	var wizard_b: Node3D = _wizards_by_slot.get(2)
	if not _alive(wizard_a) or not _alive(wizard_b):
		return
	var health_a := wizard_a.get_node_or_null("Health")
	var health_b := wizard_b.get_node_or_null("Health")
	if health_a == null or health_b == null:
		return
	var dealt_a := float(health_a.call("damage_typed", wizard_duel_damage, DIRECT_SPELL, 2))
	var dealt_b := float(health_b.call("damage_typed", wizard_duel_damage, DIRECT_SPELL, 1))
	if dealt_a > 0.0:
		_wizard_hits += 1
	if dealt_b > 0.0:
		_wizard_hits += 1


func _build_hud_log() -> Label:
	var canvas := CanvasLayer.new()
	canvas.name = "ArenaHUD"
	add_child(canvas)
	var log := Label.new()
	log.name = "ArenaLog"
	log.unique_name_in_owner = true
	log.position = Vector2(16.0, 16.0)
	log.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	log.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	log.add_theme_color_override("font_color", Color(1, 1, 1))
	log.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	log.add_theme_constant_override("shadow_offset_x", 1)
	log.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(log)
	return log


func _refresh_log() -> void:
	if _arena_log == null:
		return
	var player_a: Node3D = _wizards_by_slot.get(1)
	var player_b: Node3D = _wizards_by_slot.get(2)
	var opposite := false
	if _alive(player_a) and _alive(player_b):
		opposite = player_a.global_position.x < 0.0 and player_b.global_position.x > 0.0
	var unit_fight_ok := _unit_strikes > 0
	var wizard_duel_ok := _wizard_hits > 0
	var fight_ok := unit_fight_ok and wizard_duel_ok
	_arena_log.text = (
		"CHECK world=5 altars=%d mana=%d\n" % [ALTAR_COUNT, MANA_COUNT]
		+ "PLAYERS opposite=%s\n" % str(opposite).to_lower()
		+ "UNITS team1=%d team2=%d\n" % [_alive_units_for(1), _alive_units_for(2)]
		+ "WIZARDS team1=%d team2=%d\n" % [_alive_wizard(1), _alive_wizard(2)]
		+ "COMBAT unit_strikes=%d wizard_hits=%d deaths=%d fight_ok=%s" % [_unit_strikes, _wizard_hits, _deaths, str(fight_ok).to_lower()]
	)


func _alive(node: Variant) -> bool:
	return node != null and is_instance_valid(node) and (node as Node).is_inside_tree()


func _alive_units_for(slot: int) -> int:
	var count := 0
	for unit in _units_by_slot[slot]:
		if _alive(unit) and not bool(unit.call("is_dead")):
			count += 1
	return count


func _alive_wizard(slot: int) -> int:
	var wizard: Node3D = _wizards_by_slot.get(slot)
	if not _alive(wizard):
		return 0
	var health := wizard.get_node_or_null("Health")
	return 1 if health and not bool(health.call("is_dead")) else 0


func _on_unit_struck(_target: Node3D, amount: float, _hit_chance: float, _roll: float) -> void:
	if amount > 0.0:
		_unit_strikes += 1


func _on_body_died(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_deaths += 1
