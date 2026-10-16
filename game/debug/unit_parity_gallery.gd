extends Node3D

const WIZARD_SCENE := preload("res://scenes/world/wizard/wizard_body.tscn")
const UNIT_SCENE := preload("res://scenes/world/units/unit.tscn")
const STRUCTURE_SCENE := preload("res://scenes/world/structures/structure.tscn")
const RULES := preload("res://data/match_rules.tres")

@export var wizard_tags: PackedStringArray = ["cwa0", "cwa1", "cwa2", "cwa3", "cwa4", "cwa5"]
## CRE8 tags shown instead of the books (RFC-028c: the map's Farmer and Taurock). Empty = the books.
@export var unit_tags: PackedStringArray = []
## Clip roles that debug_anim_cycle / check_tick go through, in order.
@export var cycle_roles: PackedStringArray = ["idle", "run", "attack"]
## The Manalith + Manahoar mana probe of the roster gallery.
@export var mana_probe := true
@export var book_gods: PackedStringArray = ["james", "persephone", "pyro", "stratos", "charnel"]
## Wizard level of the books (GameData.book): 1 is the roster the game uses today, 9 the whole bestiary (F112).
@export_range(0, 9) var max_level := 1
## One row per god (the shared Manahoar stays in the first one) instead of filling `columns` in order.
@export var row_per_god := false
@export var columns := 8
@export var spacing := 6.0
@export var row_gap := 10.0
## Draws the CollisionShape3D of every body (the capsule the game gives it) over its model.
@export var show_collisions := true
## F134: stops the bodies' clocks (clips, physics, AI). Each role change shows frame 0 of its clip and stays there,
## so a capture compares the same frame every time.
@export var freeze_time := false
## F134: degrees the units turn around +y after spawning (90 = profile for a camera looking down -z).
@export_range(-180.0, 180.0, 1.0) var face_yaw_deg := 0.0

var _cycle_idx := 0
var _wizards: Array[Node3D] = []
var _units: Array[Node3D] = []
var _structures: Array[Node3D] = []
var _units_end_row := 1
var _probe_wizard: Node3D
var _probe_manahoar: Node3D
var _probe_mana_start := -1.0
var _probe_status := "pending"

@onready var _actors: Node3D = %Actors
@onready var _label: Label = %Debug


func _ready() -> void:
	# Must be set before the bodies enter the tree: it is read when each shape is created.
	get_tree().debug_collisions_hint = show_collisions
	_spawn_all()
	_apply_cycle()
	if freeze_time:
		# Method calls still reach the bodies (debug_set_clip_state shows frame 0 of the new clip); only the clocks stop.
		_actors.process_mode = Node.PROCESS_MODE_DISABLED
	set_process(true)
	call_deferred("_start_probe")


func _exit_tree() -> void:
	get_tree().debug_collisions_hint = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_anim_cycle") or event.is_action_pressed("check_tick"):
		_cycle_idx = (_cycle_idx + 1) % maxi(1, cycle_roles.size())
		_apply_cycle()


func _process(_delta: float) -> void:
	_refresh_label()
	_update_probe_status()


func _spawn_all() -> void:
	for child in _actors.get_children():
		child.queue_free()
	_wizards.clear()
	_units.clear()
	_structures.clear()
	_spawn_wizards()
	_spawn_units()
	if mana_probe:
		_spawn_probe_structures()


func _spawn_wizards() -> void:
	var row := 0
	for index in wizard_tags.size():
		var tag := wizard_tags[index]
		var wizard := WIZARD_SCENE.instantiate() as Node3D
		var wiz := _wizard_for_tag(tag)
		wizard.name = "Wizard_%s" % tag
		wizard.set("owner_slot", 1)
		wizard.set("wizard_tag", tag)
		wizard.set("model", wiz.get("model", ""))
		wizard.set("god", wiz.get("god", "james"))
		wizard.position = _grid_pos(index, row)
		_actors.add_child(wizard)
		_wizards.append(wizard)
		if tag == "cwa0":
			_probe_wizard = wizard


func _spawn_units() -> void:
	var rows := _summonable_rows()
	var row := 1
	for tags: PackedStringArray in rows:
		for index in tags.size():
			_spawn_unit(tags[index], _grid_pos(index % columns, row + int(index / columns)))
		row += maxi(1, ceili(float(tags.size()) / float(maxi(1, columns))))
	_units_end_row = row


func _spawn_unit(tag: String, at: Vector3) -> void:
	var unit := UNIT_SCENE.instantiate() as Node3D
	var type := GameData.creature(tag)
	unit.name = "Unit_%s" % tag
	unit.set("owner_slot", 1)
	unit.set("creature_tag", tag)
	unit.set("rules", RULES)
	unit.set("model", str(type.model) if type else "")
	unit.set("idle_aggro", false)
	unit.set("mode", 0)
	unit.position = at
	unit.rotation.y = deg_to_rad(face_yaw_deg)
	_actors.add_child(unit)
	_units.append(unit)
	if tag == "oham":
		_probe_manahoar = unit


