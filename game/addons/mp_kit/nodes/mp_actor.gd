@tool
class_name MpActor
extends Node

## Drop one inside anything the network shares: a player, a bullet, a door. The server owns that node; what you
## tick under "Sync" reaches every peer (the synchronizer is built here, in the editor, and saved in the scene) and
## is drawn smoothly there. `owner_slot` says which player owns it (0 = nobody, the server). Calls travel by name:
##   net.to_server(&"buy", item)  ->  mp_sv_buy(item)  runs on the server (the owner may ask; see `callers`)
##   net.to_all(&"flash")         ->  mp_all_flash()   runs on every peer (only the server may send)
## With `predict`, movement goes in `mp_move(input, delta)`: the server runs it, and the owner runs it at once with
## its own keys and corrects itself from the server's state (reconciliation), so its node answers without lag.
## Not: spawning (MpSpawner), input (MpInput), match state (MpState).

## Who may ask for this node's mp_sv_* calls.
enum Callers {
	OWNER, ## the player in owner_slot (with owner_slot 0: only the server itself)
	ANYONE, ## any seated player (a door, a bell, a shop): check what they ask inside mp_sv_*
}

enum Smoothing {
	NONE, ## draw each server state as it arrives
	FOLLOW, ## chase the newest state: no delay, small stutters when packets arrive unevenly
	BUFFERED, ## draw a little in the past between two real states: smooth under jitter (default)
}

const SV_PREFIX := "mp_sv_"
const ALL_PREFIX := "mp_all_"
const SYNC_NAME := "MpSync"
## Largest argument list a client may send in one to_server call (var_to_bytes size).
const MAX_ARGS_BYTES := 4096
## to_server calls a client may make, shared by every MpActor of the process (per second, and at once).
static var server_calls := MpRateLimit.new(60.0, 120.0)

@export_group("Sync")
@export var sync_position: bool = true:
	set(value):
		sync_position = value
		_editor_rebuild()
@export var sync_rotation: bool = true:
	set(value):
		sync_rotation = value
		_editor_rebuild()
@export var sync_visible: bool = false:
	set(value):
		sync_visible = value
		_editor_rebuild()
## More properties of the parent ("health") or of a node under it ("Health:current").
@export var sync_extra: PackedStringArray = PackedStringArray():
	set(value):
		sync_extra = value
		_editor_rebuild()
## Server states sent per second (0 = every frame). Lower saves bandwidth; BUFFERED smoothing hides the gaps.
@export_range(0, 120) var send_hz: int = 0:
	set(value):
		send_hz = value
		_editor_rebuild()
@export_group("Smoothing")
@export var smoothing: Smoothing = Smoothing.BUFFERED:
	set(value):
		smoothing = value
		_editor_rebuild()
## BUFFERED: how far in the past proxies are drawn, at most. With adaptive_buffer it uses only what the network
## needs (a few ticks on a good one); more hides worse networks.
@export_range(0.0, 0.5, 0.01) var buffer_delay_s: float = 0.1
## BUFFERED: measure the states' spacing and lateness and draw only that far behind (up to buffer_delay_s).
## Off: always buffer_delay_s.
@export var adaptive_buffer: bool = true
## BUFFERED, adaptive: share of states allowed to come too late to be drawn on time (3 % = the 97th percentile, as
## Photon Fusion). Lower = smoother on a bad network, a little more behind.
@export_range(0.0, 0.2, 0.005) var late_tolerance: float = 0.03
## FOLLOW: how fast proxies chase the newest state.
@export var follow_speed: float = 14.0
@export var freeze_rigid_if_proxy: bool = true
@export_group("Prediction")
## The owner moves at once (the parent's `mp_move(input, delta)`) and is corrected by the server.
@export var predict: bool = false:
	set(value):
		predict = value
		_editor_rebuild()
