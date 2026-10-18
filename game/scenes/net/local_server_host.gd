class_name LocalServerHost
extends Node

## RFC-034 034m: «Servidor local». The player's own PC runs ONE dedicated match with the same code as the VPS
## (`MpMatchLauncher` + `MatchTicketGlue` in the dedicated), without a room server: no list, no UPnP, no fallback.
## The ticket has two seats. The host seat's token stays here (the host joins as a normal client with it); the other
## token is the rival's CODE, shown to the host to pass along with the address and the port. The dedicated only keeps
## the sha256 of both (`MpMatchAgent`), so a third player without the code is rejected, and a code opens one seat.
## The rival does not choose his wizard: the host picks it for him (the ticket closes the picks, like in a room).
## This node lives under `root` (it survives `change_scene`) and frees itself when the match ends or the host leaves.
## `--match-args=--flag=1,--other` adds user args to the dedicated (tests only, same hook as the room server).

signal server_ready(address: String, port: int, code: String)
signal server_failed(reason: String)
signal server_closed(result: Dictionary)

const HOST_SLOT := 1
const RIVAL_SLOT := 2
const CODE_BYTES := 8
const MATCH_ID_PREFIX := "local_"
const LOOPBACK := "127.0.0.1"
## The wizard of the rival when the host does not name one.
const DEFAULT_RIVAL_WIZARD := "cwa1"

@onready var launcher: MpMatchLauncher = %Launcher
@onready var rules: SacrificeRoomRules = %Rules

## What the host needs after `server_ready`.
var match_id: String = ""
var port: int = 0
## LAN address to give to the rival (empty if this PC has none; the loopback still works for the host).
var address: String = ""
var rival_code: String = ""
## The host's own credential: it joins `LOOPBACK:port` with it.
var host_token: String = ""
var hosting: bool = false

var _joined: bool = false
var _closed: bool = false
## True while `stop()` kills the dedicated: that is not a failure the screen should show.
var _stopping: bool = false


func _ready() -> void:
	## The game exported has no `--path`; the editor (and the tests) run the same project with it.
	if launcher.base_args.is_empty():
		var args := PackedStringArray(["--headless"])
		if OS.has_feature("editor"):
			args.append_array(["--path", ProjectSettings.globalize_path("res://")])
		launcher.base_args = args
	var extra := MpBoot.user_value("match-args", "")
	if not extra.is_empty():
		launcher.agent_args.append_array(extra.split(",", false))
	launcher.match_listening.connect(_on_listening)
	launcher.match_ended.connect(_on_ended)
	launcher.match_failed.connect(_on_failed)
	MpKit.slot_assigned.connect(_on_slot_assigned)
	set_process(false)


## Launches the dedicated. `host_pick` / `rival_pick` = {wizard, god}; `transport` empty = the one of the config / flag.
## `server_ready` comes when the dedicated listens. ERR_ALREADY_IN_USE if this node already hosts.
func start(host_pick: Dictionary, rival_pick: Dictionary, transport: String = "", options: Dictionary = {}) -> Error:
	if hosting:
		return ERR_ALREADY_IN_USE
	if not transport.is_empty():
		launcher.config.transport = MpTransport.normalize(transport)
	MpKit.transport = launcher.config.transport
	host_token = _new_code()
	rival_code = _new_code()
	match_id = "%s%s" % [MATCH_ID_PREFIX, _new_code().substr(0, 8)]
	var ticket := rules.build_ticket([
		{"slot": HOST_SLOT, "token": host_token, "meta": host_pick},
		{"slot": RIVAL_SLOT, "token": rival_code, "meta": rival_pick},
	], options)
	var err := launcher.launch(match_id, ticket)
	if err != OK:
		return err
	hosting = true
	return OK


## Kills the dedicated (if it runs) and frees this node. Safe to call twice.
func stop(reason: String = "stopped") -> void:
	_stopping = true
	if hosting and launcher.active_ids().has(match_id):
		launcher.abort(match_id, reason)
	_close({})


func _exit_tree() -> void:
	if hosting and not _closed and launcher != null and launcher.active_ids().has(match_id):
		launcher.abort(match_id, "exit")


## While the host plays, leaving the match (menu, closed window) ends the local server.
func _process(_delta: float) -> void:
	if _joined and not MpKit.is_networked():
		stop("host_left")


func _on_listening(listening_id: String, listening_port: int) -> void:
	if listening_id != match_id:
		return
	port = listening_port
	address = MpLan.get_local_ipv4()
	## One line for the logs and the tests: the same three things the screen shows.
	print("servidor local listo direccion=%s puerto=%d transporte=%s codigo=%s" % [
		address, port, launcher.config.transport, rival_code])
	server_ready.emit(address, port, rival_code)


func _on_slot_assigned(slot: int) -> void:
	if hosting and slot == HOST_SLOT:
		_joined = true
		set_process(true)


func _on_ended(ended_id: String, result: Dictionary) -> void:
	if ended_id == match_id:
		print("servidor local resultado %s" % JSON.stringify(result))
		_close(result)


func _on_failed(failed_id: String, reason: String) -> void:
	if failed_id != match_id:
		return
	print("servidor local fallo %s" % reason)
	if not _closed and not _stopping:
		server_failed.emit(reason)
	_close({})


func _close(result: Dictionary) -> void:
	if _closed:
		return
	_closed = true
	hosting = false
	server_closed.emit(result)
	queue_free()


static func _new_code() -> String:
	return Crypto.new().generate_random_bytes(CODE_BYTES).hex_encode()
