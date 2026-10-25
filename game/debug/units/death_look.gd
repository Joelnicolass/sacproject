extends Node3D

## RFC-055 055a-2: look at the death by eye (F6). Three bodies stand in a row: a ground unit, a flier and a placeholder
## body with no model (so no death clip). One by one they die on a timer; later their corpses dissolve and the first one
## is revived by hand, so the fades can be seen both ways. Nothing here is a test: the rules suite checks the numbers.

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const SOUL_SYSTEM_SCENE := preload("res://scenes/souls/soul_system.tscn")
const RULES := preload("res://data/match_rules.tres")

## Seconds between one death and the next.
@export_range(0.5, 10.0, 0.5, "suffix:s") var gap_s := 2.0
## Seconds after the last death before the corpses dissolve.
@export_range(1.0, 20.0, 0.5, "suffix:s") var dissolve_after_s := 6.0

var _units: Array[UnitBody] = []


func _ready() -> void:
	add_child(SOUL_SYSTEM_SCENE.instantiate())
	_units.append(_spawn("nmuh", true, Vector3(-3.0, 0.0, 0.0)))
	_units.append(_spawn("sohe", true, Vector3(0.0, 0.0, 0.0)))
	_units.append(_spawn("nmuh", false, Vector3(3.0, 0.0, 0.0)))
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	for unit in _units:
		(unit.find_child("Health", false, false) as Health).damage(99999.0, 1)
		await get_tree().create_timer(gap_s).timeout
	await get_tree().create_timer(dissolve_after_s).timeout
	for unit in _units:
		unit.corpse().dissolve(unit)


func _spawn(tag: String, with_model: bool, at: Vector3) -> UnitBody:
	var type := GameData.creature(tag)
	var unit := UNIT_SCENE.instantiate() as UnitBody
	unit.owner_slot = 2
	unit.type = GameData.creature(tag)
	unit.model = str(type.model) if type and with_model else ""
	unit.rules = RULES
	unit.idle_aggro = false
	unit.target_groups = PackedStringArray()
	unit.position = at
	add_child(unit)
	return unit
