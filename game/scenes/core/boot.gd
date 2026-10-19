extends Control

## Product rules: %AiLevel starts at their wizard_level (RFC-030 030d).
@export var rules: MatchRules
## RFC-031 031d (F143): the player's Options → Jugabilidad (data/ui/gameplay_prefs.tres); the matches made here take it.
@export var gameplay_prefs: GameplayPrefs

const ROOM_SERVER_SCENE := "res://scenes/net/room_server.tscn"

@onready var ip: LineEdit = %Ip
@onready var status: Label = %Status
@onready var character_select: Control = %CharacterSelect
@onready var column: Control = %Column

func _ready() -> void:
	## RFC-034 034g: the exported binary has no scene argument; `--room-server` makes its main scene (this one) hand over to the
	## room server, so the same binary is the room server and, with `--dedicated`, every match process.
	if MpBoot.role() == "room-server":
		get_tree().change_scene_to_file.call_deferred(ROOM_SERVER_SCENE)
		return
	SacrificeFlow.status_changed.connect(_on_status)
	%Solo.pressed.connect(_on_solo)
	%VsAi.pressed.connect(_on_vs_ai)
	_fill_ai_levels()
	%Join.pressed.connect(_on_join)
	## RFC-034 034f: the player goes online through the rooms (the server is in data/net/lobby_endpoint.tres). The field
	## for an IP and «Unirse» (direct to a dedicated or a LAN host) stay only in debug builds.
	%Online.pressed.connect(_on_online)
	## RFC-034 034m: «Servidor local» is a door of its own (create on this PC / join an address), visible in every build.
	%LocalServer.pressed.connect(_on_local_server)
	ip.visible = OS.is_debug_build()
	%Join.visible = OS.is_debug_build()
	%Back.pressed.connect(_show_select)
	%Options.pressed.connect(%OptionsMenu.open)
	character_select.confirmed.connect(_on_confirmed)
	_show_select()

func _show_select() -> void:
	column.visible = false
	character_select.visible = true

func _on_confirmed() -> void:
	var wizard: WizardType = GameData.wizard(str(SacrificeFlow.pick.get("wizard", "")))
	var wizard_name := wizard.display_name if wizard else str(SacrificeFlow.pick.get("model", ""))
	%Choice.text = tr("UI_BOOT_CHOICE") % [wizard_name, str(SacrificeFlow.pick.get("god", "")).capitalize()]
	character_select.visible = false
	column.visible = true

func _on_solo() -> void:
	SacrificeFlow.play_solo(_setup(0))

## «Contra la IA» (RFC-024 024f): solo with the AI in every other seat of the mode; the god of %AiGod, or drawn with «Aleatorio».
func _on_vs_ai() -> void:
	var level: OptionButton = %AiLevel
	SacrificeFlow.play_vs_ai((%AiGod as AiGodPicker).selected_god(), _setup(int(level.get_item_metadata(level.selected))))

## The match this boot creates: Options → Jugabilidad and `level` (0 = the rules'). Without prefs, only the level.
func _setup(level: int) -> MatchSetup:
	var setup: MatchSetup
	if gameplay_prefs:
		setup = gameplay_prefs.to_setup(level)
	else:
		push_warning("Boot: falta gameplay_prefs; la partida usa las reglas y los flags.")
		setup = MatchSetup.new()
		setup.level = level
	## RFC-049 049a: the map of %MapPicker (SacrificeFlow plays it).
	setup.map_tag = (%MapPicker as MapPicker).selected_tag()
	## RFC-049 049h: and the mode of %ModePicker (in «Contra la IA» the AI takes every other seat).
	setup.mode_tag = (%ModePicker as ModePicker).selected_tag()
	return setup

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

func _on_online() -> void:
	get_tree().change_scene_to_file(SacrificeFlow.LOBBY_SCENE)

func _on_local_server() -> void:
	get_tree().change_scene_to_file(SacrificeFlow.LOCAL_SERVER_SCENE)

func _on_join() -> void:
	SacrificeFlow.join_lan(ip.text)

func _on_status(text: String) -> void:
	status.text = text
