class_name MpRateLimit
extends RefCounted

## Per-peer token bucket for messages a client sends to the server: `rate_per_s` on average, `burst` at once. Over
## the limit a message is dropped (the server never lets a client flood it). Pure data. Not: deciding what a
## message means.

var rate_per_s: float = 30.0
var burst: float = 60.0

var _tokens: Dictionary = {}
var _stamp_ms: Dictionary = {}


func _init(p_rate_per_s: float = 30.0, p_burst: float = 60.0) -> void:
	rate_per_s = p_rate_per_s
	burst = p_burst


## True if `peer_id` may send one more message now (and it is counted).
func allow(peer_id: int, now_ms: int = -1) -> bool:
	if now_ms < 0:
		now_ms = Time.get_ticks_msec()
	var tokens: float = _tokens.get(peer_id, burst)
	var last: int = _stamp_ms.get(peer_id, now_ms)
	tokens = minf(burst, tokens + float(now_ms - last) / 1000.0 * rate_per_s)
	_stamp_ms[peer_id] = now_ms
	if tokens < 1.0:
		_tokens[peer_id] = tokens
		return false
	_tokens[peer_id] = tokens - 1.0
	return true


func forget(peer_id: int) -> void:
	_tokens.erase(peer_id)
	_stamp_ms.erase(peer_id)
