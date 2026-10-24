extends Node3D

## F6 gallery of the wizards' death: the 15 wizards stand in three rows. One by one they die on a timer, fall as ragdolls
## (WizardDeathLook), their corpse fades and the ghost rises where they lay. The wizards of slot 1 have an altar (they rise as
## ghosts); the wizards of slot 2 have none (their corpse just fades away). Then it all starts again. Nothing here is a test:
## the rules suite checks the numbers, this is for looking at the bodies.

const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const ALTAR_SCENE := preload("res://scenes/map/props/altar.tscn")
const WIZARDS_DIR := "res://data/catalog/wizards/"

## Seconds between one death and the next.
@export_range(0.5, 10.0, 0.5, "suffix:s") var gap_s := 1.0
## Seconds the last ghost is shown before the row is cleared.
@export_range(1.0, 30.0, 0.5, "suffix:s") var linger_s := 10.0
## Wizards per row and meters between two.
@export_range(1, 15) var columns := 5
@export_range(2.0, 20.0, 0.5, "suffix:m") var spacing_m := 4.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	while is_inside_tree():
		var altar := ALTAR_SCENE.instantiate()
		altar.set("owner_slot", 1)
		altar.position = Vector3(0.0, 0.0, -12.0)
		add_child(altar)
		var wizards := _spawn_all()
		await get_tree().create_timer(1.0).timeout
		for wizard in wizards:
			(wizard.get_node("Health") as Health).damage(99999.0, 3)
			await get_tree().create_timer(gap_s).timeout
		await get_tree().create_timer(linger_s).timeout
		for wizard in wizards:
			wizard.queue_free()
		altar.queue_free()
		await get_tree().create_timer(0.5).timeout


func _spawn_all() -> Array[WizardBody]:
	var wizards: Array[WizardBody] = []
	var tags := PackedStringArray()
	for file in DirAccess.get_files_at(WIZARDS_DIR):
		if file.ends_with(".tres"):
			tags.append(file.get_basename())
	tags.sort()
	for i in tags.size():
		var type := GameData.wizard(tags[i])
		var wizard := WIZARD_SCENE.instantiate() as WizardBody
		wizard.owner_slot = 1 + i % 2
		wizard.wizard_tag = tags[i]
		wizard.model = str(type.model)
		var col := i % columns
		var row := i / columns
		wizard.position = Vector3((col - (columns - 1) * 0.5) * spacing_m, 0.0, row * spacing_m)
		add_child(wizard)
		wizards.append(wizard)
	return wizards