## Most ticks one correction replays (a high ping replays more); past it, fewer corrections are made.
@export_range(4, 240) var max_resim_ticks: int = 32
## How long a server correction of the owner takes to fade on screen (about; the node's physics is corrected at
## once). 0 = drawn at once. `--correction-smoothing-s=` overrides it.
@export_range(0.0, 0.5, 0.01) var correction_smoothing_s: float = 0.1
## A correction longer than this (pixels in 2D, meters in 3D) is drawn at once, as a teleport. 0 = every one fades.
@export var correction_snap_distance: float = 0.0
@export_group("Owner")
## The player slot that owns this node (0 = the server). Spawners set it before the node enters the tree.
@export var owner_slot: int = 0
## Who may call mp_sv_* here. OWNER (default) or ANYONE (things of the world every player uses).
@export var callers: Callers = Callers.OWNER
@export_group("Lag compensation")
## Server: keep the last second of this node's poses, so a shot can be checked against where its shooter saw it
## (MpActor.rewound / seen_position_of on the shooter). Off for things nobody aims at.
@export var lag_compensate: bool = true

## Server time of the state being sent (synced with it; 0 = none yet). Proxies and reconciliation read it.
var net_stamp: float = 0.0
## The server's pose of the parent (synced instead of the parent's own position / rotation when smoothing or
## predicting, so on a client only this node writes the parent's pose).
var net_position: Vector3 = Vector3.ZERO
var net_rotation: Quaternion = Quaternion.IDENTITY
## How many times the server teleported the node (snap()), in the same packet as the pose: no client slides between
## two states where it changed. Proxies jump when their drawn time gets there, the owner when it reconciles to it
## (as Source's EF_NOINTERP or Photon Fusion's Teleport).
var net_teleports: int = 0

var _root: Node
## Loaded as part of a saved scene (it had an owner when it entered); a node a spawner or script made has none then.
var _from_saved_scene: bool = false
var _calls: MpCalls
var _motion: MpProxyMotion
var _prediction: MpPrediction
var _smoother: MpCorrectionSmoother
## Server: teleports so far; the next published state carries them (so never with an older pose).
var _teleports: int = 0
## Server: the teleports the lag compensation history already has.
var _recorded_teleports: int = 0
## Owner: the teleports it already drew at once, and the last reconciliation it looked at.
var _owner_teleports: int = 0
var _owner_reconciled: float = 0.0
## Scenes whose saved MpSync was already compared with what this kit sends (scene path -> true).
static var _checked_scenes: Dictionary = {}
var _sender_slot: int = -1
## Inside an mp_sv_* call from a client: the server time that client was seeing (0 = unknown).
var _call_view: float = 0.0
## Server, solo, and proxies without smoothing: the pose at the last physics tick, and how fast it moved since the one
## before (motion_velocity).
var _tick_pos := Vector3.INF
var _tick_velocity := Vector3.ZERO


## The MpActor child of `node`, or null.
static func of(node: Node) -> MpActor:
	if node == null:
		return null
	for child in node.get_children():
		if child is MpActor:
			return child as MpActor
	return null


func _enter_tree() -> void:
	_editor_rebuild()


func _exit_tree() -> void:
	if not Engine.is_editor_hint() and _root:
		MpLagComp.forget(_root)


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		return
	_root = get_parent()
	_from_saved_scene = _root.owner != null
	_calls = MpCalls.new(_root)
	process_priority = 10000
	MpAuthority.claim_server(_root)
	if get_node_or_null(SYNC_NAME) == null and not sync_entries().is_empty():
		push_error("MpActor on '%s': no %s child. Open the scene in the editor and save it (the editor builds it)." % [_root.name, SYNC_NAME])
	else:
		_check_saved_sync()
	if freeze_rigid_if_proxy:
		MpAuthority.freeze_rigid_proxy(_root)
	if predict and (not _root.has_method(&"mp_move") or input() == null):
		push_error("MpActor on '%s': predict needs an MpInput next to it and mp_move(input, delta) on the parent" % _root.name)
		predict = false
	if predict:
		_prediction = MpPrediction.new(_root, input())
		_prediction.max_resim_ticks = max_resim_ticks
		var smoothing_s := float(MpBoot.user_value("correction-smoothing-s", str(correction_smoothing_s)))
		if smoothing_s > 0.0 and not is_authority():
			_smoother = MpCorrectionSmoother.new(_root)
			_smoother.time_s = smoothing_s
			_smoother.snap_distance = correction_snap_distance
			_smoother.move_position = sync_position
			_smoother.move_rotation = sync_rotation
			_prediction.smoother = _smoother
			## The drawn pose is put back to the real one before any node's _physics_process.
			get_tree().physics_frame.connect(_smoother.restore)
	_motion = MpProxyMotion.new(_root, smoothing == Smoothing.BUFFERED)
	_motion.delay_s = buffer_delay_s
	_motion.adaptive = adaptive_buffer
	_motion.late_tolerance = late_tolerance
	_motion.follow_speed = follow_speed
	_motion.move_position = sync_position
	_motion.move_rotation = sync_rotation
	if is_authority():
		_publish_pose()
	elif uses_net_pose() and not (predict and is_local()):
		## A proxy is drawn every frame here (MpProxyMotion, in _process): the engine's physics interpolation would
		## fight it. The owner's predicted node moves in physics ticks and keeps it (see GUIDE 6.2).
		_root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if not is_authority() and uses_net_pose() and net_stamp > 0.0:
		_motion.snap(net_position, net_rotation)
		if _prediction:
			_prediction.start_at(net_position)
	_owner_teleports = net_teleports


