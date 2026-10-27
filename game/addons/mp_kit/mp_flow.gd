class_name MpFlow
extends Node

## Optional session flow. Not gameplay: scenes, host/join/1P, when the world loads.
## Add as autoload (after MpKit) or instance in the boot scene.
## Override `snapshot_for_joiner()` in a subclass for game state.
## Every path that hosts (Host LAN, a dedicated by hand, a room's dedicated) arms the match's start gate (MpKit.gate): free seats
## are open until the match starts; after it only a seat that left comes back (rejoin), unless late_join. A dedicated by hand
## serves one match after another: when its match is over and the server is empty, it loads a fresh world and opens the
## seats again. Knobs: the "Match start" group.

signal status_changed(text: String)
signal world_loading
## The world load moved on (MpWorldLoader): `ratio` 0..1, `phase` FILES/WORLD while loading, READY done, IDLE dropped.
signal world_load_progressed(ratio: float, phase: MpWorldLoader.Phase)
## The world is in and ready (it said so with report_world_loaded, or `world_reports_loaded` is off).
signal world_loaded
signal world_changed(id: StringName)
## The server ended the match (MpMatch.finish): every peer gets the result.
signal match_finished(result: Dictionary)

## When a "Dedicated Server" export started without `--dedicated` enters the world: at once (the default), with the
## first client, or never by itself. Nothing else reads it: a listen host (Host LAN) and a process started with
## `--dedicated` always enter at once.
enum StartWhen {
	LISTEN_IMMEDIATE, ## enter the world at once (the default; the name is older than the other two)
	DEDICATED_FIRST_CLIENT, ## a "Dedicated Server" export without --dedicated: enter when the first client joins
	MANUAL, ## never load the world by itself; glue calls start_match() / goto_world()
}

## Every network setting in one .tres (transport, port, players, TLS). Set = it replaces max_players,
## custom_channels and the port here. Empty = the fields below and the flags, as before.
@export var net_config: MpNetConfig
## Your game in one .tres (MpGame: network + scenes). Set = it is the net_config, and it fills every scene path
## below that is empty. The easy way: set only this.
@export var game: MpGame
## Scene with your MpRoomServer. `--room-server` opens it: one exported binary is client, room server and match.
@export_file("*.tscn") var room_server_path: String = ""
## The online lobby screen. A match joined with join_match() comes back here when it ends or the server is lost.
@export_file("*.tscn") var lobby_path: String = ""
@export var boot_scene: PackedScene
@export var world_scene: PackedScene
@export_file("*.tscn") var boot_path: String = ""
@export_file("*.tscn") var world_path: String = ""
## Several maps: fill this and call `select_world(&"2d")`. Empty = single world_path/world_scene.
@export var worlds: Array[MpWorldRef] = []
@export var world_id: StringName = &""
@export var max_players: int = 4
@export var host_slot: int = 1
@export var room_name: String = "MpKit"
@export var advertise_lan: bool = true
@export var custom_channels: PackedStringArray = PackedStringArray()
@export var start_when: StartWhen = StartWhen.LISTEN_IMMEDIATE
## On: the world says when it is ready (report_world_loaded); only then is this peer loaded at the gate (solo too). Off: its scene is in.
## `--world-reports-loaded` turns it on from the command line.
@export var world_reports_loaded := false

@export var host_fail_status: String = "Could not host (port busy?)"
@export var join_fail_status: String = "Could not join"
@export var bad_ip_status: String = "Invalid address (an IP or a name, optionally :port)"
@export var joining_status: String = "Connecting to %s…"
@export var server_lost_status: String = "Lost the server"
@export var dedicated_status: String = "Dedicated on port %d"
@export var cannot_host_status: String = "This build cannot host (web): join a server"