func _spawn_probe_structures() -> void:
	var row := maxi(3, _units_end_row)
	var structure := STRUCTURE_SCENE.instantiate() as Node3D
	structure.name = "Probe_Manalith"
	structure.set("owner_slot", 1)
	structure.set("spell_tag", "htlm")
	structure.set("model", "mana")
	structure.position = _grid_pos(0, row)
	_actors.add_child(structure)
	_structures.append(structure)
	if _probe_manahoar:
		_probe_manahoar.global_position = structure.global_position + Vector3(25.0, 0.0, 0.0)
	if _probe_wizard:
		_probe_wizard.global_position = structure.global_position + Vector3(35.0, 0.0, 0.0)


## Creature tags of the books up to `max_level`, without repeats: one list per god with `row_per_god`, else one list.
func _summonable_rows() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	if not unit_tags.is_empty():
		rows.append(unit_tags)
		return rows
	var seen: Dictionary = {}
	var current := PackedStringArray()
	for god in book_gods:
		if row_per_god and not current.is_empty():
			rows.append(current)
			current = PackedStringArray()
		var book := GameData.book(str(god), max_level)
		for creature: CreatureType in book.get("creatures", []):
			if creature == null or creature.tag.is_empty() or seen.has(creature.tag):
				continue
			seen[creature.tag] = true
			current.append(creature.tag)
	rows.append(current)
	return rows


func _grid_pos(index: int, row: int) -> Vector3:
	var x := (float(index % columns) - float(columns - 1) * 0.5) * spacing
	var z := float(row) * row_gap
	return Vector3(x, 0.0, z)


func _wizard_for_tag(tag: String) -> Dictionary:
	var type := GameData.wizard(tag)
	if type == null:
		return {}
	return {
		"model": type.model,
		"god": "james",
	}


func _apply_cycle() -> void:
	var role := current_role()
	for wizard in _wizards:
		if wizard and wizard.has_method("debug_set_clip_state"):
			wizard.call("debug_set_clip_state", "run" if role == "run" else "idle")
	for unit in _units:
		_set_flight(unit, role == "fly")
		if unit and unit.has_method("debug_set_clip_state"):
			unit.call("debug_set_clip_state", role)


## F135: on the "fly" role a hybrid flier is put in FLYING (its capsule takes the flying height); otherwise GROUND.
## Only the bench does this: in a match Flight changes state on its own.
func _set_flight(unit: Node3D, flying: bool) -> void:
	var flight := unit.get_node_or_null("Flight") as Flight if unit else null
	if flight == null:
		return
	flight.state = Flight.State.FLYING if flying and flight.is_capable() else Flight.State.GROUND


## The clip role the gallery is showing now ("" with no roles).
func current_role() -> String:
	return cycle_roles[_cycle_idx] if _cycle_idx < cycle_roles.size() else ""


func _start_probe() -> void:
	if _probe_wizard == null:
		_probe_status = "no_wizard"
		return
	var pool := _probe_wizard.get_node_or_null("ManaPool")
	if pool == null:
		_probe_status = "no_mana_pool"
		return
	pool.call("setup", 2000.0)
	pool.set("current", 250.0)
	_probe_mana_start = float(pool.get("current"))
	_probe_status = "running"


func _update_probe_status() -> void:
	if _probe_status != "running" or _probe_wizard == null:
		return
	var pool := _probe_wizard.get_node_or_null("ManaPool")
	if pool == null:
		_probe_status = "no_mana_pool"
		return
	var current := float(pool.get("current"))
	if current > _probe_mana_start + 10.0:
		_probe_status = "pass"


func _refresh_label() -> void:
	if _label == null:
		return
	var lines: Array[String] = []
	lines.append("cycle: %s | Tab/check_tick para cambiar" % current_role())
	if mana_probe:
		lines.append("probe manahoar mana: %s" % _probe_status)
	lines.append("wizards:")
	for wizard in _wizards:
		lines.append("  %s" % _actor_line(wizard))
	lines.append("units (%d summonable):" % _units.size())
	for unit in _units:
		lines.append("  %s" % _actor_line(unit))
	_label.text = "\n".join(lines)


func _actor_line(body: Node3D) -> String:
	if body == null or not is_instance_valid(body):
		return "null"
	var info: Dictionary = {}
	if body.has_method("debug_clip_info"):
		var value: Variant = body.call("debug_clip_info")
		if value is Dictionary:
			info = value
	var model := str(body.get("model"))
	var extras := ""
	var creature_tag := str(body.get("creature_tag"))
	if not creature_tag.is_empty():
		var creature := GameData.creature(creature_tag)
		if creature:
			extras = " ability=%s abilities=%s" % [creature.active_ability_tag, ",".join(creature.ability_tags)]
	var col := body.get_node_or_null("Collision") as CollisionShape3D
	var capsule := col.shape as CapsuleShape3D if col else null
	if capsule:
		extras += " cap_h=%.2f" % capsule.height
	return "%s model=%s role=%s tag=%s frame=%d fps=%d rot_y=%.1f y=%.2f%s" % [
		body.name,
		model,
		info.get("role", ""),
		info.get("tag", ""),
		int(info.get("frame", 0)),
		int(info.get("fps", 0)),
		rad_to_deg(body.rotation.y),
		body.position.y,
		extras,
	]
