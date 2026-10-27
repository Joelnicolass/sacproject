extends Control

## Join a friend's «Servidor local». Visible outside debug builds too (it is the only door to a direct address).
## The rival types `address:port`, the code the host gave him and the transport. The code is the ticket of his seat.
## Ref: RFC-034 034m.

signal back_requested

## Used when the text has no `:port`. Same number as `match_port_min` of data/net/lobby_config_local_server.tres.
@export var default_port: int = 7710

## The character selector of the menu, shown over this view while the rival chooses (the same scene the room screens use).
@export var character_select_scene: PackedScene

var _joining: bool = false
var _character_select: Control

@onready var _transport: OptionButton = %JoinTransport
@onready var _status: Label = %JoinStatus


func _ready() -> void:
	%JoinHelp.text = tr(LocalServerText.HELP_JOIN)
	LocalServerText.fill_transports(_transport)
	%JoinPick.pressed.connect(_on_pick_pressed)
	_show_choice()
	%JoinServer.pressed.connect(_on_join)
	%JoinAddress.text_submitted.connect(func(_text: String) -> void: _on_join())
	%JoinCode.text_submitted.connect(func(_text: String) -> void: _on_join())
	%JoinBack.pressed.connect(back_requested.emit)
	MpKit.admission_rejected.connect(_on_rejected)
	MpKit.join_failed.connect(_on_join_failed)
	MpKit.slot_assigned.connect(_on_slot_assigned)


func _show_choice() -> void:
	var chosen: WizardPick = SacrificeFlow.pick
	%JoinChoice.text = tr(LocalServerText.PICK_CHOICE) % [chosen.wizard.display_name, chosen.god.display_name]


func _on_pick_pressed() -> void:
	if _character_select == null:
		_character_select = character_select_scene.instantiate() as Control
		_character_select.set("confirm_text", tr(LocalServerText.PICK_CONFIRM))
		_character_select.connect("confirmed", _on_pick_confirmed)
		%JoinPickHolder.add_child(_character_select)
	%JoinPickOverlay.visible = true


func _on_pick_confirmed() -> void:
	%JoinPickOverlay.visible = false
	if _character_select != null:
		_character_select.queue_free()
		_character_select = null
	_show_choice()


func _on_join() -> void:
	if _joining:
		return
	var target := LocalServerEndpoint.parse(%JoinAddress.text, default_port)
	if not bool(target["ok"]):
		_status.text = tr(LocalServerText.BAD_ENDPOINT)
		return
	var code := LocalServerEndpoint.clean_code(%JoinCode.text)
	if code.is_empty():
		_status.text = tr(LocalServerText.BAD_CODE)
		return
	MpKit.transport = str(_transport.get_item_metadata(_transport.selected))
	var err: Error = SacrificeFlow.join_local_server(str(target["host"]), int(target["port"]), code)
	if err != OK:
		_status.text = tr(LocalServerText.BAD_ENDPOINT)
		return
	_set_joining(true)
	_status.text = tr(LocalServerText.CONNECTING) % LocalServerEndpoint.format(str(target["host"]), int(target["port"]))


func _set_joining(joining: bool) -> void:
	_joining = joining
	%JoinServer.disabled = joining


func _on_rejected(reason: String) -> void:
	_set_joining(false)
	_status.text = LocalServerText.rejection_text(reason)


func _on_join_failed() -> void:
	_set_joining(false)
	_status.text = LocalServerText.rejection_text("dropped")


func _on_slot_assigned(_slot: int) -> void:
	_status.text = tr(LocalServerText.WAITING_HOST)
