class_name MpLocalServer
extends Node

## A private match on the player's own PC with the same code as the VPS: one dedicated process (your project with
## `--dedicated` and a ticket), no room server. The host joins it like any client; each other seat gets a short
## code. Friends join with "address:port#CODE" in the menu's address field; a third player without a code is turned
## away. Lives under the root (survives scene changes) and frees itself when the match ends or `stop()` is called.
## One per process: start_on() while one runs gives that one back (a second click never breaks the first match).
## `invites()` / `invite_text()` say what friends type; an MpInviteLabel in the HUD shows it during the match.
##   var server := MpLocalServer.start_on(get_tree(), 2)
##   server.server_ready.connect(func(address, port, codes): show(codes))
## Online (MpOnline, through the MpKit issuer): the same match, hosting the issuer's relay room with its token;
## the issuer hands each friend a seat, so the invite is the room's code alone.
## Not: a LAN listen server (MpFlow.host_lan is simpler there), the online lobby (MpRoomServer).

## The match process listens. `address`: this PC on the LAN ("" if none, or through the relay). `codes`: slot -> code for each other seat.
signal server_ready(address: String, port: int, codes: Dictionary)
signal server_failed(reason: String)
signal server_ended(result: Dictionary)

const GROUP := &"mp_local_server"
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 6

## Ports, match times and the matches folder (the defaults work for one match).
@export var config: MpLobbyConfig

var port: int = 0
var codes: Dictionary = {}
## This PC as friends reach it ("" through the relay: the port and the code are enough). Set once it listens.
var address: String = ""
var _launcher: MpMatchLauncher
var _match_id: String = ""
var _host_token: String = ""
var _join_host: bool = true
## The online room's code (MpOnline): what friends type instead of address:port#code.
var online_code: String = ""


## The private server this process runs, or null.
static func running(tree: SceneTree) -> MpLocalServer:
	for node in tree.get_nodes_in_group(GROUP):
		if not node.is_queued_for_deletion():
			return node as MpLocalServer
	return null


## Creates the node under the root and starts a match with `seats` seats (slot 1 is this player). One already
## running is returned as it is (nothing new starts).
static func start_on(tree: SceneTree, seats: int = 2, options: Dictionary = {}, join_host: bool = true, online: Dictionary = {}, ticket: Dictionary = {}) -> MpLocalServer:
	var already := MpLocalServer.running(tree)
	if already:
		return already
	var server := MpLocalServer.new()
	server.name = "MpLocalServer"
	tree.root.add_child(server)
	server.start(seats, options, join_host, online, ticket)
	return server


func _enter_tree() -> void:
	add_to_group(GROUP)


## True once the match process listens (port, address and codes are known).
func is_ready() -> bool:
	return port > 0


## What friends type to join, one per free seat: "192.168.1.5:7801#K7P2QX" (":7801#K7P2QX" through the relay);
## online, the room's code.
func invites() -> PackedStringArray:
	var out := PackedStringArray()
	if not is_ready():
		return out
	if not online_code.is_empty():
		out.append(online_code)
		return out
	var slots := codes.keys()
	slots.sort()
	for slot in slots:
		out.append("%s:%d#%s" % [address, port, codes[slot]])
	return out


func invite_text() -> String:
	return ", ".join(invites())


## `online` (MpOnline): {code, room, token, url, host_seat, seats}: the issuer's room code, relay room and host
## token (they go in the match's ticket) and the admission tickets the issuer hands out (one per seat but slot 1).
## `ticket`: the game's match ticket (world, mode, options, seed, picks…, and `seats: [{slot, meta}]` with each seat's
## meta, the host's in slot 1), merged by merge_ticket(): the kit only adds the seats' tokens and the relay block.
func start(seats: int = 2, options: Dictionary = {}, join_host: bool = true, online: Dictionary = {}, ticket: Dictionary = {}) -> Error:
	_join_host = join_host
	online_code = str(online.get("code", ""))
	_forget_dead_servers()
	if config == null:
		config = MpLobbyConfig.new()
		## The match talks like this process does: the game's MpNetConfig (transport, relay, TLS) when there is a
		## flow with one, what MpKit runs otherwise.
		var flow := MpFlow.find_in_tree(self)
		if flow and flow.net_config:
			flow.net_config.fill_lobby_config(config)
		config.transport = MpKit.transport
		if config.relay_url.is_empty():
			config.relay_url = MpTransport.relay_url
		if config.relay_room.is_empty():
			config.relay_room = MpTransport.relay_room
	## An online room is always hosted through the relay (its match hosts the issuer's room).
	if online.has("room"):
		config.transport = MpTransport.RELAY
		if not str(online.get("url", "")).is_empty():
			config.relay_url = str(online["url"])
	_launcher = MpMatchLauncher.new()
	_launcher.name = "Launcher"
	_launcher.config = config
	## A folder per process: another private server on this PC never takes this match for a leftover.
	_launcher.matches_subdir = "local_%d" % OS.get_process_id()
	_launcher.base_args = PackedStringArray(["--headless"])
	if not OS.has_feature("template"):
		_launcher.base_args.append_array(PackedStringArray(["--path", ProjectSettings.globalize_path("res://")]))
	var extra := MpBoot.user_value("match-args", "")
	if not extra.is_empty():
		_launcher.agent_args.append_array(extra.split(",", false))
	add_child(_launcher)
	_launcher.match_listening.connect(_on_listening)
	_launcher.match_failed.connect(func(_id: String, reason: String) -> void: _fail(reason))
	_launcher.match_ended.connect(_on_ended)
	var tokens := {}
	var given: Array = Array(online.get("seats", PackedStringArray()))
	_host_token = str(online.get("host_seat", "")) if online.has("host_seat") else MpMatchFiles.new_token()
	tokens[1] = _host_token
	for slot in range(2, seats + 1):
		var code := str(given[slot - 2]) if slot - 2 < given.size() else MpLocalServer.new_code()
		codes[slot] = code
		tokens[slot] = code
	_match_id = "local_%d" % (Time.get_unix_time_from_system() as int)
	var relay := {}
	if online.has("room"):
		relay = {"room": online["room"], "token": online.get("token", ""), "url": online.get("url", "")}
	var err := _launcher.launch(_match_id, MpLocalServer.merge_ticket(ticket, options, tokens, relay))
	if err != OK:
		_fail("launch_%s" % error_string(err))
	return err


