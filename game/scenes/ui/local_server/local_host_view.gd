extends Control

## Creates a «Servidor local». The host's pick comes from the menu (`SacrificeFlow.pick`); here he
## chooses the transport (the rival chooses his own wizard and god when he joins). «Crear» launches
## the dedicated on this PC (`LocalServerHost`); when it listens the view shows the address, the
## port, the transport and the rival's code. «Entrar a la partida» joins it as a normal client. The
## host also chooses the mode and the map (the map picker lists the maps that fit the mode) and, for
## each seat but his, a person or an AI (one `seat_row_scene` per seat, rebuilt when the mode
## changes); each seat for a person gets a code.

signal back_requested

## The server node (launcher + the rules of Sacrifice), added to `root` so it outlives this screen.
@export var host_scene: PackedScene
## One row per seat besides the host's (local_seat_row.tscn).
@export var seat_row_scene: PackedScene

var _server: LocalServerHost

@onready var _transport: OptionButton = %HostTransport
@onready var _status: Label = %HostStatus
@onready var _info: Control = %HostInfo


func _ready() -> void:
	%HostHelp.text = tr(LocalServerText.HELP_HOST)
	LocalServerText.fill_transports(_transport)
	%CreateServer.pressed.connect(_on_create)
	%EnterMatch.pressed.connect(_on_enter)
	%CopyInfo.pressed.connect(_on_copy)
	%HostBack.pressed.connect(_on_back)
	(%HostMode as ModePicker).item_selected.connect(_on_mode_selected)
	_build_seats()
	_show_form()


func _show_form() -> void:
	_info.visible = false
	%HostForm.visible = true
	_status.text = ""


func _on_create() -> void:
	if _server != null:
		return
	_server = host_scene.instantiate() as LocalServerHost
	# Under root: `change_scene` frees this screen, not the server.
	get_tree().root.add_child(_server)
	_server.server_ready.connect(_on_server_ready)
	_server.server_failed.connect(_on_server_failed)
	_server.server_closed.connect(_on_server_closed)
	var kind: String = str(_transport.get_item_metadata(_transport.selected))
	# The mode, the map and the land go in the ticket like a room's options.
	var chosen := MatchSetup.new()
	chosen.mode = (%HostMode as ModePicker).selected_mode()
	chosen.map = (%HostMap as MapPicker).selected_map()
	chosen.biome = (%HostBiome as BiomePicker).selected_god()
	chosen.sky_hour = (%HostHour as HourPicker).selected_hour()
	chosen.weather = (%HostWeather as WeatherPicker).selected_weather()
	var err := _server.start(SacrificeFlow.pick, kind, MatchWire.options_of(chosen), ai_seats())
	if err != OK:
		_server.queue_free()
		_server = null
		_status.text = tr(LocalServerText.FAILED_START)
		return
	%HostForm.visible = false
	_status.text = tr(LocalServerText.STARTING)


func _on_server_ready(address: String, port: int, code: String) -> void:
	%HostAddress.text = LocalServerText.address_text(address)
	%HostPort.text = tr(LocalServerText.INFO_PORT) % port
	%HostTransportInfo.text = (
		tr(LocalServerText.INFO_TRANSPORT) % LocalServerText.transport_name(MpKit.transport)
	)
	# One code per seat for a person (`code` is the first one).
	%HostCode.text = (
		LocalServerText.codes_text(_server.codes)
		if _server != null
		else tr(LocalServerText.INFO_CODE) % code
	)
	_info.visible = true
	_status.text = ""


func _on_mode_selected(_index: int) -> void:
	_build_seats()


## One row per seat of the chosen mode besides the host's (seat 1).
func _build_seats() -> void:
	var holder: Control = %HostSeats
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	var mode := (%HostMode as ModePicker).selected_mode()
	if mode == null:
		return
	for slot in range(LocalServerHost.RIVAL_SLOT, mode.seats() + 1):
		var row := seat_row_scene.instantiate() as LocalSeatRow
		holder.add_child(row)
		row.show_slot(slot, mode.team_of(slot))


## {slot: meta} of the seats an AI plays.
func ai_seats() -> Dictionary:
	var out := {}
	for row in %HostSeats.get_children():
		var meta := (row as LocalSeatRow).ai_meta()
		if not meta.is_empty():
			out[(row as LocalSeatRow).slot] = meta
	return out


func _on_server_failed(reason: String) -> void:
	_server = null
	_show_form()
	_status.text = LocalServerText.start_error_text(reason)


func _on_server_closed(_result: Dictionary) -> void:
	_server = null


func _on_enter() -> void:
	if _server == null or not _server.hosting:
		return
	var err: Error = SacrificeFlow.join_local_server(
		LocalServerHost.LOOPBACK, _server.port, _server.host_token
	)
	if err != OK:
		_status.text = tr(LocalServerText.FAILED_START)


func _on_copy() -> void:
	if _server == null:
		return
	var text := (
		tr("UI_LOCAL_HOST_COPY_FORMAT")
		% [
			LocalServerEndpoint.format(_server.address, _server.port),
			LocalServerText.codes_text(_server.codes)
		]
	)
	DisplayServer.clipboard_set(text)
	_status.text = tr(LocalServerText.COPIED)


func _on_back() -> void:
	if _server != null:
		var closing := _server
		_server = null
		closing.stop("host_cancelled")
	_show_form()
	back_requested.emit()
