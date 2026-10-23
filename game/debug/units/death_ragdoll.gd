extends Node3D

## F6 gallery of the ragdoll death: five models of different shapes stand in a row (Trogg, Taurock, Familiar, Storm Giant,
## Gargoyle). One by one they die on a timer, fall as ragdolls, freeze, and later their corpses dissolve. Then it all starts
## again. Nothing here is a test: the rules suite checks the numbers, this is for looking at the bodies.

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const SOUL_SYSTEM_SCENE := preload("res://scenes/souls/soul_system.tscn")
const RULES := preload("res://data/match_rules.tres")
## Creature tags, left to right: humanoid, quadruped, small, big, winged flier.
const TAGS: PackedStringArray = ["ycro", "raeb", "imaf", "rgos", "sohe"]

## Seconds between one death and the next.
@export_range(0.5, 10.0, 0.5, "suffix:s") var gap_s := 1.5
## Seconds after the last death before the corpses dissolve.
@export_range(1.0, 20.0, 0.5, "suffix:s") var dissolve_after_s := 6.0
## Meters between two bodies.
@export_range(2.0, 20.0, 0.5, "suffix:m") var spacing_m := 8.0


func _ready() -> void:
	add_child(SOUL_SYSTEM_SCENE.instantiate())
	_run.call_deferred()


func _run() -> void:
	while is_inside_tree():
		var units: Array[UnitBody] = []
		for i in TAGS.size():
			units.append(_spawn(TAGS[i], Vector3((i - (TAGS.size() - 1) * 0.5) * spacing_m, 0.0, 0.0)))
		await get_tree().create_timer(1.0).timeout
		for unit in units:
			(unit.find_child("Health", false, false) as Health).damage(99999.0, 1)
			await get_tree().create_timer(gap_s).timeout
		await get_tree().create_timer(dissolve_after_s).timeout
		for unit in units:
			unit.corpse().dissolve(unit)
		await get_tree().create_timer(4.0).timeout


func _spawn(tag: String, at: Vector3) -> UnitBody:
	var type := GameData.creature(tag)
	var unit := UNIT_SCENE.instantiate() as UnitBody
	unit.owner_slot = 2
	unit.creature_tag = tag
	unit.model = str(type.model) if type else ""
	unit.rules = RULES
	unit.idle_aggro = false
	unit.target_groups = PackedStringArray()
	unit.position = at
	add_child(unit)
	return unit
