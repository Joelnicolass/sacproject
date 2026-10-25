extends Node

## 055c3 test bed of Weapons: five creatures whose weapons were changed ONLY in the editor, with no code. `Plain` is a Trogg as it comes;
## `Added` is a Trogg with a ranged_weapon.tscn dropped under its Weapons (its `attack_type` is the Earthfling's shot); `Removed` is an
## Earthfling whose Ranged weapon has `enabled` off; `Changed` is a Silverback whose Ranged weapon fires the Earthfling's shot instead of
## its breath. `Foe` stands 20 m in front of `Added`. Open the scene, click a Weapons node, drag or delete its children, press F6.
## Headless it runs the checks, prints `WEAPON_SWAP PASS/FAIL {json}` and quits. The rules suite (debug/suite/weapon_cases.gd) calls run_checks().
## Checks: the priority is the order of the children, a weapon with nothing to fire or turned off is skipped, a weapon dropped in is used
## at once, the weapon's own ability wins over the creature's, the shot look follows the ability, `struck` reaches the container, and the
## active ability comes from the AbilityType.

const TAG := "WEAPON_SWAP "
const ABILITIES_DIR := "res://data/catalog/abilities/"
## The active abilities that have an effect scene (the old catalog had these 19 entries).
const EFFECTS := 19

@export var plain: UnitBody
@export var added: UnitBody
@export var removed: UnitBody
@export var changed: UnitBody
@export var foe: UnitBody


func _ready() -> void:
	if get_tree().current_scene != self:
		return
	var report := await run_checks()
	print(TAG + ("PASS " if bool(report["ok"]) else "FAIL ") + JSON.stringify(report))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if bool(report["ok"]) else 1)


## Runs every check and returns {ok, checks}. The bodies stand still: the checks ask the weapons, they do not fight.
func run_checks() -> Dictionary:
	for body: UnitBody in [plain, added, removed, changed, foe]:
		body.set_physics_process(false)
	var checks := {}
	checks["plain_melee_only"] = _names(plain.weapons.ordered()) == ["Melee"]
	checks["plain_ranged_node_is_inert"] = plain.weapons.ranged != null and not plain.weapons.ranged.armed()
	checks["added_in_child_order"] = _names(added.weapons.ordered()) == ["Melee", "Spit"]
	checks["added_is_the_ranged_one"] = added.weapons.ranged != null and added.weapons.ranged.name == "Spit" and added.weapons.ranged.attack.tag == "ekba"
	checks["added_look_is_its_shot"] = added.weapons.ranged.look != null and added.weapons.ranged.look.tag == "ekba"
	checks["added_shoots_the_far_foe"] = added.weapons.ranged.wants(foe) and not added.weapons.melee.wants(foe)
	checks["removed_melee_only"] = _names(removed.weapons.ordered()) == ["Melee"] and removed.weapons.ranged == null
	checks["removed_type_keeps_its_data"] = removed.type.ranged_attack != null
	checks["changed_own_ability_wins"] = changed.weapons.ranged.attack.tag == "ekba" and changed.type.ranged_attack.tag != "ekba"
	checks["changed_look_follows"] = changed.weapons.ranged.look.tag == "ekba"
	checks["changed_ranged_before_melee"] = _names(changed.weapons.ordered()) == ["Ranged", "Melee"]
	var heard := []
	added.weapons.struck.connect(func(_target: Node3D, amount: float, _chance: float, _roll: float) -> void: heard.append(amount))
	added.weapons.melee.struck.emit(foe, 5.0, 0.5, 0.25)
	checks["struck_reaches_the_container"] = heard == [5.0]
	checks["ability_effect_from_the_type"] = removed.abilities.slot.effect is Rockform and plain.abilities.slot.effect == null
	checks["ability_effects_on_the_types"] = _effects() == EFFECTS
	var look := ShotLook.make("kcfa")
	checks["shot_look_is_a_scene"] = look.ground_mark != null and look.tag == "kcfa"
	look.free()
	var ok := true
	for key in checks:
		ok = ok and bool(checks[key])
	return {"ok": ok, "checks": checks}


## How many ability types carry an effect scene.
static func _effects() -> int:
	var found := 0
	for file in DirAccess.get_files_at(ABILITIES_DIR):
		if file.ends_with(".tres"):
			var ability := load(ABILITIES_DIR + file) as AbilityType
			if ability != null and ability.effect != null:
				found += 1
	return found


static func _names(weapons: Array[Weapon]) -> Array:
	var names := []
	for weapon: Weapon in weapons:
		names.append(String(weapon.name))
	return names
