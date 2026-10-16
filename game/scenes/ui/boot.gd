extends Control

## Product rules: %AiLevel starts at their wizard_level (RFC-030 030d).
@export var rules: MatchRules

@onready var ip: LineEdit = %Ip
@onready var status: Label = %Status
@onready var character_select: Control = %CharacterSelect
@onready var column: Control = %Column

func _ready() -> void:
	SacrificeFlow.status_changed.connect(_on_status)
	%Solo.pressed.connect(_on_solo)
	%VsAi.pressed.connect(_on_vs_ai)
	_fill_ai_gods()
	_fill_ai_levels()
	%Join.pressed.connect(_on_join)
	%Back.pressed.connect(_show_select)
	character_select.confirmed.connect(_on_confirmed)
	_show_select()

func _show_select() -> void:
	column.visible = false
	character_select.visible = true

func _on_confirmed() -> void:
	var wizard: WizardType = GameData.wizard(str(SacrificeFlow.pick.get("wizard", "")))
	var wizard_name := wizard.display_name if wizard else str(SacrificeFlow.pick.get("model", ""))
	%Choice.text = "%s · Dios: %s" % [wizard_name, str(SacrificeFlow.pick.get("god", "")).capitalize()]
	character_select.visible = false
	column.visible = true

func _on_solo() -> void:
	SacrificeFlow.play_solo()

## «Contra la IA» (RFC-024 024f): solo with the AI in slot 2; the god of %AiGod, or drawn with «Aleatorio».
func _on_vs_ai() -> void:
	var picker: OptionButton = %AiGod
	var level: OptionButton = %AiLevel
	SacrificeFlow.play_vs_ai(StringName(str(picker.get_item_metadata(picker.selected))), int(level.get_item_metadata(level.selected)))

func _fill_ai_gods() -> void:
	var picker: OptionButton = %AiGod
	picker.clear()
	picker.add_item("Rival: Aleatorio")
	picker.set_item_metadata(0, "")
	for god in GameData.gods():
		picker.add_item("Rival: %s" % god.capitalize())
		picker.set_item_metadata(picker.item_count - 1, god)
	picker.select(0)

## RFC-030 030d (F115): the level of both wizards in «Contra la IA», 1-9; default = the product rules (9).
func _fill_ai_levels() -> void:
	var picker: OptionButton = %AiLevel
	picker.clear()
	var initial := rules.wizard_level if rules else 9
	for level in range(1, 10):
		picker.add_item(str(level))
		picker.set_item_metadata(picker.item_count - 1, level)
		if level == initial:
			picker.select(picker.item_count - 1)

func _on_join() -> void:
	SacrificeFlow.join_lan(ip.text)

func _on_status(text: String) -> void:
	status.text = text
