extends Node3D

## F6 gallery of the ragdoll death: five models of different shapes stand in a row (Trogg, Taurock, Familiar, Storm Giant,
## Gargoyle). One by one they die on a timer, fall as ragdolls, freeze, and later their corpses dissolve. Then it all starts
## again. Nothing here is a test: the rules suite checks the numbers, this is for looking at the bodies.
## To look at one: `-- --focus=<tag or index>` follows that creature from a 3/4 view and only it dies, `--only=<tag>` spawns
## just that one, `--kill-delay=<s>` is when it dies; `--out=<dir> --shots=<n> --every=<s>` saves PNGs from its death and
## quits (see GalleryCapture).

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
## Seconds from the start to the first death (`--kill-delay`).
@export_range(0.0, 30.0, 0.5, "suffix:s") var kill_delay_s := 1.0
## Follows and kills only this creature (tag or index in `TAGS`); empty = all die in turn (`--focus`).
@export var focus := ""
## Spawns only this creature (tag; `--only`).
@export var only := ""
## The camera follower and PNG saver.
@export var capture: GalleryCapture


func _ready() -> void:
	add_child(SOUL_SYSTEM_SCENE.instantiate())
	_run.call_deferred()


func _run() -> void:
	var only_tag := GalleryCapture.cli("only", only)
	var focus_tag := _resolve(GalleryCapture.cli("focus", focus))
	if focus_tag.is_empty():
		focus_tag = only_tag
	var delay_s := float(GalleryCapture.cli("kill-delay", str(kill_delay_s)))
	while is_inside_tree():
		var units: Array[UnitBody] = []
		var focused: UnitBody
		for i in TAGS.size():
			if not only_tag.is_empty() and TAGS[i] != only_tag:
				continue
			var at := Vector3((i - (TAGS.size() - 1) * 0.5) * spacing_m, 0.0, 0.0)
			units.append(_spawn(TAGS[i], Vector3.ZERO if not only_tag.is_empty() else at))
			if TAGS[i] == focus_tag:
				focused = units[-1]
		capture.subject = focused
		await get_tree().create_timer(delay_s).timeout
		if focused != null:
			_kill(focused)
			capture.begin_capture()
		else:
			for unit in units:
				_kill(unit)
				await get_tree().create_timer(gap_s).timeout
		await get_tree().create_timer(dissolve_after_s).timeout
		for unit in units:
			unit.corpse().dissolve(unit)
		await get_tree().create_timer(4.0).timeout


func _kill(unit: UnitBody) -> void:
	(unit.find_child("Health", false, false) as Health).damage(99999.0, 1)


## A tag as is, or the tag at that index of `TAGS`; "" when it names nothing.
func _resolve(text: String) -> String:
	if text.is_valid_int():
		return TAGS[int(text)] if int(text) >= 0 and int(text) < TAGS.size() else ""
	return text if TAGS.has(text) else ""


func _spawn(tag: String, at: Vector3) -> UnitBody:
	var type := GameData.creature(tag)
	var unit := UNIT_SCENE.instantiate() as UnitBody
	unit.owner_slot = 2
	unit.type = GameData.creature(tag)
	unit.model = type.model_id() if type else ""
	unit.rules = RULES
	unit.idle_aggro = false
	unit.target_groups = PackedStringArray()
	unit.position = at
	add_child(unit)
	return unit