func _physics_process(delta: float) -> void:
	if is_authority() or not uses_net_pose():
		if _prediction and is_authority():
			_prediction.server_tick(delta, is_local() or not MpKit.is_networked())
		_measure_tick(delta)
		if is_authority():
			_publish_pose()
	elif _prediction and is_local():
		_prediction.owner_tick(delta, net_stamp, _motion, net_position, net_rotation)
		## It went back to a state the server teleported it in: drawn there at once.
		if _prediction.reconciled_stamp != _owner_reconciled:
			_owner_reconciled = _prediction.reconciled_stamp
			if net_teleports != _owner_teleports:
				_owner_teleports = net_teleports
				_draw_owner_jump()
		if _smoother:
			_smoother.mark_tick()
			## With the engine's physics interpolation the node is drawn between ticks: the fading correction goes
			## in each tick's pose (put back before the next tick). Without it, every frame in _process.
			if _root.is_physics_interpolated_and_enabled():
				_smoother.draw(delta)


func _process(delta: float) -> void:
	if not MpKit.is_networked() or MpKit.is_server() or not uses_net_pose():
		return
	if not (predict and is_local()):
		_motion.draw(delta, net_stamp, net_position, net_rotation, net_teleports)
	elif _smoother and not _root.is_physics_interpolated_and_enabled():
		_smoother.draw(delta)


## How fast what this node shows moves, for animation (a run clip, a jump or fall, footsteps): a Vector2 in 2D, a
## Vector3 in 3D, in the node's units per second. The same on every machine, and never the network's own motion:
##   server and solo - each physics tick's step;
##   the owner, with `predict` - its own predicted steps (mp_move's), never a server correction or a paced tick fading
##                     on screen (MpCorrectionSmoother);
##   a proxy - BUFFERED, the motion between the two server states it is drawn between now; FOLLOW, how fast it
##             chases; without smoothing, the change since the last tick.
## Zero when it stands still, and across a teleport. Read it anywhere, `_process` included: unlike the node's pose
## read frame to frame, it does not jump with physics ticks, corrections or late packets.
func motion_velocity() -> Variant:
	var velocity := _velocity()
	if _root is Node2D:
		return Vector2(velocity.x, velocity.y)
	return velocity


## How fast what this node shows moves, as one number (units per second): `motion_velocity()`'s length. For the
## usual choice: `if net.motion_speed() > 0.1:` run, else idle.
func motion_speed() -> float:
	return _velocity().length()


func _velocity() -> Vector3:
	if is_authority() or not uses_net_pose():
		return _tick_velocity
	if _prediction and is_local():
		return _prediction.step_velocity
	return _motion.velocity() if _motion else Vector3.ZERO


## True when the pose travels in net_position / net_rotation (smoothing or prediction) instead of the parent's own.
func uses_net_pose() -> bool:
	return smoothing != Smoothing.NONE or predict


## True where the rules of this node run: solo or the server.
func is_authority() -> bool:
	return MpKit.is_authority()


## Owner with prediction: how far the drawn node still is from the real one, while a correction fades (0 = none).
func correction_offset() -> float:
	return _smoother.offset() if _smoother else 0.0


## Owner with prediction: how far the last server correction moved this node (0 = the prediction was right).
func last_correction() -> float:
	return _prediction.last_correction if _prediction else 0.0


## True on the machine of the player that owns this node.
func is_local() -> bool:
	return owner_slot > 0 and owner_slot == MpKit.local_slot()


