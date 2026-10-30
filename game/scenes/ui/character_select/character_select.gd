extends Control

signal confirmed

const _PREVIEW := preload("res://scenes/ui/character_select/wizard_preview.gd")

@export var pick_button: PackedScene
## The confirm button says «Jugar» in the menu; the room screen says «Elegir».
@export var confirm_text: String = "UI_CHARACTER_SELECT_PLAY"

var _wizard: WizardType
var _god: GodType
var _wizard_group := ButtonGroup.new()
var _god_group := ButtonGroup.new()

@onready var _wizard_grid: GridContainer = %WizardGrid
@onready var _god_row: HBoxContainer = %GodRow
@onready var _preview: _PREVIEW = %WizardPreview
@onready var _wizard_name: Label = %WizardName
@onready var _wizard_stats: Label = %WizardStats
@onready var _book: Label = %Book


func _ready() -> void:
	var current: WizardPick = SacrificeFlow.pick
	_wizard = current.wizard
	_god = current.god
	var catalog := GameCatalog.shared()
	# The button names (`Wizard_<id>`, `God_<id>`) carry the network id, so the flows of the agent
	# keep working.
	for wizard in catalog.offered_wizards():
		_add_button(
			_wizard_grid,
			"Wizard_" + wizard.id(),
			wizard.display_name,
			_wizard_group,
			_on_wizard.bind(wizard)
		)
	for god in catalog.offered_gods():
		_add_button(
			_god_row,
			"God_" + god.id(),
			tr("UI_CHARACTER_SELECT_GOD_BUTTON") % god.display_name,
			_god_group,
			_on_god.bind(god)
		)
	%Play.text = tr(confirm_text)
	%Play.pressed.connect(_on_play)
	_on_wizard(_wizard)
	_on_god(_god)


func _add_button(
	parent: Control, unique: String, text: String, group: ButtonGroup, on_pressed: Callable
) -> void:
	var button := pick_button.instantiate() as BaseButton
	button.name = unique
	button.set("text", text)
	button.button_group = group
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	button.owner = self
	button.unique_name_in_owner = true


func _on_wizard(wizard: WizardType) -> void:
	_wizard = wizard
	if wizard == null:
		_wizard_name.text = tr("UI_CHARACTER_SELECT_NO_DATA")
		_wizard_stats.text = ""
		return
	_press("Wizard_" + wizard.id())
	_wizard_name.text = wizard.display_name
	_wizard_stats.text = tr("UI_CHARACTER_SELECT_WIZARD_STATS") % [wizard.health, wizard.mana]
	if not MpBoot.is_dedicated_process():
		_preview.show_wizard(wizard)


func _on_god(god: GodType) -> void:
	_god = god
	if god == null:
		_book.text = tr("UI_CHARACTER_SELECT_NO_BOOK")
		return
	_press("God_" + god.id())
	var book: Dictionary = god.book.up_to(1) if god.book != null else {}
	var creatures := PackedStringArray()
	for creature: CreatureType in book.get("creatures", []):
		creatures.append(creature.display_name)
	var spells := PackedStringArray()
	for spell: SpellType in book.get("spells", []):
		spells.append(spell.display_name)
	if creatures.is_empty() and spells.is_empty():
		_book.text = tr("UI_CHARACTER_SELECT_NO_BOOK")
		return
	_book.text = tr("UI_CHARACTER_SELECT_BOOK") % [", ".join(creatures), ", ".join(spells)]


func _press(unique: String) -> void:
	var button := get_node_or_null("%" + unique) as BaseButton
	if button:
		button.set_pressed_no_signal(true)


func _on_play() -> void:
	var chosen := WizardPick.new()
	chosen.wizard = _wizard
	chosen.god = _god
	SacrificeFlow.set_pick(chosen)
	confirmed.emit()
