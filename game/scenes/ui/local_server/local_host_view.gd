extends Control

## RFC-034 034m: create a «Servidor local». The host's pick comes from the menu (`SacrificeFlow.pick`); here he chooses
## the transport (the rival chooses his own wizard and god when he joins). «Crear» launches the dedicated on this PC (`LocalServerHost`); when it listens the
## view shows the address, the port, the transport and the rival's code. «Entrar a la partida» joins it as a normal client.

signal back_requested

## The server node (launcher + the rules of Sacrifice), added to `root` so it outlives this screen.
@export var host_scene: PackedScene

var _server: LocalServerHost

@onready var _transport: OptionButton = %HostTransport
@onready var _status: Label = %HostStatus
@onready var _info: Control = %HostInfo


func _ready() -> void:
	%HostHelp.text = LocalServerText.HELP_HOST
	LocalServerText.fill_transports(_transport)
	%CreateServer.pressed.connect(_on_create)
	%EnterMatch.pressed.connect(_on_enter)
	%CopyInfo.pressed.connect(_on_copy)
	%HostBack.pressed.connect(_on_back)
	_show_form()


func _show_form() -> void:
	_info.visible = false
	%HostForm.visible = true
	_status.text = ""


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
	var err := _server.start(host_pick, kind)
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
