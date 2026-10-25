extends RefCounted

## RFC-021a cases of rules_suite: the Structures tab dispatch (SpellAction) and ManalithAction.
## No physics frames: the checks call the action and the Caster directly.
## `run(host)` builds a wizard and stubs under `host` and removes them when it ends.

const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const GOD := "james"
## Tabs of the Structures tab with no action yet: none (Desecrate has one since RFC-020c, Convert since RFC-020e, Guardian since RFC-021b, Teleport since RFC-021c).
const WITHOUT_ACTION: Array[String] = []


const FOUNT_SCENE := preload("res://scenes/map/props/manafount.tscn")


func run(host: Node3D) -> Dictionary:
	var out := {}
	out["action_lookup"] = _action_lookup(host)
	out["manalith_action"] = _manalith_action(host)
	return out


## The Caster finds the action by tag; a tab entry with no action, or one whose child was taken
## out, answers «No implementado»; a SpellAction without tag or prompt warns in the inspector.
func _action_lookup(host: Node3D) -> Dictionary:
	var wizard := _wizard(host, Vector3.ZERO)
	var caster := wizard.get_node("Caster")
	var book: Node = caster.get("spellbook")
	var checks := {}
	var manalith: SpellAction = caster.action_for("htlm")
	checks["manalith_found"] = manalith is StructureAction
	checks["manalith_pick"] = manalith != null and manalith.pick == SpellAction.Pick.GROUND
	checks["manalith_prompt"] = manalith != null and manalith.prompt == "Elegí el suelo"
	checks["manalith_no_warnings"] = manalith != null and manalith._get_configuration_warnings().is_empty()
	var index := int(book.structure_index_of("htlm"))
	checks["manalith_armable"] = index >= 0 and caster.structure_status(index) == "" and caster.structure_action(index) == manalith
	var without := true
	for tag in WITHOUT_ACTION:
		var at := int(book.structure_index_of(tag))
		without = without and at >= 0 and caster.action_for(tag) == null
		without = without and caster.structure_status(at) == SpellAction.NOT_IMPLEMENTED and caster.structure_action(at) == null
	checks["others_not_implemented"] = without
	checks["unknown_tag_null"] = caster.action_for("zzzz") == null
	checks["not_implemented_key"] = SpellAction.NOT_IMPLEMENTED == &"not_implemented"
	var bare := SpellAction.new()
	checks["bare_warns"] = bare._get_configuration_warnings().size() == 2
	bare.free()
	var twin := StructureAction.new()
	twin.tag = "htlm"
	twin.prompt = "x"
	caster.actions.add_child(twin)
	checks["duplicate_tag_warns"] = twin._get_configuration_warnings().size() == 1
	caster.actions.remove_child(twin)
	twin.free()
	caster.actions.remove_child(manalith)
	manalith.free()
	checks["removed_gone"] = caster.action_for("htlm") == null
	checks["removed_not_implemented"] = caster.structure_status(index) == SpellAction.NOT_IMPLEMENTED
	checks["removed_request_is_quiet"] = caster._try_structure(index, Vector3.ZERO) == SpellAction.NOT_IMPLEMENTED
	checks["spells_tab_untouched"] = _spells_tab_status(caster, book)
	return _verdict(checks, wizard)


## The first entry of the Spells tab keeps answering through its own path (no action, not «No implementado»).
func _spells_tab_status(caster: Node, book: Node) -> bool:
	var index := int(book.index_of("laeh"))
	return index >= 0 and caster.arm_status(index) != SpellAction.NOT_IMPLEMENTED


