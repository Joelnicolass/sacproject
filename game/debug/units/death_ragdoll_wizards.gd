extends Node3D

## F6 gallery of the wizards' death: the 15 wizards stand in three rows. One by one they die on a timer, fall as ragdolls
## (WizardDeathLook), their corpse fades and the ghost rises where they lay. The wizards of slot 1 have an altar (they rise as
## ghosts); the wizards of slot 2 have none (their corpse just fades away). Then it all starts again. Nothing here is a test:
## the rules suite checks the numbers, this is for looking at the bodies.
## To look at one: `-- --focus=<model tag or index>` follows that wizard from a 3/4 view and only it dies, `--only=<tag>`
## spawns just that wizard, `--kill-delay=<s>` is when it dies; `--out=<dir> --shots=<n> --every=<s>` saves PNGs from its
## death and quits (see GalleryCapture).

const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const ALTAR_SCENE := preload("res://scenes/map/props/altar.tscn")
const WIZARDS_DIR := "res://data/catalog/wizards/"

## Seconds between one death and the next.
@export_range(0.5, 10.0, 0.5, "suffix:s") var gap_s := 1.0
## Seconds the last ghost is shown before the row is cleared.
@export_range(1.0, 30.0, 0.5, "suffix:s") var linger_s := 10.0
## Seconds from the start to the first death (`--kill-delay`).
@export_range(0.0, 30.0, 0.5, "suffix:s") var kill_delay_s := 1.0
## Wizards per row and meters between two.
@export_range(1, 15) var columns := 5
@export_range(2.0, 20.0, 0.5, "suffix:m") var spacing_m := 4.0
## Follows and kills only this wizard (model tag or index in the sorted list); empty = all die in turn (`--focus`).
@export var focus := ""
## Spawns only this wizard (model tag; `--only`).
@export var only := ""
## The camera follower and PNG saver.
@export var capture: GalleryCapture


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tags := _tags()
	var only_tag := GalleryCapture.cli("only", only)
	var focus_tag := _resolve(GalleryCapture.cli("focus", focus), tags)
	if focus_tag.is_empty():
		focus_tag = only_tag
	var delay_s := float(GalleryCapture.cli("kill-delay", str(kill_delay_s)))
	while is_inside_tree():
		var altar := ALTAR_SCENE.instantiate()
		altar.set("owner_slot", 1)
		altar.position = Vector3(0.0, 0.0, -12.0)
		add_child(altar)
		var wizards := _spawn(tags, only_tag)
		var focused := _find(wizards, focus_tag)
		capture.subject = focused
		await get_tree().create_timer(delay_s).timeout
		if focused != null:
			(focused.get_node("Health") as Health).damage(99999.0, 3)
			capture.begin_capture()
		else:
			for wizard in wizards:
				(wizard.get_node("Health") as Health).damage(99999.0, 3)
				await get_tree().create_timer(gap_s).timeout
		await get_tree().create_timer(linger_s).timeout
		for wizard in wizards:
			wizard.queue_free()
		altar.queue_free()
		await get_tree().create_timer(0.5).timeout


func _tags() -> PackedStringArray:
	var tags := PackedStringArray()
	for file in DirAccess.get_files_at(WIZARDS_DIR):
		if file.ends_with(".tres"):
			tags.append(file.get_basename())
	tags.sort()
	return tags


## A tag as is, or the tag at that index of the sorted list; "" when it names nothing.
func _resolve(text: String, tags: PackedStringArray) -> String:
	if text.is_valid_int():
		return tags[int(text)] if int(text) >= 0 and int(text) < tags.size() else ""
	return text if tags.has(text) else ""


func _find(wizards: Array[WizardBody], tag: String) -> WizardBody:
	for wizard in wizards:
		if wizard.wizard_tag == tag:
			return wizard
	return null


## The grid of wizards (slot and place follow the index in the sorted list); `only_tag` keeps one, at the center.
func _spawn(tags: PackedStringArray, only_tag: String) -> Array[WizardBody]:
	var wizards: Array[WizardBody] = []
	for i in tags.size():
		if not only_tag.is_empty() and tags[i] != only_tag:
			continue
		var type := GameData.wizard(tags[i])
		var wizard := WIZARD_SCENE.instantiate() as WizardBody
		wizard.owner_slot = 1 + i % 2
		wizard.wizard_tag = tags[i]
		wizard.model = str(type.model)
		var col := i % columns
		var row := i / columns
		wizard.position = Vector3((col - (columns - 1) * 0.5) * spacing_m, 0.0, row * spacing_m)
		if not only_tag.is_empty():
			wizard.position = Vector3.ZERO
		add_child(wizard)
		wizards.append(wizard)
	return wizards