@export_group("Online (issuer)")
## Shown while the issuer opens the room (host_online) or finds a seat (join_online).
@export var online_working_status: String = "Asking the server…"
## Shown once the room is up: `%s` is the code friends type.
@export var online_ready_status: String = "Room %s: friends join with this code"
## The issuer's refusals and errors, by its word; `%s` in version_too_old is the oldest version allowed and in
## version_mismatch the host's. Any other word goes through online_error_status.
@export var online_texts: Dictionary = {
	"room_full": "That room is full",
	"room_starting": "That room is still starting: try again",
	"no_such_room": "No room with that code",
	"version_mismatch": "That room runs version %s of the game: update to join",
	"version_too_old": "Update the game (version %s or newer)",
	"too_many_rooms": "You already host a room: close it first",
	"rate_limited": "Too many tries: wait a minute",
	"banned": "This player cannot play online",
	"network": "Cannot reach the online server",
	"no_issuer": "This game has no online server (MpNetConfig.issuer_url)",
}
@export var online_error_status: String = "Online error (%s)"
## Shown on a client while the host sends nothing (its game froze, its tab is hidden in a mobile browser, its link
## stalls). After host_silent_timeout_s the client gives up: server_lost_status.
@export var host_silent_status: String = "Waiting for the host…"
@export var host_silent_timeout_s: float = 30.0

@export_group("Match start")
## Seconds a seat that dropped keeps its place (`--rejoin-grace-s=`). A room's match takes its MpLobbyConfig instead.
@export var rejoin_grace_s: float = 60.0
## Seconds after the first player sat that the match waits for the rest to load (`--load-timeout-s=`); then it starts with
## whoever loaded. The HUD says it waits (MpWaitingLabel). A room's match takes its MpLobbyConfig instead.
@export var load_timeout_s: float = 15.0
## Clients that must load before the match starts, in Host LAN and a dedicated by hand; 0 = every seat, or whoever loaded
## once load_timeout_s passed (`--start-seats=`). A listen host may start sooner (MpStartButton, `Mp.gate().start_now()`).
@export var start_seats: int = 0
## After the start a newcomer still takes a free seat (`--late-join`). Off: only a seat that left comes back. Not for a room's
## match (its ticket names every seat).
@export var late_join: bool = false
## The clients' world pauses too while the match waits for seats.
@export var pause_clients: bool = true
## Shown on a client the server turned away because the match already started.
@export var match_started_status: String = "The match already started"
## Shown for any other reason (`%s` = the reason code).
@export var rejected_status: String = "The server turned this player away (%s)"
@export_group("")

const PORT_MIN := 1
const PORT_MAX := 65535

## Group every flow joins, so a lobby finds one dropped in its own scene.
const GROUP := &"mp_flow"

var match_running: bool = false

var _match_from_lobby: bool = false
## A dedicated by hand: it loads the world at once (not with its first client), and its match ended (MpMatch.finish).
var _dedicated_at_once: bool = false
var _open_match_over: bool = false
var _tree: SceneTree
## Where this flow came from (its scene, or an autoload): two flows of different origins is a setup mistake.
var _origin: String = ""

var _lan: MpLanBeacon
var _loader := MpWorldLoader.new()


func _init() -> void:
	_loader.name = "WorldLoader"
	add_child(_loader, false, Node.INTERNAL_MODE_BACK)
	_loader.progressed.connect(world_load_progressed.emit)
	_loader.finished.connect(_on_world_loaded)


static func find_in_tree(from: Node) -> MpFlow:
	if from == null or from.get_tree() == null:
		return null
	for child in from.get_tree().root.get_children():
		if child is MpFlow:
			return child as MpFlow
	## A flow dropped in the boot scene, before it moves itself under the root.
	return from.get_tree().get_first_node_in_group(GROUP) as MpFlow


func _enter_tree() -> void:
	add_to_group(GROUP)
	_tree = get_tree()
	_use_game()
	if _origin.is_empty():
		_origin = owner.scene_file_path if owner else "autoload %s" % name