## Kills the match process and frees this node.
func stop() -> void:
	if _launcher and not _match_id.is_empty():
		_launcher.abort(_match_id, "stopped")
	queue_free()


## The match ticket: the game's `ticket` as it is (world, mode, options, seed, picks…), `options` when given, one seat
## per `tokens` entry (slot -> admission token) with the game's meta for that slot, and the `relay` block (online).
## The kit's keys win: a game's own seat tokens or relay block are replaced.
static func merge_ticket(ticket: Dictionary, options: Dictionary, tokens: Dictionary, relay: Dictionary = {}) -> Dictionary:
	var out := ticket.duplicate(true)
	var meta := {}
	for row in out.get("seats", []):
		if row is Dictionary and (row as Dictionary).get("meta") is Dictionary:
			meta[int((row as Dictionary).get("slot", 0))] = (row as Dictionary)["meta"]
	if not options.is_empty() or not out.has("options"):
		out["options"] = options if not options.is_empty() else out.get("options", {})
	var slots := tokens.keys()
	slots.sort()
	var rows: Array = []
	for slot in slots:
		rows.append({"slot": int(slot), "token": str(tokens[slot]), "meta": meta.get(int(slot), {})})
	out["seats"] = rows
	out.erase("relay")
	if not relay.is_empty():
		out["relay"] = relay
	return out


## A seat code: an admission ticket, so from the system's secure random (online it crosses the internet).
static func new_code() -> String:
	var out := ""
	for byte in Crypto.new().generate_random_bytes(CODE_LENGTH):
		out += CODE_CHARS[byte % CODE_CHARS.length()]
	return out


## The match's seats: slot -> connected (from its state.json; {} before it wrote one).
func connected_slots() -> Dictionary:
	if _launcher == null or _match_id.is_empty():
		return {}
	var out := {}
	var slots: Variant = _launcher.state_of(_match_id).get("slots", {})
	if slots is Dictionary:
		for slot in (slots as Dictionary).keys():
			out[int(slot)] = bool(slots[slot])
	return out


func _on_listening(_id: String, p_port: int) -> void:
	port = p_port
	## Through the relay friends need no address of this PC, only the port (it picks the room) and a code.
	address = "" if MpTransport.normalize(config.transport) == MpTransport.RELAY else MpLan.get_local_ipv4()
	if address.is_empty() and MpTransport.normalize(config.transport) != MpTransport.RELAY:
		address = "127.0.0.1"
	server_ready.emit(address, port, codes.duplicate())
	if _join_host:
		var flow := MpFlow.find_in_tree(self)
		if flow:
			flow.join_endpoint("127.0.0.1", port, _host_token)


func _on_ended(_id: String, result: Dictionary) -> void:
	server_ended.emit(result)
	queue_free()


func _fail(reason: String) -> void:
	push_warning("MpLocalServer: %s" % reason)
	server_failed.emit(reason)
	queue_free()


## Folders of private servers whose process is gone (a crash, a kill): their matches stopped with them.
func _forget_dead_servers() -> void:
	var root := (config.with_cli_overrides() if config else MpLobbyConfig.new().with_cli_overrides()).matches_root
	var dir := ProjectSettings.globalize_path(root)
	if not DirAccess.dir_exists_absolute(dir):
		return
	for name in DirAccess.get_directories_at(dir):
		if not name.begins_with("local_") or not name.trim_prefix("local_").is_valid_int():
			continue
		var pid := int(name.trim_prefix("local_"))
		if pid != OS.get_process_id() and not MpProcessRunner.pid_alive(pid):
			MpMatchFiles.remove_dir(root.path_join(name))
