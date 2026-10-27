class_name MpOnline
extends Node

## A room this player hosts online through the MpKit issuer and relay: no server of yours runs the match.
## Desktop: a match process on this PC hosts it (MpLocalServer, the same code as a VPS) and this player joins it like
## any other; it keeps running if the window is minimized. Browser (it cannot start a process): this game hosts it
## itself and keeps simulating while its tab is hidden (MpWebKeepAlive). `--online-mode=listen|dedicated` picks one
## (tests). Friends join with the code (MpFlow.join_online) or from the list (MpFlow.online_rooms).
## Lives under the root, tells the issuer every few seconds that the room is alive (players, seats taken) and closes
## it when the match ends or this player leaves. One per process.
##   var online := MpOnline.start_on(get_tree(), 4, "Friday night")
##   online.room_ready.connect(func(code): show(code))
## `ticket`: the game's match ticket (world, mode, options, seed, picks…, `seats: [{slot, meta}]`). Desktop: it goes to
## the match process (MpLocalServer.merge_ticket). Browser: this game is the match, so it reads `ticket` here.
## Not: the HTTP calls (MpIssuer), the relay connection (MpTransport), the match rules (the game).

## Players may join: `code` is what they type.
signal room_ready(code: String)
## The issuer refused (its word: "too_many_rooms", "version_too_old"…), it could not be reached ("network"), or the
## match could not start.
signal failed(reason: String)
## The room is closed (the match ended, or this player left).
signal ended

const GROUP := &"mp_online"
const LISTEN := "listen"
const DEDICATED := "dedicated"

## The room's code once the issuer gave it.
var code: String = ""
## LISTEN (this game hosts) or DEDICATED (a match process of this PC hosts).
var mode: String = ""
var max_players: int = 0
## The game's match ticket this room was opened with ({} = none).
var ticket: Dictionary = {}
var _key: String = ""
var _relay_room: String = ""
var _heartbeat_s: float = 10.0
var _local: MpLocalServer
var _ready_sent: bool = false
var _hosting: bool = false
var _next_beat_ms: int = 0
var _beating: bool = false
var _closed: bool = false


## The online room this process hosts, or null.
static func running(tree: SceneTree) -> MpOnline:
	for node in tree.get_nodes_in_group(GROUP):
		if not node.is_queued_for_deletion():
			return node as MpOnline
	return null


## Creates the node under the root and opens a room for `players` players (this one counts). One already running is
## given back as it is.
static func start_on(tree: SceneTree, players: int, room_name: String, listed: bool = true, match_ticket: Dictionary = {}) -> MpOnline:
	var already := MpOnline.running(tree)
	if already:
		return already
	var online := MpOnline.new()
	online.name = "MpOnline"
	tree.root.add_child(online)
	online.start(players, room_name, listed, match_ticket)
	return online


## Which way this build hosts: a browser in its own game, a desktop through a match process.
static func default_mode() -> String:
	var flag := MpBoot.user_value("online-mode", "")
	if flag == LISTEN or flag == DEDICATED:
		return flag
	return LISTEN if OS.has_feature("web") else DEDICATED


func _enter_tree() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS


## True once players can join (the relay accepted the room's host).
func is_ready() -> bool:
	return _ready_sent


## For MpInviteLabel: the code friends type.
func invite_text() -> String:
	return code


func start(players: int, room_name: String, listed: bool = true, match_ticket: Dictionary = {}) -> void:
	max_players = players
	ticket = match_ticket.duplicate(true)
	mode = default_mode()
	var seats := PackedStringArray()
	var host_seat := ""
	if mode == DEDICATED:
		host_seat = MpMatchFiles.new_token()
		for i in players - 1:
			seats.append(MpLocalServer.new_code())
	var made: Dictionary = await MpIssuer.create_room(get_tree(), players, room_name, listed, mode, seats)
	if not made["ok"]:
		_fail(str(made["error"]))
		return
	var data: Dictionary = made["data"]
	code = str(data.get("code", ""))
	_key = str(data.get("room_key", ""))
	_relay_room = str(data.get("room", ""))
	_heartbeat_s = maxf(1.0, float(data.get("heartbeat_s", 10.0)))
	MpTransport.relay_url = str(data.get("relay_url", MpTransport.relay_url))
	if mode == DEDICATED:
		_start_dedicated(players, data, host_seat, seats)
	else:
		_start_listen(data)