func _ready() -> void:
	## Dropped in a scene instead of being an autoload: live under the root so a scene change keeps it.
	## A second one (the boot scene loaded again) gives way to the first.
	if get_parent() != get_tree().root:
		_adopt.call_deferred()
		return
	## `--no-flow`: tools and probes that use MpKit directly; the flow never reacts to it.
	if MpBoot.user_flag("no-flow"):
		return
	_pick_world_from_args()
	if net_config:
		max_players = net_config.effective_max_players()
		custom_channels = net_config.custom_channels
		advertise_lan = advertise_lan and net_config.lan_discovery
		net_config.apply(host_slot)
	else:
		var port := int(MpBoot.user_value("mp-port", "7777"))
		MpKit.configure(port, max_players, host_slot, custom_channels)
	## A browser can neither host nor advertise on the LAN.
	if not MpNetConfig.can_host():
		advertise_lan = false
	for link in _kit_links():
		(link[0] as Signal).connect(link[1])
	_apply_load_mode()
	## A dedicated started by the room server: the ticket says who may join (unless the game armed its own agent),
	## and how many seats the match has, before the port opens.
	if not MpBoot.user_value("match-ticket-file", "").is_empty():
		var seats := MpBoot.ticket_seats()
		if seats > MpKit.max_players:
			max_players = seats
			MpKit.configure(MpKit.port, seats, host_slot, custom_channels)
		_ensure_match_agent.call_deferred()
	var role := MpBoot.role()
	if role == "room-server" and not room_server_path.is_empty():
		get_tree().change_scene_to_file.call_deferred(room_server_path)
		return
	if role == "server":
		if _host_dedicated():
			_start_dedicated_world()
			_quit_if_refused()
		return
	if role == "listen":
		if host_lan() != OK:
			get_tree().quit(1)
		return
	if role == "client1" or role == "client2":
		if join_lan(MpBoot.user_value("join-ip", "127.0.0.1")) != OK:
			get_tree().quit(1)
		return
	if MpBoot.is_dedicated_process() and _host_dedicated() and start_when == StartWhen.LISTEN_IMMEDIATE:
		_start_dedicated_world()


## Opens the dedicated's port and arms its gate. False (and the process quits) when it cannot.
func _host_dedicated() -> bool:
	var err := MpKit.host_dedicated()
	if err != OK:
		push_error("MpKit.host_dedicated failed: %s" % err)
		get_tree().quit(1)
		return false
	_arm_gate()
	_set_status(dedicated_status % MpKit.port)
	return true


func _start_dedicated_world() -> void:
	match_running = true
	_dedicated_at_once = true
	call_deferred("goto_world")


## The MpGame fills what was left empty; anything set by hand on this node wins.
func _use_game() -> void:
	if game == null:
		return
	if net_config == null:
		net_config = game
	if boot_path.is_empty() and boot_scene == null:
		boot_path = game.boot_scene
	if world_path.is_empty() and world_scene == null and worlds.is_empty():
		world_path = game.world_scene
	if lobby_path.is_empty():
		lobby_path = game.lobby_scene
	if room_server_path.is_empty():
		room_server_path = game.rooms_scene


## A dedicated through the relay whose port's room has another live host: say so and stop, as a busy port would.
## A match of a room server reports it to its launcher instead (MpMatchAgent), which picks another port.
func _quit_if_refused() -> void:
	if MpTransport.normalize(MpKit.transport) != MpTransport.RELAY or not MpBoot.user_value("match-ticket-file", "").is_empty():
		return
	var end := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < end and not MpKit.is_listening():
		if MpKit.listen_refused():
			push_error("MpFlow: port %d is in use on the relay (another server of this game hosts that room)" % MpKit.port)
			get_tree().quit(1)
			return
		await get_tree().process_frame


## Moves this flow under the root. Works even when a scene change already took the boot scene out of the tree
## (Godot removes the outgoing scene at once and frees it at the end of the frame).
func _adopt() -> void:
	if _tree == null or get_parent() == null or get_parent() == _tree.root:
		return
	var root := _tree.root
	for child in root.get_children():
		if child is MpFlow and child != self:
			## The same boot scene loaded again: its flow gives way quietly. A flow of another origin (an autoload and
			## a node in the boot, two boot scenes) is a setup mistake: say so, its inspector settings are ignored.
			if (child as MpFlow)._origin != _origin:
				push_warning("MpFlow: two flows (%s and %s); the one already running stays, this one's settings are ignored" % [(child as MpFlow)._origin, _origin])
			queue_free()
			return
	get_parent().remove_child(self)
	## It no longer belongs to the boot scene: under the root it is nobody's child scene.
	owner = null
	request_ready()
	root.add_child(self)


func _exit_tree() -> void:
	if MpKit.gate == null:
		return
	for link in _kit_links():
		if (link[0] as Signal).is_connected(link[1]):
			(link[0] as Signal).disconnect(link[1])


## What the flow listens to on MpKit and its gate: [signal, handler].
func _kit_links() -> Array:
	return [[MpKit.load_world, goto_world], [MpKit.peer_joined, _on_peer_joined], [MpKit.join_failed, _on_join_failed],
		[MpKit.server_lost, _on_server_lost], [MpKit.snapshot_received, _on_flow_snapshot], [MpKit.session_ended, _on_session_ended],
		[MpKit.admission_rejected, _on_admission_rejected], [MpKit.peer_left, _on_peer_left],
		[MpKit.session_ended_sent, _on_session_ended_sent], [MpKit.gate.all_gone, _on_all_gone],
		[MpKit.host_silent, _on_host_silent], [MpKit.host_back, _on_host_back]]


