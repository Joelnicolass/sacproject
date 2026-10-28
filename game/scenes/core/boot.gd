extends Control

## The main menu the game starts in. With `--room-server` it hands over to the room server.

const ROOM_SERVER_SCENE := "res://scenes/net/room_server.tscn"

## The product rules: %AiLevel starts at their wizard_level.
@export var rules: MatchRules
## The player's Options → Jugabilidad (data/ui/gameplay_prefs.tres); the matches made here take it.
@export var gameplay_prefs: GameplayPrefs

@onready var ip: LineEdit = %Ip
@onready var status: Label = %Status
@onready var character_select: Control = %CharacterSelect
@onready var column: Control = %Column


func _ready() -> void:
	# The exported binary has no scene argument; `--room-server` makes its main scene (this one)
	# hand over to the room server, so the same binary is the room server and, with `--dedicated`,
	# every match process. Only with `SacrificeFlow.room_server_enabled` (inspector of
	# sacrifice_flow.tscn).
	if MpBoot.role() == "room-server":
		if not SacrificeFlow.room_server_enabled:
			push_error(
				"--room-server: the room server is off (room_server_enabled in sacrifice_flow.tscn)"
			)
			get_tree().quit(1)
			return
		get_tree().change_scene_to_file.call_deferred(ROOM_SERVER_SCENE)
		return
	SacrificeFlow.status_changed.connect(_on_status)
	%Solo.pressed.connect(_on_solo)
	%VsAi.pressed.connect(_on_vs_ai)
	_fill_ai_levels()
	%Join.pressed.connect(_on_join)
	# «Salas online»: rooms the players host through the issuer (scenes/ui/online/; the issuer is in
	# data/net/online_config.tres), or the room-server lobby when
	# `SacrificeFlow.room_server_enabled` is on. The field for an IP and «Unirse» (direct to a
	# dedicated or a LAN host) stay only in debug builds.
	%Online.pressed.connect(_on_online)
	# «Servidor local» is a door of its own (create on this PC / join an address), visible in every
	# build.
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
	var chosen: WizardPick = SacrificeFlow.pick
	%Choice.text = tr("UI_BOOT_CHOICE") % [chosen.wizard.display_name, chosen.god.display_name]
	character_select.visible = false
	column.visible = true


func _on_solo() -> void:
	SacrificeFlow.play_solo(_setup(0))


## «Contra la IA»: solo with the AI in every other seat of the mode; the god of %AiGod, or drawn
## with «Aleatorio».
func _on_vs_ai() -> void:
	var level: OptionButton = %AiLevel
	SacrificeFlow.play_vs_ai(
		(%AiGod as AiGodPicker).selected_god(), _setup(int(level.get_item_metadata(level.selected)))
	)


## The match this boot creates: Options → Jugabilidad and `level` (0 = the rules'). Without prefs,
## only the level.
func _setup(level: int) -> MatchSetup:
	var setup: MatchSetup
	if gameplay_prefs:
		setup = gameplay_prefs.to_setup(level)
	else:
		push_warning("Boot: gameplay_prefs is missing; the match uses the rules and the flags.")
		setup = MatchSetup.new()
		setup.level = level
	# The map of %MapPicker and the mode of %ModePicker (in «Contra la IA» the AI takes every other
	# seat); the flow plays them.
	setup.map = (%MapPicker as MapPicker).selected_map()
	setup.mode = (%ModePicker as ModePicker).selected_mode()
	# The land of %BiomePicker (null = drawn from the seed; the authority of the match draws it and
	# sends it to the clients).
	setup.biome = (%BiomePicker as BiomePicker).selected_god()
	return setup


## The level of both wizards in «Contra la IA», 1-9; default = the product rules (9).
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
	var screen := (
		SacrificeFlow.LOBBY_SCENE
		if SacrificeFlow.room_server_enabled
		else SacrificeFlow.ONLINE_SCENE
	)
	get_tree().change_scene_to_file(screen)


func _on_local_server() -> void:
	get_tree().change_scene_to_file(SacrificeFlow.LOCAL_SERVER_SCENE)


func _on_join() -> void:
	SacrificeFlow.join_lan(ip.text)


func _on_status(text: String) -> void:
	status.text = text
