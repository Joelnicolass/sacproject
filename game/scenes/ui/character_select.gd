extends Control

const _PREVIEW := preload("res://scenes/ui/wizard_preview.gd")

signal confirmed

@export var pick_button: PackedScene

@onready var _wizard_grid: GridContainer = %WizardGrid
@onready var _god_row: HBoxContainer = %GodRow
@onready var _preview: _PREVIEW = %WizardPreview
@onready var _wizard_name: Label = %WizardName
@onready var _wizard_stats: Label = %WizardStats
@onready var _book: Label = %Book

var _wizard_tag: String = ""
var _god: String = ""
var _wizard_group := ButtonGroup.new()
var _god_group := ButtonGroup.new()


func _ready() -> void:
	_wizard_tag = str(SacrificeFlow.pick.get("wizard", ""))
	_god = str(SacrificeFlow.pick.get("god", ""))
	for wizard: WizardType in GameData.wizards():
		_add_button(_wizard_grid, "Wizard_" + wizard.tag, wizard.display_name, _wizard_group, _on_wizard.bind(wizard.tag))
	for god: String in GameData.gods():
		_add_button(_god_row, "God_" + god, "Dios: %s" % god.capitalize(), _god_group, _on_god.bind(god))
	%Play.pressed.connect(_on_play)
	_on_wizard(_wizard_tag)
	_on_god(_god)


func _add_button(parent: Control, unique: String, text: String, group: ButtonGroup, on_pressed: Callable) -> void:
	var button := pick_button.instantiate() as BaseButton
	button.name = unique
	button.set("text", text)
	button.button_group = group
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	button.owner = self
	button.unique_name_in_owner = true


func _on_wizard(tag: String) -> void:
	_wizard_tag = tag
	_press("Wizard_" + tag)
	var wizard: WizardType = GameData.wizard(tag)
	if wizard == null:
		_wizard_name.text = "Faltan los datos del instalador."
		_wizard_stats.text = ""
		return
	_wizard_name.text = wizard.display_name
	_wizard_stats.text = "Vida %d · Maná %d" % [wizard.health, wizard.mana]
	if not MpBoot.is_dedicated_process():
		_preview.show_model(wizard.model)


func _on_god(god: String) -> void:
	_god = god
	_press("God_" + god)
	var book: Dictionary = GameData.book(god)
	var creatures := PackedStringArray()
	for creature: CreatureType in book.get("creatures", []):
		creatures.append(creature.display_name)
	var spells := PackedStringArray()
	for spell: SpellType in book.get("spells", []):
		spells.append(spell.display_name)
	if creatures.is_empty() and spells.is_empty():
		_book.text = "Sin libro: faltan los datos del instalador."
		return
	_book.text = "Criaturas: %s\nHechizos: %s" % [", ".join(creatures), ", ".join(spells)]


func _press(unique: String) -> void:
	var button := get_node_or_null("%" + unique) as BaseButton
	if button:
		button.set_pressed_no_signal(true)


func _on_play() -> void:
	SacrificeFlow.set_pick(_wizard_tag, _god)
	confirmed.emit()