func play_solo() -> void:
	_stop_lan()
	MpKit.leave()
	_arm_gate()
	match_running = true
	goto_world()


func host_lan() -> Error:
	if not MpNetConfig.can_host():
		_set_status(cannot_host_status)
		return ERR_UNAVAILABLE
	return host_here()


## This game hosts the match and plays it (a listen server) on whatever MpKit.transport is: Host LAN; with an issuer
## room pending (MpTransport.use_relay_room) it hosts that room through the relay: an online room in a browser (MpOnline). Unlike host_lan(), a browser may: the relay listens for it.
func host_here() -> Error:
	var err := MpKit.host()
	if err != OK:
		_set_status(host_fail_status)
		return err
	_arm_gate()
	_begin_match()
	return OK


## Opens an online room this player hosts (MpOnline through the issuer): `players` seats (this one counts), shown in
## the issuer's list unless `listed` is off (then friends need the code). The status says the code once it is up.
## `ticket`: the game's match ticket (world, mode, options, seed, picks…, `seats: [{slot, meta}]`), as for a private
## match: a desktop's match process gets it; in a browser this game is the match and reads MpOnline.ticket.
func host_online(players: int = 0, online_room_name: String = "", listed: bool = true, ticket: Dictionary = {}) -> MpOnline:
	if not MpIssuer.is_configured():
		_set_status(online_text("no_issuer"))
		return null
	_set_status(online_working_status)
	var online := MpOnline.start_on(get_tree(), players if players > 1 else max(2, MpKit.max_players),
		online_room_name if not online_room_name.is_empty() else room_name, listed, ticket)
	if not online.room_ready.is_connected(_on_online_ready):
		online.room_ready.connect(_on_online_ready)
		online.failed.connect(func(reason: String) -> void: _set_status(online_text(reason)))
	return online


## Joins the online room `code` (as the player typed it): the issuer gives a seat, then the relay connects.
func join_online(code: String) -> Error:
	if not MpIssuer.is_configured():
		_set_status(online_text("no_issuer"))
		return ERR_UNCONFIGURED
	_set_status(online_working_status)
	## A room whose host is still getting on the relay answers room_starting: ask again for a few seconds.
	var seat: Dictionary = await MpIssuer.join_room(get_tree(), code)
	var tries := 0
	while not seat["ok"] and str(seat["error"]) == "room_starting" and tries < 30:
		tries += 1
		await get_tree().create_timer(0.5, true).timeout
		seat = await MpIssuer.join_room(get_tree(), code)
	if not seat["ok"]:
		_set_status(online_text(str(seat["error"]), seat["data"]))
		return ERR_UNAVAILABLE
	var data: Dictionary = seat["data"]
	## The relay for this connection only (use_relay_room): MpKit.transport stays the game's, for LAN afterwards.
	MpTransport.use_relay_room(str(data.get("room", "")), str(data.get("token", "")), str(data.get("relay_url", "")))
	var ticket: Variant = data.get("ticket", null)
	var err := MpKit.join(str(data.get("code", code)), MpKit.port, str(ticket) if ticket != null else "")
	_set_status(join_fail_status if err != OK else joining_status % str(data.get("code", code)))
	return err


## The public online rooms of this game and version with a free seat: [{code, name, players, max_players, state,
## platform, age_s}]. [] (and a status) when the issuer cannot answer.
func online_rooms() -> Array:
	if not MpIssuer.is_configured():
		_set_status(online_text("no_issuer"))
		return []
	var listed: Dictionary = await MpIssuer.list_rooms(get_tree())
	if not listed["ok"]:
		_set_status(online_text(str(listed["error"]), listed["data"]))
		return []
	return listed["data"].get("rooms", [])


## The status for an issuer word (online_texts), with the version the issuer sent when it names one.
func online_text(word: String, data: Dictionary = {}) -> String:
	var text := str(online_texts.get(word, ""))
	if text.is_empty():
		return online_error_status % word
	if text.contains("%s"):
		return text % str(data.get("min_version", data.get("host_version", "?")))
	return text