## The MpInput next to this node, or null.
func input() -> MpInput:
	for child in get_parent().get_children():
		if child is MpInput:
			return child as MpInput
	return null


## Inside an mp_sv_* call: the slot that asked (0 = the server itself). Elsewhere: -1.
func sender_slot() -> int:
	return _sender_slot


## Server: the time the owner of this node was seeing (its proxies are drawn in the past): inside an mp_sv_* call
## the caller's, else the owner's current input frame's; the present for the host's own player, solo, or unknown.
## Never ahead of now, never more than MpLagComp.HISTORY_S back.
func view_stamp() -> float:
	var now := MpNetClock.stamp()
	if not MpKit.is_networked() or not MpKit.is_server():
		return now
	var view := _call_view
	if view <= 0.0 and not is_local():
		var keys := input()
		if keys and keys.current_frame():
			view = keys.current_frame().view
	return MpLagComp.clamp_view(view, now)


## Server: how far behind the present this node's owner sees the others, in seconds.
func view_lag() -> float:
	return MpNetClock.stamp() - view_stamp()


## Server: runs `body` with every other lag-compensated node moved to where this node's owner saw it (then puts
## them back). For a hitscan shot: `net.rewound(func(): return space.intersect_ray(query))`.
func rewound(body: Callable) -> Variant:
	return MpLagComp.rewind(view_stamp(), body, _root)


## Server: where `node` was when this node's owner saw it (Vector2 for 2D, Vector3 for 3D).
func seen_position_of(node: Node) -> Variant:
	return MpLagComp.position_at_like(node, view_stamp())


## Server (or solo) only: remove this node everywhere. Only for nodes a spawner made (the spawner removes them on every
## peer, late joiners never get them). A node of the world scene cannot be despawned: a late joiner loads the scene
## and would still have it; hide it instead (sync `visible`) or spawn it.
func despawn() -> void:
	if not MpKit.is_authority():
		push_warning("MpActor '%s': despawn() only runs on the server" % _root.name)
		return
	## Saved in the world scene = it had an owner when it loaded (an owner a script sets later does not count).
	if _from_saved_scene:
		push_error("MpActor '%s': despawn() on a node of the world scene; hide it (sync visible) or spawn it" % _root.name)
		return
	_root.queue_free()


## The tick's step of the parent (server, solo, or a proxy without smoothing): motion_velocity.
func _measure_tick(delta: float) -> void:
	var pos := MpProxyMotion.position_of(_root)
	if _tick_pos == Vector3.INF or delta <= 0.0:
		_tick_velocity = Vector3.ZERO
	else:
		_tick_velocity = (pos - _tick_pos) / delta
	_tick_pos = pos


## After a teleport or respawn. On the server, right after moving the node: the teleport travels with the state,
## so every client jumps there instead of sliding (proxies when their drawn time gets there, the owner when it
## reconciles to it). On a client (from an mp_all_* call): jump to the server's latest pose now.
func snap() -> void:
	if is_authority():
		## Counted now, sent with the next published pose (the moved one).
		_teleports += 1
		## No step across it: motion_velocity starts again from here.
		_tick_pos = Vector3.INF
		if _root and _root.is_physics_interpolated_and_enabled():
			_root.reset_physics_interpolation()
	elif _prediction and is_local():
		_draw_owner_jump()
		if _smoother:
			_smoother.jump_next()
	elif _motion:
		_motion.snap(net_position, net_rotation)


## Ask the server to run mp_sv_<action>(args...) on this node. Solo and the server run it at once.
func to_server(action: StringName, ...args: Array) -> void:
	if MpKit.is_authority():
		_run_sv(action, args, MpKit.local_slot())
		return
	if callers == Callers.OWNER and not is_local():
		push_warning("MpActor '%s': to_server(%s) from a peer that does not own it (callers = OWNER)" % [_root.name, action])
		return
	## With what this player sees, so the server can rewind the others to it (lag compensation).
	rpc_server_call_seen.rpc_id(MpAuthority.SERVER_PEER, action, args, MpNetClock.view_stamp())


## Server only: run mp_all_<action>(args...) here and on every peer that has this node.
func to_all(action: StringName, ...args: Array) -> void:
	if not MpKit.is_authority():
		push_warning("MpActor '%s': to_all(%s) only runs on the server" % [_root.name, action])
		return
	_calls.run(ALL_PREFIX, action, args)
	if not MpKit.is_networked():
		return
	for peer_id in multiplayer.get_peers():
		if reaches(peer_id):
			rpc_all_call.rpc_id(peer_id, action, args)