## check(): fount near the point or the wizard, then mana, range and room, cooldown first.
## begin + finish: one tower of the god over the fount; a stolen fount builds nothing.
func _manalith_action(host: Node3D) -> Dictionary:
	var wizard := _wizard(host, Vector3(15.0, 0.0, 0.0))
	var caster := wizard.get_node("Caster")
	var action: StructureAction = caster.action_for("htlm")
	var spell: SpellType = caster.get("spellbook").structure_by_tag("htlm")
	var fount := FOUNT_SCENE.instantiate() as ManafountBody
	host.add_child(fount)
	var towers := Node3D.new()
	towers.name = "Towers"
	host.add_child(towers)
	var spawner := StructureSpawner.new()
	spawner.scenes = [wizard.god_type.structure_for(spell).scene]
	spawner.spawn_path = NodePath("../Towers")
	host.add_child(spawner)
	var checks := {}
	var aim := action.check(wizard, spell, fount.global_position, null, "")
	checks["armed_ok"] = aim.status.is_empty() and aim.point.is_equal_approx(fount.global_position) and aim.target == wizard
	checks["funds_no_mana"] = action.check(wizard, spell, fount.global_position, null, SpellAction.NO_MANA).status == SpellAction.NO_MANA
	checks["funds_cooling"] = action.check(wizard, spell, fount.global_position, null, SpellAction.COOLING).status == SpellAction.COOLING
	var far := action.check(wizard, spell, fount.global_position + Vector3(30.0, 0.0, 0.0), null, "")
	checks["point_far_uses_wizard_fount"] = far.status.is_empty() and far.point.is_equal_approx(fount.global_position)
	wizard.global_position = Vector3(0.0, 0.0, 40.0)
	checks["out_of_range"] = action.check(wizard, spell, fount.global_position, null, "").status == SpellAction.OUT_OF_RANGE
	wizard.global_position = Vector3(0.0, 0.0, 60.0)
	var nofount := action.check(wizard, spell, fount.global_position + Vector3(30.0, 0.0, 0.0), null, SpellAction.COOLING)
	checks["no_fount_wins_over_cooling"] = nofount.status == StructureAction.NO_FOUNT
	wizard.global_position = Vector3(15.0, 0.0, 0.0)
	var blocker := Node3D.new()
	blocker.add_to_group("unit")
	host.add_child(blocker)
	checks["no_room"] = action.check(wizard, spell, fount.global_position, null, "").status == SpellAction.NO_ROOM
	blocker.free()
	aim = action.check(wizard, spell, fount.global_position, null, "")
	action.begin(wizard, spell, aim)
	checks["finish_quiet"] = action.finish(wizard, spell, wizard).is_empty()
	var tower := towers.get_child(0) as CastTower if towers.get_child_count() == 1 else null
	checks["spawned_one"] = tower != null
	checks["spawned_god_model"] = tower != null and tower.type.tag == "jman" and tower.type.role == BuildingType.Role.MANALITH
	checks["spawned_slot"] = tower != null and tower.owner_slot == 1
	checks["spawned_at_fount"] = tower != null and tower.global_position.is_equal_approx(fount.global_position)
	checks["fount_taken"] = tower != null and not fount.is_free()
	checks["occupied_no_fount"] = action.check(wizard, spell, fount.global_position, null, "").status == StructureAction.NO_FOUNT
	checks["finish_twice_builds_once"] = action.finish(wizard, spell, wizard).is_empty() and towers.get_child_count() == 1
	if tower != null:
		towers.remove_child(tower)
		tower.free()
	checks["fount_free_again"] = fount.is_free()
	aim = action.check(wizard, spell, fount.global_position, null, "")
	action.begin(wizard, spell, aim)
	var thief := Node3D.new()
	thief.set_script(preload("res://debug/suite/slot_node.gd"))
	host.add_child(thief)
	fount.occupy(thief.get_path())
	checks["stolen_says_no_fount"] = action.finish(wizard, spell, wizard) == StructureAction.NO_FOUNT and towers.get_child_count() == 0
	fount.release(thief.get_path())
	thief.free()
	aim = action.check(wizard, spell, fount.global_position, null, "")
	action.begin(wizard, spell, aim)
	action.cancel()
	checks["cancel_builds_nothing"] = action.finish(wizard, spell, wizard).is_empty() and towers.get_child_count() == 0
	fount.free()
	spawner.free()
	towers.free()
	return _verdict(checks, wizard)


func _wizard(host: Node3D, at: Vector3) -> WizardBody:
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = 1
	wizard.god_type = GameData.god(GOD)
	host.add_child(wizard)
	wizard.global_position = at
	return wizard


func _verdict(checks: Dictionary, wizard: Node) -> Dictionary:
	var ok := true
	for key in checks:
		if checks[key] is bool and not checks[key]:
			ok = false
			print("action_cases: falla %s" % key)
	checks["ok"] = ok
	wizard.get_parent().remove_child(wizard)
	wizard.free()
	return checks