## Closes the room on the issuer and stops hosting it (the match process, or this game's server).
func stop() -> void:
	await _close()
	if _local and is_instance_valid(_local):
		_local.stop()
	elif mode == LISTEN and MpKit.is_server():
		MpKit.leave()


func _start_dedicated(players: int, data: Dictionary, host_seat: String, seats: PackedStringArray) -> void:
	_local = MpLocalServer.new()
	_local.name = "MpLocalServer"
	get_tree().root.add_child(_local)
	_local.server_ready.connect(func(_address: String, port: int, _codes: Dictionary) -> void: _join_own_match(port, host_seat))
	_local.server_failed.connect(_fail)
	_local.server_ended.connect(func(_result: Dictionary) -> void: _close())
	var online := {"code": code, "room": _relay_room, "token": str(data.get("host_token", "")),
		"url": MpTransport.relay_url, "host_seat": host_seat, "seats": seats}
	_local.start(players, {}, false, online, ticket)


## The match process hosts the relay room; this player joins it with a client token of its own.
func _join_own_match(port: int, host_seat: String) -> void:
	var got: Dictionary = await MpIssuer.tokens(get_tree(), code, _key, "client")
	if not got["ok"]:
		_fail(str(got["error"]))
		return
	MpTransport.use_relay_room(_relay_room, str(got["data"].get("token", "")), MpTransport.relay_url)
	var flow := MpFlow.find_in_tree(self)
	var err := flow.join_endpoint("127.0.0.1", port, host_seat) if flow else MpKit.join(code, port, host_seat)
	if err != OK:
		_fail("join_%s" % error_string(err))
		return
	_set_ready()


func _start_listen(data: Dictionary) -> void:
	MpTransport.use_relay_room(_relay_room, str(data.get("host_token", "")), MpTransport.relay_url)
	var flow := MpFlow.find_in_tree(self)
	var err := flow.host_here() if flow else MpKit.host()
	if err != OK:
		_fail("host_%s" % error_string(err))
		return
	MpWebKeepAlive.enable()
	_hosting = true


## The host is on the relay: friends may join. The first heartbeat now makes the room live on the issuer (listed, open
## to joins); before it a joiner would reach the relay ahead of its host.
func _set_ready() -> void:
	_ready_sent = true
	_beating = true
	_next_beat_ms = 0
	room_ready.emit(code)


func _process(_delta: float) -> void:
	if _closed:
		return
	if mode == LISTEN and _hosting:
		if not _ready_sent and MpKit.is_listening():
			_set_ready()
		if MpKit.listen_refused() or (_ready_sent and not MpKit.is_server()):
			_close()
			return
	if not _beating:
		return
	var now := Time.get_ticks_msec()
	if now >= _next_beat_ms:
		_next_beat_ms = now + int(_heartbeat_s * 1000.0)
		_beat()


## Players in (this one counts), "playing" once every seat is taken, and (dedicated) the seats' tickets taken.
func _beat() -> void:
	var players := 1
	var taken := PackedStringArray()
	if mode == DEDICATED and _local and is_instance_valid(_local):
		var slots := _local.connected_slots()
		players = 0
		for slot in slots.keys():
			if bool(slots[slot]):
				players += 1
				if _local.codes.has(slot):
					taken.append(str(_local.codes[slot]))
		players = maxi(players, 1)
	elif mode == LISTEN:
		players = 1 + multiplayer.get_peers().size()
	var state := "playing" if players >= max_players else "open"
	var answer: Dictionary = await MpIssuer.heartbeat(get_tree(), code, _key, players, state, taken)
	## The issuer forgot the room (it restarted, or the host was silent too long): the match goes on, unlisted.
	if not answer["ok"] and int(answer["status"]) == 404:
		_beating = false


func _close() -> void:
	if _closed:
		return
	_closed = true
	_beating = false
	MpWebKeepAlive.disable()
	if not code.is_empty() and not _key.is_empty():
		await MpIssuer.close_room(get_tree(), code, _key)
	ended.emit()
	queue_free()


func _fail(reason: String) -> void:
	push_warning("MpOnline: %s" % reason)
	failed.emit(reason)
	if _local and is_instance_valid(_local):
		_local.stop()
	_close()


func _exit_tree() -> void:
	MpWebKeepAlive.disable()
