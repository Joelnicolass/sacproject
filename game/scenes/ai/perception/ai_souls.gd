class_name AiSouls
extends Node

## The souls the AI may go for: the one that weighs most near a point, to take by touching it or to convert, and a track for each so
## the cast queue and the orders aim at a soul like at any other target. Souls are not gated by sight (the original follows them
## all). It does not cast nor walk (Brain, Port).
## Ref: shiny.d:1358-1369 and 583 (souls ungated), 3005-3024 findBestNear (retail 0x485490).

## Above this many soul tracks the ones whose soul is gone are dropped.
const PRUNE_ABOVE := 64

var _soul_tracks: Dictionary = {}


## Drops the tracks of souls that no longer exist, once there are many.
func prune() -> void:
	if _soul_tracks.size() > PRUNE_ABOVE:
		for id in _soul_tracks.keys():
			if not (_soul_tracks[id] as AiTrack).is_valid():
				_soul_tracks.erase(id)


## A track for a soul. Kind NONE: it only carries the node and where it is.
func soul_track(soul: Node3D) -> AiTrack:
	var id := soul.get_instance_id()
	var t: AiTrack = _soul_tracks.get(id)
	if t == null:
		t = AiTrack.new()
		t.kind = AiTrack.Kind.NONE
		t.node = soul
		t.id = id
		t.origin = &"soul"
		_soul_tracks[id] = t
	t.cur_pos = soul.global_position
	t.extrap_pos = t.cur_pos
	return t


## The soul within `radius` of `pos` that weighs most for side `side` (1 on top of it, falling linearly to 0 at `radius`; strict
## argmax, the first one wins a tie), in the same pathfinder region as `pos`. `pickup` asks for the souls the side can take by
## touching them (the wizard walks onto them); else for the ones it cannot but can convert (the red ones in the open, with the rules
## of the Convert cast, so the AI does not ask for what the game would answer «Blanco inválido»).
func find_best_near(pos: Vector3, radius: float, pickup: bool, side: int, system: SacrificeSystem, service: NavService) -> AiTrack:
	var best := 0.0
	var best_soul: Node3D
	for node in get_tree().get_nodes_in_group(Soul.GROUP):
		var soul := node as Soul
		if soul == null or not is_instance_valid(soul) or soul.is_queued_for_deletion():
			continue
		if pickup:
			if not soul.can_be_collected_by(side):
				continue
		elif system == null or not system.convert_status(side, soul).is_empty():
			continue
		if service != null and service.is_ready() and not service.same_region(pos, soul.global_position):
			continue
		var d := pos.distance_to(soul.global_position)
		var w := 0.0
		if d <= 0.0:
			w = 1.0
		elif d < radius:
			w = AiField.safediv(radius - d, radius)
		if best < w:
			best = w
			best_soul = soul
	return soul_track(best_soul) if best_soul != null else null
