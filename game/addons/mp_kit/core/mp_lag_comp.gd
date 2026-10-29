class_name MpLagComp
extends RefCounted

## Lag compensation (as Valve's Source engine does it): the server keeps the last HISTORY_S of every actor's pose,
## stamped with its simulation time, so a shot can be checked against where the shooter SAW the others, not
## where they are by the time the shot arrives. MpActor records its parent each tick (lag_compensate) and offers
## `rewound(callable)` / `seen_position_of(node)`; the view time comes from the shooter (MpInputFrame.view, or the
## to_server call). Server only; pure bookkeeping, no network. Not: hit rules (the game's).

## Seconds of history kept (also the most a shot can be rewound: a slower view is clamped to it, as sv_maxunlag).
const HISTORY_S := 1.0

## Off: rewound() runs the callable on the present and seen_position_of() gives the present (`--lag-comp=off`).
static var enabled: bool = true
static var _flag_read: bool = false
## instance id -> Track
static var _tracks: Dictionary = {}


## Server: the pose of `node` at simulation time `stamp` (this tick's). `teleported`: it got there by a teleport,
## so a rewind between the last pose and this one holds the last (as the shooter saw it: proxies never slide across).
static func record(node: Node, stamp: float, teleported: bool = false) -> void:
	var id := node.get_instance_id()
	var track: Track = _tracks.get(id)
	if track == null:
		track = Track.new()
		track.node = node
		_tracks[id] = track
	track.add(stamp, MpProxyMotion.position_of(node), MpProxyMotion.rotation_of(node), teleported)


static func forget(node: Node) -> void:
	_tracks.erase(node.get_instance_id())


static func clear() -> void:
	_tracks.clear()


static func is_enabled() -> bool:
	if not _flag_read:
		_flag_read = true
		if MpBoot.user_value("lag-comp", "on") == "off":
			enabled = false
	return enabled


## A view time made safe: never ahead of now, never further back than HISTORY_S.
static func clamp_view(view: float, now: float) -> float:
	if view <= 0.0:
		return now
	return clampf(view, now - HISTORY_S, now)


## Where `node` was at `stamp` (its present pose if it has no history then).
static func position_at(node: Node, stamp: float) -> Vector3:
	var track: Track = _tracks.get(node.get_instance_id())
	if track == null or not is_enabled():
		return MpProxyMotion.position_of(node)
	return track.sample(stamp)[0]


## position_at as the node's own type: Vector2 for a 2D node, Vector3 otherwise.
static func position_at_like(node: Node, stamp: float) -> Variant:
	var p := MpLagComp.position_at(node, stamp)
	return Vector2(p.x, p.y) if node is Node2D else p


## Moves every recorded node except `skip` to where it was at `stamp`, runs `body`, and puts them back. Physics
## queries inside `body` see the moved bodies.
static func rewind(stamp: float, body: Callable, skip: Node = null) -> Variant:
	if not is_enabled():
		return body.call()
	var moved: Array = []
	for id in _tracks.keys():
		var track: Track = _tracks[id]
		if not is_instance_valid(track.node):
			_tracks.erase(id)
			continue
		if track.node == skip or not track.node.is_inside_tree():
			continue
		var pose := track.sample(stamp)
		moved.append([track.node, MpProxyMotion.position_of(track.node), MpProxyMotion.rotation_of(track.node)])
		MpProxyMotion.set_position(track.node, pose[0])
		MpProxyMotion.set_rotation(track.node, pose[1])
		MpLagComp._sync_body(track.node)
	var result: Variant = body.call()
	for row in moved:
		MpProxyMotion.set_position(row[0], row[1])
		MpProxyMotion.set_rotation(row[0], row[2])
		MpLagComp._sync_body(row[0])
	return result


## A moved physics body tells the physics server at once, so a raycast in the same frame sees it.
static func _sync_body(node: Node) -> void:
	if node is Node2D:
		(node as Node2D).force_update_transform()
		if node is Area2D:
			PhysicsServer2D.area_set_transform((node as Area2D).get_rid(), (node as Node2D).global_transform)
		elif node is PhysicsBody2D:
			PhysicsServer2D.body_set_state((node as PhysicsBody2D).get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, (node as Node2D).global_transform)
	elif node is Node3D:
		(node as Node3D).force_update_transform()
		if node is Area3D:
			PhysicsServer3D.area_set_transform((node as Area3D).get_rid(), (node as Node3D).global_transform)
		elif node is PhysicsBody3D:
			PhysicsServer3D.body_set_state((node as PhysicsBody3D).get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, (node as Node3D).global_transform)


## One node's recent poses, oldest first.
class Track:
	var node: Node
	var stamps := PackedFloat64Array()
	var positions := PackedVector3Array()
	var rotations: Array[Quaternion] = []
	## 1 where the pose was reached by a teleport.
	var teleports := PackedByteArray()

	func add(stamp: float, position: Vector3, rotation: Quaternion, teleported: bool = false) -> void:
		if not stamps.is_empty() and stamp <= stamps[stamps.size() - 1]:
			return
		stamps.append(stamp)
		positions.append(position)
		rotations.append(rotation)
		teleports.append(1 if teleported else 0)
		while stamps.size() > 1 and stamp - stamps[0] > MpLagComp.HISTORY_S:
			stamps.remove_at(0)
			positions.remove_at(0)
			rotations.remove_at(0)
			teleports.remove_at(0)

	## [position, rotation] at `stamp`, between the two poses around it (the ends outside the history).
	func sample(stamp: float) -> Array:
		var last := stamps.size() - 1
		if last < 0:
			return [MpProxyMotion.position_of(node), MpProxyMotion.rotation_of(node)]
		if stamp <= stamps[0]:
			return [positions[0], rotations[0]]
		if stamp >= stamps[last]:
			return [positions[last], rotations[last]]
		var i := last - 1
		while i > 0 and stamps[i] > stamp:
			i -= 1
		if teleports[i + 1] == 1:
			return [positions[i], rotations[i]]
		var t := (stamp - stamps[i]) / maxf(stamps[i + 1] - stamps[i], 0.0001)
		return [positions[i].lerp(positions[i + 1], t), rotations[i].slerp(rotations[i + 1], t)]
