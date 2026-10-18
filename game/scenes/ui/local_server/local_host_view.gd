extends Control

## RFC-034 034m: create a «Servidor local». The host's pick comes from the menu (`SacrificeFlow.pick`); here he chooses
## the god of the rival and the transport. «Crear» launches the dedicated on this PC (`LocalServerHost`); when it listens the
## view shows the address, the port, the transport and the rival's code. «Entrar a la partida» joins it as a normal client.

signal back_requested

## The server node (launcher + the rules of Sacrifice), added to `root` so it outlives this screen.
@export var host_scene: PackedScene

var _server: LocalServerHost

@onready var _rival_god: OptionButton = %RivalGod
@onready var _transport: OptionButton = %HostTransport
@onready var _status: Label = %HostStatus
@onready var _info: Control = %HostInfo


func _ready() -> void:
	%HostHelp.text = LocalServerText.HELP_HOST
	_fill_gods()
	LocalServerText.fill_transports(_transport)
	%CreateServer.pressed.connect(_on_create)
	%EnterMatch.pressed.connect(_on_enter)
	%CopyInfo.pressed.connect(_on_copy)
	%HostBack.pressed.connect(_on_back)
	_show_form()


func _fill_gods() -> void:
	_rival_god.clear()
	_rival_god.add_item(LocalServerText.RANDOM_GOD)
	_rival_god.set_item_metadata(0, "")
	for god in GameData.gods():
		_rival_god.add_item(LocalServerText.GOD_PREFIX % god.capitalize())
		_rival_god.set_item_metadata(_rival_god.item_count - 1, god)
	_rival_god.select(0)


func _show_form() -> void:
	_info.visible = false
	%HostForm.visible = true
	_status.text = ""


func _rival_pick() -> Dictionary:
	var god: String = str(_rival_god.get_item_metadata(_rival_god.selected))
	if god.is_empty():
		var gods := GameData.gods()
		god = str(gods[randi() % gods.size()])
	return {"wizard": LocalServerHost.DEFAULT_RIVAL_WIZARD, "god": god}


func _on_create() -> void:
	if _server != null:
		return
	_server = host_scene.instantiate() as LocalServerHost
	## Under root: `change_scene` frees this screen, not the server.
	get_tree().root.add_child(_server)
	_server.server_ready.connect(_on_server_ready)
	_server.server_failed.connect(_on_server_failed)
	_server.server_closed.connect(_on_server_closed)
	var host_pick := {"wizard": str(SacrificeFlow.pick.get("wizard", "")), "god": str(SacrificeFlow.pick.get("god", ""))}
	var kind: String = str(_transport.get_item_metadata(_transport.selected))
	var err := _server.start(host_pick, _rival_pick(), kind)
	if err != OK:
		_server.queue_free()
		_server = null
		_status.text = LocalServerText.FAILED_START
		return
	%HostForm.visible = false
	_status.text = LocalServerText.STARTING


func _on_server_ready(address: String, port: int, code: String) -> void:
	%HostAddress.text = LocalServerText.address_text(address)
	%HostPort.text = LocalServerText.INFO_PORT % port
	%HostTransportInfo.text = LocalServerText.INFO_TRANSPORT % LocalServerText.transport_name(MpKit.transport)
	%HostCode.text = LocalServerText.INFO_CODE % code
	_info.visible = true
	_status.text = ""


func _on_server_failed(reason: String) -> void:
	_server = null
	_show_form()
	_status.text = LocalServerText.start_error_text(reason)


func _on_server_closed(_result: Dictionary) -> void:
	_server = null


func _on_enter() -> void:
	if _server == null or not _server.hosting:
		return
	var err := SacrificeFlow.join_local_server(LocalServerHost.LOOPBACK, _server.port, _server.host_token)
	if err != OK:
		_status.text = LocalServerText.FAILED_START


func _on_copy() -> void:
	if _server == null:
		return
	var text := "%s  código: %s" % [LocalServerEndpoint.format(_server.address, _server.port), _server.rival_code]
	DisplayServer.clipboard_set(text)
	_status.text = LocalServerText.COPIED


func _on_back() -> void:
	if _server != null:
		var closing := _server
		_server = null
		closing.stop("host_cancelled")
	_show_form()
	back_requested.emit()
