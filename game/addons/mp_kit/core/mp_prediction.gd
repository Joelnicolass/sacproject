class_name MpPrediction
extends RefCounted

## Client-side prediction and server reconciliation for one MpActor with `predict`. The parent's `mp_move(input,
## delta)` is the only movement code:
##   server - runs it once per frame the owner sent (MpInputQueue), in order, so it simulates the owner's own ticks;
##   owner  - runs it at once every tick with its own keys; when a server state arrives it goes back to that state
##            and replays the frames the server has not applied yet (`acked_seq`). Same ticks, so corrections ~0.
## Everything runs inside the physics tick (move_and_slide uses its delta). Not: drawing proxies (MpProxyMotion).

## How far the last server correction moved the owner's node (0 = the prediction was right).
var last_correction: float = 0.0
## Most ticks one reconciliation replays. With a high ping more frames are unacknowledged; past this cap only
## every n-th server state is reconciled (as Photon Fusion caps resimulations), the others are skipped.
var max_resim_ticks: int = 32
## Owner: reconciliations skipped by the cap so far (a test can read it).
var skipped_reconciles: int = 0
## Owner: draws each correction's jump fading out instead of at once (null = at once).
var smoother: MpCorrectionSmoother
## Owner: the stamp of the last server state it went back to (0 = none yet).
var reconciled_stamp: float = 0.0

var _states_since_reconcile: int = 0
## Owner: how far the last simulated frame moved the node (a paced-down tick is drawn as if it moved this much).
var _last_step := Vector3.ZERO

var _root: Node
var _input: MpInput
var _predicted := Vector3.ZERO
var _seen_stamp: float = -1.0


func _init(root: Node, input: MpInput) -> void:
	_root = root
	_input = input


## The owner's node starts at the server's pose (its spawn).
func start_at(position: Vector3) -> void:
	_predicted = position


## Server (or solo / the host's own player): this tick's movement.
func server_tick(delta: float, reads_keys_here: bool) -> void:
	if reads_keys_here:
		_root.mp_move(_input, delta)
		return
	var keep := _input.current_frame()
	var keep_before := _input.previous_frame()
	var before := keep_before
	for frame in _input.tick_frames():
		_input.use_frame(frame, before, false)
		_root.mp_move(_input, delta)
		before = frame
	_input.use_frame(keep, keep_before, false)


## Owner: reconcile when the server sent a new state (`stamp`), then predict this tick.
func owner_tick(delta: float, stamp: float, motion: MpProxyMotion, net_pos: Vector3, net_rot: Quaternion) -> void:
	## Pacing (MpInput): an extra frame this tick, before the tick's own (both belong to THIS tick: a reconciliation
	## replays only the ticks before it, then both run here, as the server will); or no frame at all this tick (the
	## reconciliation then replays up to the last one).
	var extra := _input.take_extra()
	var skip := _input.take_skip()
	if stamp > 0.0 and stamp != _seen_stamp:
		_seen_stamp = stamp
		_states_since_reconcile += 1
		var replay := _input.replay_chain().size() - 2
		var every := maxi(int(ceil(float(replay) / float(maxi(max_resim_ticks, 1)))), 1)
		if _states_since_reconcile >= every:
			_states_since_reconcile = 0
			_reconcile(delta, motion, net_pos, net_rot, 0 if skip else (2 if not extra.is_empty() else 1))
			reconciled_stamp = stamp
		else:
			skipped_reconciles += 1
	var start := MpProxyMotion.position_of(_root)
	if skip:
		## No frame this tick: drawn as if it went on one step, fading into where it is.
		if smoother:
			smoother.absorb(start + _last_step, MpProxyMotion.rotation_of(_root))
		_predicted = start
		return
	if not extra.is_empty():
		var keep := _input.current_frame()
		var keep_before := _input.previous_frame()
		_input.use_frame(extra[0], extra[1], false)
		_root.mp_move(_input, delta)
		_input.use_frame(keep, keep_before, false)
	var after_extra := MpProxyMotion.position_of(_root)
	var after_extra_rot := MpProxyMotion.rotation_of(_root)
	_root.mp_move(_input, delta)
	_predicted = MpProxyMotion.position_of(_root)
	if not extra.is_empty():
		_last_step = (_predicted - start) / 2.0
		## Two frames this tick: drawn one step on, fading into where it is.
		if smoother:
			smoother.absorb(after_extra, after_extra_rot)
	else:
		_last_step = _predicted - start


## Back to the server's pose after `acked_seq`, then the ticks it has not seen, up to the last one predicted (this
## tick's frame runs next, as every tick).
## `this_tick`: frames at the end of the history that belong to this tick (1, 2 with a paced extra frame, 0 when
## this tick has none).
func _reconcile(delta: float, motion: MpProxyMotion, net_pos: Vector3, net_rot: Quaternion, this_tick: int = 1) -> void:
	var keep := _input.current_frame()
	var keep_before := _input.previous_frame()
	var before_pos := MpProxyMotion.position_of(_root)
	var before_rot := MpProxyMotion.rotation_of(_root)
	motion.write(net_pos, net_rot)
	var chain := _input.replay_chain()
	for i in range(1, chain.size() - this_tick):
		_input.use_frame(chain[i], chain[i - 1], true)
		_root.mp_move(_input, delta)
	_input.use_frame(keep, keep_before, false)
	last_correction = MpProxyMotion.position_of(_root).distance_to(_predicted)
	if smoother:
		smoother.absorb(before_pos, before_rot)