func _on_online_ready(code: String) -> void:
	_set_status(online_ready_status % code)


func join_lan(ip: String) -> Error:
	if not MpLan.is_valid_ipv4(ip.strip_edges()):
		_set_status(bad_ip_status)
		return ERR_INVALID_PARAMETER
	return join_endpoint(ip, MpKit.port)


## What a player types: "192.168.1.5", "play.example.com" or either with ":port" (default MpKit.port), and
## "#CODE" at the end for a private match (MpLocalServer). A full "wss://…" URL goes as is (WebSocket).
func join_address(text: String, ticket: String = "") -> Error:
	var address := MpAddress.parse(text, MpKit.port)
	if not address.is_valid():
		_set_status(bad_ip_status)
		return ERR_INVALID_PARAMETER
	if not address.code.is_empty():
		ticket = address.code
	if not address.url.is_empty():
		var err := MpKit.join(address.url, MpKit.port, ticket)
		_set_status(join_fail_status if err != OK else joining_status % address.url)
		return err
	return join_endpoint(address.host, address.port, ticket)


## The lobby's match_ready(host, port, token): join that match; when it ends, come back to `lobby_path`.
func join_match(host: String, p_port: int, token: String) -> Error:
	_match_from_lobby = true
	var err := join_endpoint(host if not host.is_empty() else "127.0.0.1", p_port, token)
	if err != OK:
		_match_from_lobby = false
	return err


## Join a dedicated by host (IPv4 or name) and port; `ticket` is presented for admission.
func join_endpoint(host: String, p_port: int, ticket: String = "") -> Error:
	var trimmed := host.strip_edges()
	var named := MpLan.is_valid_ipv4(trimmed) or MpLan.is_valid_hostname(trimmed)
	if not named or p_port < PORT_MIN or p_port > PORT_MAX:
		_set_status(bad_ip_status)
		return ERR_INVALID_PARAMETER
	var err := MpKit.join(trimmed, p_port, ticket)
	if err != OK:
		_set_status(join_fail_status)
		return err
	_set_status(joining_status % trimmed)
	return OK


func start_match() -> void:
	if match_running or not MpKit.is_server():
		return
	_begin_match()


func return_to_boot() -> void:
	match_running = false
	_stop_lan()
	MpKit.leave()
	_go_boot()


## Loads the world on a thread (MpWorldLoader, world_load_progressed) with what _extra_world_loads() names; world_loaded at the end.
func goto_world() -> void:
	_adopt()
	world_loading.emit()
	_before_world_load()
	var entry := _resolved_world()
	var path := entry.resolve_path() if entry != null else ""
	var scene: PackedScene = entry.scene if entry != null else null
	if path.is_empty() and scene == null:
		path = world_path.strip_edges()
		scene = world_scene
	_loader.load_world(path, scene, _extra_world_loads(), _reports_loaded())


## The world says how far it got getting ready (0..1), between the scene swap and report_world_loaded().
func report_world_progress(ratio: float) -> void:
	_loader.report_progress(ratio)


## The world is ready (with `world_reports_loaded`): the load ends and this peer counts as loaded at the start gate.
func report_world_loaded() -> void:
	_loader.report_loaded()


## Override: right before a world loads, on every peer (e.g. the game picks the map). Nothing by default.
func _before_world_load() -> void:
	pass


## Override: files to read on the loading thread beside the world (what it will spawn). None by default.
func _extra_world_loads() -> PackedStringArray:
	return PackedStringArray()


## world_reports_loaded, or `--world-reports-loaded`.
func _reports_loaded() -> bool:
	return world_reports_loaded or MpBoot.user_flag("world-reports-loaded")


## How a peer counts as loaded at the gate (see world_reports_loaded), on every path that arms it.
func _apply_load_mode() -> void:
	MpKit.gate.wait_host = _reports_loaded()
	MpKit.gate.loaded_on_world_ready = not _reports_loaded()


func _on_world_loaded() -> void:
	world_loaded.emit()
	if _reports_loaded():
		MpKit.report_loaded()


func add_world(id: StringName, path: String, scene: PackedScene = null) -> MpWorldRef:
	var entry := MpWorldRef.new()
	entry.id = id
	entry.path = path
	entry.scene = scene
	worlds.append(entry)
	if world_id == &"":
		world_id = id
	return entry


