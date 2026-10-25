class_name MpNetQuality
extends Node

## How this connection behaves, measured all the time: round trip (RTT), jitter and loss. A client pings the server
## a few times a second (tiny unreliable packets) and the server answers; each ping also carries the client's own
## numbers, so the server knows every player's. MpKit keeps one (MpKit.net_quality); read it with Mp.net_quality().
## Not: the buffers that size themselves to the network (MpProxyMotion and MpInputQueue measure their own packets).

enum Grade {
	GOOD, ## RTT < 80 ms, jitter < 15 ms, loss < 1 %
	FAIR, ## RTT < 180 ms, jitter < 40 ms, loss < 5 %
	BAD, ## worse
}

const PING_S := 0.25
## Pings remembered (10 s).
const WINDOW := 40
## A ping not answered in this long counts as lost.
const LOST_AFTER_S := 1.0
## Pings a client may send per second (more are ignored).
const MAX_PINGS_PER_S := 20.0

var _stats := Stats.new()
var _since_ping: float = 0.0
var _seq: int = 0
## Server: peer id -> {rtt_ms, jitter_ms, loss, last_ms}.
var _peers: Dictionary = {}
var _limit := MpRateLimit.new(MAX_PINGS_PER_S, MAX_PINGS_PER_S)


## This machine's connection: {rtt_ms, jitter_ms, loss, grade, grade_name, samples}. On the server (and solo)
## RTT is 0: use of_peer / of_slot for the players.
func snapshot() -> Dictionary:
	return MpNetQuality.describe(_stats.rtt_ms(), _stats.jitter_ms(), _stats.loss(), _stats.samples())


## Server: what peer `peer_id` measured ({} until its first ping).
func of_peer(peer_id: int) -> Dictionary:
	var row: Dictionary = _peers.get(peer_id, {})
	if row.is_empty():
		return {}
	return MpNetQuality.describe(row["rtt_ms"], row["jitter_ms"], row["loss"], -1)


## Server: the player of `slot` ({} if none).
func of_slot(slot: int) -> Dictionary:
	for peer_id in _peers:
		if MpKit.slot_for_peer(peer_id) == slot:
			return of_peer(peer_id)
	return {}


static func grade_of(rtt_ms: float, jitter_ms: float, loss: float) -> Grade:
	if rtt_ms < 80.0 and jitter_ms < 15.0 and loss < 0.01:
		return Grade.GOOD
	if rtt_ms < 180.0 and jitter_ms < 40.0 and loss < 0.05:
		return Grade.FAIR
	return Grade.BAD


static func describe(rtt_ms: float, jitter_ms: float, loss: float, samples: int) -> Dictionary:
	var grade := MpNetQuality.grade_of(rtt_ms, jitter_ms, loss)
	return {"rtt_ms": rtt_ms, "jitter_ms": jitter_ms, "loss": loss, "grade": grade,
		"grade_name": Grade.keys()[grade].to_lower(), "samples": samples}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MpKit.peer_left.connect(func(peer_id: int, _slot: int) -> void: _peers.erase(peer_id))


func _process(delta: float) -> void:
	if not MpKit.is_networked() or MpKit.is_server():
		if not MpKit.is_networked():
			_stats.clear()
		return
	## Only over an established link: a ping sent while connecting is never answered and would count as lost.
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED or not multiplayer.get_peers().has(MpAuthority.SERVER_PEER):
		return
	var now := Time.get_ticks_usec() / 1000000.0
	_stats.expire(now)
	_since_ping += delta
	if _since_ping < PING_S:
		return
	_since_ping = 0.0
	_seq += 1
	_stats.on_sent(_seq, now)
	rpc_ping.rpc_id(MpAuthority.SERVER_PEER, _seq, _stats.rtt_ms(), _stats.jitter_ms(), _stats.loss())


@rpc("any_peer", "call_remote", "unreliable")
func rpc_ping(seq: int, rtt_ms: float, jitter_ms: float, loss: float) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _limit.allow(peer_id):
		return
	_peers[peer_id] = {"rtt_ms": clampf(rtt_ms, 0.0, 10000.0), "jitter_ms": clampf(jitter_ms, 0.0, 10000.0),
		"loss": clampf(loss, 0.0, 1.0), "last_ms": Time.get_ticks_msec()}
	rpc_pong.rpc_id(peer_id, seq)


@rpc("authority", "call_remote", "unreliable")
func rpc_pong(seq: int) -> void:
	_stats.on_reply(seq, Time.get_ticks_usec() / 1000000.0)


## The numbers of one connection, from pings sent and answered. Pure data (the tests feed it by hand).
class Stats:
	var _rtts := PackedFloat64Array()
	var _sent: Dictionary = {}
	var _outcomes: Array[bool] = []

	func clear() -> void:
		_rtts.clear()
		_sent.clear()
		_outcomes.clear()

	func samples() -> int:
		return _rtts.size()

	func on_sent(seq: int, at_s: float) -> void:
		_sent[seq] = at_s

	## Returns the round trip in ms (or -1 for an unknown or expired ping).
	func on_reply(seq: int, at_s: float) -> float:
		if not _sent.has(seq):
			return -1.0
		var rtt := (at_s - float(_sent[seq])) * 1000.0
		_sent.erase(seq)
		_rtts.append(rtt)
		if _rtts.size() > MpNetQuality.WINDOW:
			_rtts.remove_at(0)
		_remember(true)
		return rtt

	## Pings older than LOST_AFTER_S without an answer are lost.
	func expire(now_s: float) -> void:
		for seq in _sent.keys():
			if now_s - float(_sent[seq]) > MpNetQuality.LOST_AFTER_S:
				_sent.erase(seq)
				_remember(false)

	## The median round trip (0 before any).
	func rtt_ms() -> float:
		return MpNetQuality.percentile(_rtts, 0.5)

	## How much the round trip wanders: half the spread between the fastest and the 97th percentile (one way).
	func jitter_ms() -> float:
		if _rtts.size() < 2:
			return 0.0
		return (MpNetQuality.percentile(_rtts, 0.97) - MpNetQuality.percentile(_rtts, 0.0)) / 2.0

	func loss() -> float:
		if _outcomes.is_empty():
			return 0.0
		return float(_outcomes.count(false)) / float(_outcomes.size())

	func _remember(received: bool) -> void:
		_outcomes.append(received)
		if _outcomes.size() > MpNetQuality.WINDOW:
			_outcomes.pop_front()


## The value under which `p` (0..1) of `values` fall (nearest rank; 0 for none).
static func percentile(values: PackedFloat64Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var i := clampi(int(ceil(clampf(p, 0.0, 1.0) * sorted.size())) - 1, 0, sorted.size() - 1)
	return sorted[i]
