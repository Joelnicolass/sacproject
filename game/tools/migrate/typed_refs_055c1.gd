extends SceneTree

## One-shot, with Godot: checks the result of tools/migrate/typed_refs_055c1.py. The Python script wrote the typed references without
## opening Godot (the three ability slots and the passives of the 72 creatures, the typed components, the owners of the bodies) and a
## snapshot of how every creature read before (tools/migrate/055c1_typed_refs_parity.json). This one loads all of it and prints the
## parity report: every slot points at the same ability the old tag named, `abilities()` lists them in the old order, the scenes of
## the components load with their references, and no script or scene still names the old fields. It changes nothing.
##   godot --headless --path . --script res://tools/migrate/typed_refs_055c1.gd
## Prints `TYPED REFS <checked> checks` and `MIGRATE 055c1-b PASS|FAIL`. It ALWAYS quits: it asks for exit 1 first, so a script
## error half way still ends the run, and only a clean run changes it to 0. Both files go away when 055c1 closes.

const SNAPSHOT := "res://tools/migrate/055c1_typed_refs_parity.json"
const CREATURES := "res://data/catalog/creatures/"
const WIZARDS := "res://data/catalog/wizards/"
const PEASANTS := ["zepa", "zepd", "zepe", "zepf", "saep"]
## The old text that must be gone from the product, the benches and the tools that still run.
const GONE := ["ability_tags", "ranged_attack_tag", "active_ability_tag", "passive_on_damage", "passive_abilities", "is_peasant_tag",
		"WIDTH_SCALE", "source_ability_tag", "shield_tag", "heal_spell", "freeze_spell = \"", "passive_tag"]
const SCAN_ROOTS := ["res://scenes", "res://debug", "res://agent", "res://tools/bake"]

var _checked := 0
var _failures := PackedStringArray()