func select_world(id: StringName) -> bool:
	if id == &"":
		return false
	if not worlds.is_empty() and _world_entry(id) == null:
		return false
	if world_id == id:
		return true
	world_id = id
	world_changed.emit(world_id)
	return true


func world_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for entry in worlds:
		if entry != null and entry.id != &"":
			out.append(String(entry.id))
	return out


## What a client shows when the server turned it away. Override to translate (`reason`: MpMatchGate's codes, "timeout"...).
func rejection_text(reason: String) -> String:
	if reason == MpMatchGate.MATCH_STARTED:
		return match_started_status
	return rejected_status % reason


## Server: opens the start gate of this match. A room's dedicated arms it through its MpMatchAgent (the ticket names the seats);
## any other host opens every client seat; solo has no seats (it waits only for its own world). Idempotent.
func _arm_gate() -> void:
	if MpKit.gate.is_armed() or (MpKit.is_networked() and not MpKit.is_server()):
		return
	## Here and not only in _ready: play_solo / host_lan may run before it (a game that starts from its boot scene's _ready).
	_apply_load_mode()
	if not MpKit.is_networked():
		MpKit.gate.load_timeout_s = float(MpBoot.user_value("load-timeout-s", str(load_timeout_s)))
		MpKit.gate.arm([], 0)
		return
	MpKit.gate.pause_clients = pause_clients
	var agents := get_tree().get_nodes_in_group(&"mp_match_agent")
	if not agents.is_empty():
		## Untyped: the flow must not load the lobby scripts.
		agents[0].call(&"arm_gate")
		return
	## A ticket whose agent is not up yet: _ensure_match_agent arms it.
	if not MpBoot.user_value("match-ticket-file", "").is_empty():
		return
	var gate := MpKit.gate
	gate.rejoin_grace_s = float(MpBoot.user_value("rejoin-grace-s", str(rejoin_grace_s)))
	gate.load_timeout_s = float(MpBoot.user_value("load-timeout-s", str(load_timeout_s)))
	gate.host_present = MpKit.is_listen_host()
	gate.late_join = late_join or MpBoot.user_flag("late-join")
	gate.arm(MpKit.open_seats(), int(MpBoot.user_value("start-seats", str(start_seats))))


## A dedicated by hand (no ticket): it serves one match after another, so there is a next one when a match ends.
func _serves_open_matches() -> bool:
	return MpKit.is_dedicated() and MpBoot.user_value("match-ticket-file", "").is_empty() \
		and get_tree().get_nodes_in_group(&"mp_match_agent").is_empty()


## Server, a dedicated by hand: the match is over and nobody is left. A fresh world (score and actors from zero) and every
## seat open again. Public: a game with a rematch screen may call it once its players left.
func next_open_match() -> void:
	if not _serves_open_matches():
		return
	_open_match_over = false
	MpKit.gate.reset()
	_arm_gate()
	if _dedicated_at_once:
		match_running = true
		goto_world.call_deferred()
	else:
		## Started without --dedicated (StartWhen): the world loads again with the next first client.
		match_running = false


## Server: every seat of the match is past the grace (the gate gave up on all of them).
func _on_all_gone() -> void:
	next_open_match()


## Server: after a finished match, the last player that leaves opens the next one (no grace to wait for).
func _on_peer_left(_peer_id: int, _slot: int) -> void:
	if _open_match_over and MpKit.occupied_slots().is_empty():
		next_open_match()


## Sent to every seat the gate let in (a first time or a rejoin): the world, and what the joiner must know first.
func snapshot_for_joiner() -> Dictionary:
	var snap := {}
	var id := _snapshot_world_id()
	if not id.is_empty():
		snap["world_id"] = id
	return snap


func _begin_match() -> void:
	match_running = true
	# Peers already connected (dedicated first client) need the world id too.
	var snap := snapshot_for_joiner()
	if not snap.is_empty():
		MpKit.push_snapshot(snap)
	MpKit.broadcast_load_world()
	_start_advertise()
	## At the end of the frame: a caller inside a tree change (host_lan from _ready, while the root still adds the autoloads)
	## cannot swap the scene then.
	goto_world.call_deferred()


