class_name MpMatchAgent
extends Node

## Dedicated-match side of the launcher. Reads `--match-ticket-file`, sets `MpKit.admission`
## from the token hashes, writes state.json as a heartbeat, writes result.json when the match
## ends, and quits when nobody is left or the room server (`--room-pid`) is gone.
## The glue starts the dedicated host (MpKit.host_dedicated) and calls `report_result()`.
## The agent never sees the plain token: it compares sha256(presented) with the ticket.
## Rows of the ticket without `token_sha256` (bot seats) are ignored: they are never admitted.

signal ticket_loaded(ticket: Dictionary)
signal result_reported(data: Dictionary)

@export var config: MpLobbyConfig
## Start by itself in _ready when `--match-ticket-file` is present.
@export var auto_start: bool = true

const GROUP := &"mp_match_agent"
## Result reason when the relay refused this match's port (another live host): the launcher retries another port.
const PORT_IN_USE := "port_in_use"

var ticket: Dictionary = {}
var match_id: String = ""
var finished: bool = false

var _root: String = ""
var _room_pid: int = 0
var _started_ms: int = 0
var _hb_accum: float = 0.0
var _parent_accum: float = 0.0
var _empty_since_ms: int = 0
var _ever_joined: bool = false
## slot -> {sha, meta, used: bool, peer: int, left_ms: int}
var _seats: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	## Infrastructure: it keeps the heartbeat and the state going while the match is paused (MpMatch waits for seats).
	process_mode = Node.PROCESS_MODE_ALWAYS
	if config == null:
		config = MpLobbyConfig.new()
	config = config.with_cli_overrides()
	if auto_start and not MpBoot.user_value("match-ticket-file", "").is_empty():
		start()


## Loads the ticket and arms the admission. Returns false if the ticket is unusable.
func start(ticket_path: String = "") -> bool:
	if ticket_path.is_empty():
		ticket_path = MpBoot.user_value("match-ticket-file", "")
	ticket = MpMatchFiles.read_json(ticket_path)
	match_id = str(ticket.get("match_id", ""))
	if not MpMatchFiles.is_valid_id(match_id) or ticket.get("seats", []).is_empty():
		push_error("MpMatchAgent: unusable ticket %s" % ticket_path)
		get_tree().quit(1)
		return false
	_root = ticket_path.get_base_dir().get_base_dir()
	_room_pid = int(MpBoot.user_value("room-pid", str(ticket.get("room_pid", 0))))
	_started_ms = MpMatchFiles.now_ms()
	for seat in ticket["seats"]:
		var row: Dictionary = seat
		## A row without a token hash (a bot seat) is never admitted.
		if str(row.get("token_sha256", "")).is_empty():
			continue
		_seats[int(row["slot"])] = {
			"sha": str(row["token_sha256"]), "meta": row.get("meta", {}),
			"used": false, "peer": 0, "left_ms": 0,
		}
	MpKit.admission = _admit
	MpKit.peer_joined.connect(_on_peer_joined)
	MpKit.peer_left.connect(_on_peer_left)
	set_process(true)
	_write_state()
	ticket_loaded.emit(ticket)
	return true


func seat_meta(slot: int) -> Dictionary:
	return _seats.get(slot, {}).get("meta", {})


func connected_slots() -> Array[int]:
	var out: Array[int] = []
	for slot in _seats.keys():
		if int(_seats[slot]["peer"]) != 0:
			out.append(int(slot))
	return out


## Writes result.json, tells the clients and quits after `result_quit_delay_s`. Only the first call counts.
func report_result(data: Dictionary) -> void:
	if finished:
		return
	finished = true
	var out := data.duplicate(true)
	out["match_id"] = match_id
	if not out.has("reason"):
		out["reason"] = "result"
	out["ended_ms"] = MpMatchFiles.now_ms()
	MpMatchFiles.write_json(MpMatchFiles.path_of(_root, match_id, MpMatchFiles.RESULT), out)
	_write_state()
	MpKit.broadcast_session_ended(out)
	result_reported.emit(out)
	var delay := config.result_quit_delay_s if out["reason"] != "room_gone" and out["reason"] != PORT_IN_USE else 0.0
	if delay <= 0.0:
		get_tree().quit()
	else:
		get_tree().create_timer(delay).timeout.connect(func() -> void: get_tree().quit())


func _process(delta: float) -> void:
	if ticket.is_empty() or finished:
		return
	## Through the relay this port's room has another live host: say so, the launcher tries another port.
	if MpKit.listen_refused():
		report_result({"reason": PORT_IN_USE})
		return
	_hb_accum += delta
	if _hb_accum >= config.heartbeat_s:
		_hb_accum = 0.0
		_write_state()
	_parent_accum += delta
	if _parent_accum >= config.parent_check_s:
		_parent_accum = 0.0
		if _room_pid > 0 and not MpProcessRunner.pid_alive(_room_pid):
			report_result({"reason": "room_gone"})
			return
	_check_idle()


func _check_idle() -> void:
	var now := MpMatchFiles.now_ms()
	if not connected_slots().is_empty():
		_empty_since_ms = 0
		return
	if not _ever_joined and now > int(ticket.get("expires_ms", 0)):
		report_result({"reason": "ticket_expired"})
		return
	if _empty_since_ms == 0:
		_empty_since_ms = _started_ms if not _ever_joined else now
	if now - _empty_since_ms > int(config.idle_no_players_s * 1000.0):
		report_result({"reason": "empty"})


func _admit(peer_id: int, presented: String) -> int:
	if finished:
		return 0
	var sha := MpMatchFiles.sha256(presented)
	var now := MpMatchFiles.now_ms()
	for slot in _seats.keys():
		var seat: Dictionary = _seats[slot]
		if seat["sha"] != sha:
			continue
		if int(seat["peer"]) != 0 and int(seat["peer"]) != peer_id:
			return 0
		if not bool(seat["used"]):
			return int(slot) if now <= int(ticket.get("expires_ms", 0)) else 0
		if now - int(seat["left_ms"]) > int(config.rejoin_grace_s * 1000.0):
			return 0
		return int(slot)
	return 0


func _on_peer_joined(peer_id: int, slot: int) -> void:
	if not _seats.has(slot):
		return
	var seat: Dictionary = _seats[slot]
	seat["used"] = true
	seat["peer"] = peer_id
	_ever_joined = true
	_write_state()


func _on_peer_left(peer_id: int, slot: int) -> void:
	if not _seats.has(slot) or int(_seats[slot]["peer"]) != peer_id:
		return
	_seats[slot]["peer"] = 0
	_seats[slot]["left_ms"] = MpMatchFiles.now_ms()
	_write_state()


func _write_state() -> void:
	var slots := {}
	for slot in _seats.keys():
		slots[str(slot)] = int(_seats[slot]["peer"]) != 0
	var listening := MpKit.is_listening()
	MpMatchFiles.write_json(MpMatchFiles.path_of(_root, match_id, MpMatchFiles.STATE), {
		"match_id": match_id, "pid": OS.get_process_id(), "listening": listening,
		"heartbeat_ms": MpMatchFiles.now_ms(), "started_ms": _started_ms,
		"finished": finished, "slots": slots,
	})