func _initialize() -> void:
	quit(1)
	if not FileAccess.file_exists(SNAPSHOT):
		print("MIGRATE 055c1-b FAIL falta %s (¿ya se cerró la migración?)" % SNAPSHOT)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT))
	if not parsed is Dictionary:
		print("MIGRATE 055c1-b FAIL el snapshot no es un diccionario")
		return
	var snapshot: Dictionary = parsed
	var known: Array = snapshot.get("abilities", [])
	var creatures: Dictionary = snapshot.get("creatures", {})
	for tag: String in creatures:
		_check_creature(tag, creatures[tag], known)
	var wizards: Dictionary = snapshot.get("wizards", {})
	for tag: String in wizards:
		var entry: Dictionary = wizards[tag]
		var wizard := load(WIZARDS + str(entry["file"])) as WizardType
		_expect(wizard != null and wizard.tag == tag, "wizards/%s: no carga como WizardType con el mismo tag" % tag)
	_check_passive_files(snapshot.get("passives", {}))
	_check_scenes()
	_check_text()
	for line in _failures:
		print("TYPED REFS FAIL %s" % line)
	print("TYPED REFS %d checks, %d creatures" % [_checked, creatures.size()])
	var ok := _failures.is_empty() and creatures.size() == 72
	print("MIGRATE 055c1-b %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _expect(condition: bool, message: String) -> void:
	_checked += 1
	if not condition:
		_failures.append(message)


func _tag_of(ability: AbilityType) -> String:
	return ability.tag if ability != null else ""


## One creature: the three slots, the order of `abilities()`, `is_ranged()`, the passives, the two scalars.
func _check_creature(tag: String, old: Dictionary, known: Array) -> void:
	var type := load(CREATURES + str(old["file"])) as CreatureType
	if type == null:
		_failures.append("creatures/%s: no carga como CreatureType" % str(old["file"]))
		return
	_expect(type.tag == tag, "creatures/%s: el tag cambió (%s)" % [str(old["file"]), type.tag])
	var ranged := str(old["ranged_attack_tag"])
	var active := str(old["active_ability_tag"])
	var damage := str(old["passive_on_damage"])
	# A slot whose tag is in no table of the original (the Ghost's and Zyzyx's `tsg@`) stays empty, as it was a null.
	_expect(_tag_of(type.ranged_attack) == (ranged if known.has(ranged) else ""), "%s: ranged_attack %s y era %s" % [tag, _tag_of(type.ranged_attack), ranged])
	_expect(_tag_of(type.active_ability) == (active if known.has(active) else ""), "%s: active_ability %s y era %s" % [tag, _tag_of(type.active_ability), active])
	_expect(_tag_of(type.on_damage) == (damage if known.has(damage) else ""), "%s: on_damage %s y era %s" % [tag, _tag_of(type.on_damage), damage])
	var listed := PackedStringArray()
	for slot in type.abilities():
		listed.append(slot.tag)
	var expected := PackedStringArray()
	for old_tag: String in old["ability_tags"]:
		if known.has(old_tag):
			expected.append(old_tag)
	_expect(listed == expected, "%s: abilities() %s y ability_tags era %s" % [tag, listed, expected])
	_expect(type.is_ranged() == bool(old["is_ranged"]), "%s: is_ranged() %s y era %s" % [tag, type.is_ranged(), old["is_ranged"]])
	var passives := PackedStringArray()
	for passive in type.passives:
		if passive is DeathCloudType:
			passives.append(_tag_of((passive as DeathCloudType).ability))
		elif passive is OnHitPassiveType and (passive as OnHitPassiveType).spell != null:
			passives.append((passive as OnHitPassiveType).spell.tag)
		else:
			passives.append("?")
	var old_passives := PackedStringArray()
	for old_tag: String in old["passive_abilities"]:
		old_passives.append(old_tag)
	_expect(passives == old_passives, "%s: passives %s y passive_abilities era %s" % [tag, passives, old_passives])
	_expect(is_equal_approx(type.melee_width_scale, 1.3 if tag == "nmuh" else 1.0), "%s: melee_width_scale %s" % [tag, type.melee_width_scale])
	_expect(type.peasant == PEASANTS.has(tag), "%s: peasant %s" % [tag, type.peasant])


## The passive files: the typed field names the same tag the old `tag` line did.
func _check_passive_files(old: Dictionary) -> void:
	for path: String in old:
		var resource := load(path)
		var want := str(old[path])
		var got := ""
		if resource is DeathCloudType:
			got = _tag_of((resource as DeathCloudType).ability)
		elif resource is OnHitPassiveType:
			got = (resource as OnHitPassiveType).spell.tag if (resource as OnHitPassiveType).spell != null else ""
		elif resource is DamagePassiveType:
			got = _tag_of((resource as DamagePassiveType).ability)
		elif resource is TargetPolicy:
			got = _tag_of((resource as TargetPolicy).attack)
		_expect(got == want, "%s: nombra %s y era %s" % [path, got, want])


## The scenes of the components load, build, and carry their references.
func _check_scenes() -> void:
	var unit := _build("res://scenes/units/unit.tscn")
	if unit != null:
		var support := unit.get_node_or_null("ManaSupport") as UnitManaSupport
		_expect(support != null and _tag_of(support.source) == "hmba", "unit.tscn: ManaSupport.source no es hmba")
		var shield := unit.get_node_or_null("FireShield") as FireShield
		_expect(shield != null and _tag_of(shield.passive) == "rifl" and shield.fire != null and shield.fire.tag == "mrff", "unit.tscn: FireShield sin rifl/mrff")
		var charge := unit.get_node_or_null("LightningCharge") as LightningCharge
		_expect(charge != null and _tag_of(charge.passive) == "gcil", "unit.tscn: LightningCharge sin gcil")
		var damage := unit.get_node_or_null("DamagePassive") as DamagePassive
		var damage_tags := PackedStringArray()
		if damage != null:
			for entry in damage.types:
				damage_tags.append(_tag_of(entry.ability))
		_expect(damage_tags == PackedStringArray(["korq", "ahtf"]), "unit.tscn: DamagePassive.types %s" % damage_tags)
		var picker := unit.get_node_or_null("TargetPicker") as TargetPicker
		_expect(picker != null and picker.policies.size() == 1 and _tag_of(picker.policies[0].attack) == "slba", "unit.tscn: TargetPicker sin la política de slba")
		_expect(unit.get_node_or_null("MeleeOnHit") is MeleeOnHit and unit.get_node_or_null("DeathCloudSpawner") is DeathCloudSpawner, "unit.tscn: faltan MeleeOnHit o DeathCloudSpawner")
		unit.free()
	var protector := _build("res://scenes/units/abilities/protector.tscn") as Protector
	_expect(protector != null and _tag_of(protector.life_shield) == "hsba", "protector.tscn: life_shield no es hsba")
	_free(protector)
	var lightning := _build("res://scenes/units/abilities/call_lightning.tscn") as CallLightning
	_expect(lightning != null and lightning.spell != null and lightning.spell.tag == "ntil", "call_lightning.tscn: spell no es ntil")
	_free(lightning)
	var devour := _build("res://scenes/units/abilities/devour.tscn") as DevourAbility
	_expect(devour != null and devour.healing != null and devour.healing.tag == "wobr", "devour.tscn: healing no es wobr")
	_free(devour)
	var breath := _build("res://scenes/units/abilities/breath_of_life.tscn") as BreathOfLife
	_expect(breath != null and _tag_of(breath.default_ability) == "filb", "breath_of_life.tscn: default_ability no es filb")
	_free(breath)
	var halo := _build("res://scenes/units/abilities/halo_of_earth.tscn") as HaloOfEarth
	_expect(halo != null and _tag_of(halo.default_ability) == "HRba", "halo_of_earth.tscn: default_ability no es HRba")
	_free(halo)
	var frost := _build("res://scenes/units/attacks/frost_wave.tscn")
	var touch := frost.get_node_or_null("FreezeTouch") as FreezeTouch if frost != null else null
	_expect(touch != null and touch.freeze != null and touch.freeze.tag == "zerf", "frost_wave.tscn: FreezeTouch.freeze no es zerf")
	_free(frost)
	var doctor := _build("res://scenes/sacrifice/doctor.tscn") as DoctorBody
	_expect(doctor != null and doctor.type != null and doctor.type.tag == "dcas", "doctor.tscn: type no es dcas")
	_free(doctor)
	var wizard := _build("res://scenes/wizards/wizard_body.tscn") as WizardBody
	_expect(wizard != null and wizard.wizard_type != null and wizard.wizard_type.tag == "cwa0" and wizard.wizard_tag == "cwa0", "wizard_body.tscn: wizard_type no es cwa0 o wizard_tag no lo sigue")
	_free(wizard)


func _build(path: String) -> Node:
	var scene := load(path) as PackedScene
	_expect(scene != null, "%s: no carga" % path)
	var node: Node = scene.instantiate() if scene != null else null
	_expect(scene == null or node != null, "%s: no se pudo instanciar" % path)
	return node


func _free(node: Node) -> void:
	if node != null:
		node.free()


## No script or scene still names the removed fields (the tool itself and the snapshot are not scanned).
func _check_text() -> void:
	for root: String in SCAN_ROOTS:
		_scan(root)


func _scan(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_scan(folder.path_join(sub))
	for file in dir.get_files():
		if not (file.ends_with(".gd") or file.ends_with(".tscn")):
			continue
		var text := FileAccess.get_file_as_string(folder.path_join(file))
		for word: String in GONE:
			if text.contains(word):
				_failures.append("%s: todavía dice «%s»" % [folder.path_join(file), word])
		_checked += 1