## MpKit says joined only for a seat the gate let in, so the world goes to admitted seats only (a newcomer after the start was
## turned away before this).
func _on_peer_joined(peer_id: int, _slot: int) -> void:
	if match_running:
		var snap := snapshot_for_joiner()
		if not snap.is_empty():
			MpKit.push_snapshot_to(peer_id, snap)
		MpKit.load_world_to(peer_id)
		return
	if MpKit.is_dedicated() and start_when == StartWhen.DEDICATED_FIRST_CLIENT:
		_begin_match()


func _on_admission_rejected(reason: String) -> void:
	match_running = false
	_set_status(rejection_text(reason))


func _on_join_failed() -> void:
	match_running = false
	_set_status(join_fail_status)


## The host stopped sending: say so, and give up after host_silent_timeout_s unless it comes back.
func _on_host_silent(_seconds: float) -> void:
	_set_status(host_silent_status)
	var since := Time.get_ticks_msec()
	MpKit.after_real(maxf(host_silent_timeout_s - MpKit.host_silent_after_s, 0.0), func() -> void:
		if MpKit.is_host_silent() and MpKit.host_silent_since_ms() <= since:
			MpKit.leave()
			_on_server_lost())


func _on_host_back() -> void:
	_set_status("")


func _on_server_lost() -> void:
	match_running = false
	_stop_lan()
	_set_status(server_lost_status)
	if _back_to_lobby():
		return
	_go_boot()


func _on_session_ended(result: Dictionary) -> void:
	match_running = false
	match_finished.emit(result)


## Server: the match ended (MpMatch.finish). A dedicated by hand opens the next one once its players left.
func _on_session_ended_sent(_result: Dictionary) -> void:
	if not _serves_open_matches():
		return
	_open_match_over = true
	if MpKit.occupied_slots().is_empty():
		next_open_match()


## A match from the lobby is over: the lobby screen again (it shows the result). False when there is none.
func _back_to_lobby() -> bool:
	if not _match_from_lobby or lobby_path.is_empty():
		return false
	_match_from_lobby = false
	MpKit.leave()
	get_tree().change_scene_to_file(lobby_path)
	return true


## Called by MpMatch (or the game) once the result was shown: leave the match, back to the lobby or the boot.
func leave_match() -> void:
	match_running = false
	if _back_to_lobby():
		return
	return_to_boot()


func _ensure_match_agent() -> void:
	## By path, not by class: the flow must not depend on the lobby scripts to load.
	if MpKit.admission.is_valid() or not get_tree().get_nodes_in_group(&"mp_match_agent").is_empty():
		_arm_gate()
		return
	var agent: Node = (load("res://addons/mp_kit/lobby/mp_match_agent.gd") as GDScript).new()
	agent.name = "MatchAgent"
	add_child(agent)
	_arm_gate()


func _go_boot() -> void:
	_adopt()
	var path := boot_path.strip_edges()
	if not path.is_empty():
		get_tree().change_scene_to_file(path)
		return
	if boot_scene != null:
		get_tree().change_scene_to_packed(boot_scene)


func _start_advertise() -> void:
	if not advertise_lan or not MpKit.is_listen_host():
		return
	_stop_lan()
	_lan = MpLan.advertise(self, room_name, MpKit.port)


func _stop_lan() -> void:
	if _lan == null:
		return
	if is_instance_valid(_lan):
		_lan.stop()
		_lan.queue_free()
	_lan = null


func _set_status(text: String) -> void:
	status_changed.emit(text)


func _pick_world_from_args() -> void:
	var arg := MpBoot.user_value("world", "")
	if not arg.is_empty():
		var named := StringName(arg)
		if worlds.is_empty() or _world_entry(named) != null:
			world_id = named
			return
	if world_id == &"" and not worlds.is_empty() and worlds[0] != null:
		world_id = worlds[0].id


func _on_flow_snapshot(data: Dictionary) -> void:
	var raw := str(data.get("world_id", data.get("world_kind", "")))
	if raw.is_empty():
		return
	select_world(StringName(raw))


func _snapshot_world_id() -> String:
	if world_id != &"":
		return String(world_id)
	var entry := _resolved_world()
	return String(entry.id) if entry != null else ""


func _resolved_world() -> MpWorldRef:
	if worlds.is_empty():
		return null
	var found := _world_entry(world_id)
	return found if found != null else worlds[0]


func _world_entry(id: StringName) -> MpWorldRef:
	if id == &"":
		return null
	for entry in worlds:
		if entry != null and entry.id == id:
			return entry
	return null