## Server: true when `peer_id` has this node now, so a call to it lands: shown to it by the spawner (per-peer
## visibility), or, for a node every peer has (public visibility), once that peer's world is loaded.
func reaches(peer_id: int) -> bool:
	var sync := get_node_or_null(SYNC_NAME) as MultiplayerSynchronizer
	if sync and not sync.public_visibility:
		return sync.get_visibility_for(peer_id)
	return MpKit.is_peer_world_ready(peer_id)


## What the synchronizer sends, from the inspector (MpActorSync builds it).
func sync_entries() -> PackedStringArray:
	return MpActorSync.entries(self)


@rpc("any_peer", "call_remote", "reliable")
func rpc_server_call(action: StringName, args: Array) -> void:
	if not multiplayer.is_server():
		return
	var slot := MpKit.slot_for_peer(multiplayer.get_remote_sender_id())
	if slot <= 0 or (callers == Callers.OWNER and slot != owner_slot):
		return
	if var_to_bytes(args).size() > MAX_ARGS_BYTES or not server_calls.allow(multiplayer.get_remote_sender_id()):
		return
	_run_sv(action, args, slot)


## to_server with the server time the caller was seeing (lag compensation reads it as view_stamp()).
@rpc("any_peer", "call_remote", "reliable")
func rpc_server_call_seen(action: StringName, args: Array, view: float) -> void:
	_call_view = view if is_finite(view) else 0.0
	rpc_server_call(action, args)
	_call_view = 0.0


@rpc("authority", "call_remote", "reliable")
func rpc_all_call(action: StringName, args: Array) -> void:
	_calls.run(ALL_PREFIX, action, args)


func _run_sv(action: StringName, args: Array, slot: int) -> void:
	_sender_slot = slot
	_calls.run(SV_PREFIX, action, args)
	_sender_slot = -1


## Server: the stamp and pose the synchronizer sends this tick.
func _publish_pose() -> void:
	net_stamp = MpNetClock.stamp()
	net_position = MpProxyMotion.position_of(_root)
	net_rotation = MpProxyMotion.rotation_of(_root)
	net_teleports = _teleports
	if lag_compensate and MpKit.is_networked() and sync_position:
		MpLagComp.record(_root, net_stamp, _recorded_teleports != _teleports)
		_recorded_teleports = _teleports


## Owner: draw the node where it really is now (a teleport), with no correction fading and no engine interpolation.
func _draw_owner_jump() -> void:
	if _smoother:
		_smoother.jump()
	elif _root.is_physics_interpolated_and_enabled():
		_root.reset_physics_interpolation()


## Once per scene: a saved MpSync that no longer matches what this kit sends (an older kit, or the inspector changed
## outside the editor) still runs, but without what is missing; say how to fix it.
func _check_saved_sync() -> void:
	var scene := _root.scene_file_path if _root.scene_file_path != "" else (owner.scene_file_path if owner else "")
	if scene == "" or _checked_scenes.has(scene):
		return
	_checked_scenes[scene] = true
	var sync := get_node_or_null(SYNC_NAME) as MultiplayerSynchronizer
	if sync and not MpSyncBuilder.matches(sync.replication_config, sync_entries(), MpActorSync.spawn_only(self)):
		push_warning("MpActor on '%s' (%s): its saved %s is out of date for this MpKit. Open the scene in the editor and save it." % [_root.name, scene, SYNC_NAME])


func _editor_rebuild() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		_rebuild_sync.call_deferred()


func _rebuild_sync() -> void:
	MpActorSync.rebuild(self)


func _get_configuration_warnings() -> PackedStringArray:
	if get_parent() == null or owner == null:
		return PackedStringArray(["MpActor goes inside the node the network shares (not as a scene root)."])
	if get_node_or_null(SYNC_NAME) == null:
		return PackedStringArray(["Save the scene: the %s child is built in the editor." % SYNC_NAME])
	if predict and not get_parent().has_method(&"mp_move"):
		return PackedStringArray(["Predict is on: the parent needs func mp_move(input: MpInput, delta: float)."])
	return PackedStringArray()
