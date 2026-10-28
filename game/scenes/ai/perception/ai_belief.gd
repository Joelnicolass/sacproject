class_name AiBelief
extends Node

## What the AI believes of a body it knows: where it is, how much health and mana it has. A body its
## side sees now is read live; one it does not see keeps what was seen last (the place where it was,
## one step of its last velocity ahead, its health and mana of that moment; nothing if it was never
## seen). With Knowledge.SIGHT_AND_MAP it also knows where the bodies on the minimap are (within
## `map_sight_m` of its wizard, and every enemy wizard), never their health or mana. No difficulty
## reads more; a snapshot of an unseen body is counted in `unseen_reads` (0 is the rule,
## ai_knowledge_cases checks it). It does not look (Vision, SightIntake) nor choose which bodies the
## AI knows (AiPerception).
## Ref: shiny.d:1024-1038 updateBase, 1710-1711 and 2715-2722 healthPair (the original reads
## everything live).

## What the AI may know of what its side does not see (AiSide.setup: the difficulty's; look_from).
var knowledge: AiDifficulty.Knowledge = AiDifficulty.Knowledge.SIGHT
## The flat radius of the minimap around `map_center` (AiSenses.map_sight_m).
var map_sight_m := 216.0
## The own wizard: the minimap is drawn around him.
var map_center: Node3D

## Snapshots of the health and mana of a body of another side its side did not see (must stay 0: no
## difficulty cheats).
var unseen_reads := 0


## What the AI may know, and around whom the minimap is drawn (AiSide.setup, the suite).
func look_from(center: Node3D, p_knowledge: AiDifficulty.Knowledge, sight_m: float) -> void:
	map_center = center
	knowledge = p_knowledge
	map_sight_m = sight_m


## The side `side` sees `t` now: its own and its allies' bodies, structures and souls always
## (structures stand still and are marked for good once seen; souls are not gated either); a body of
## another side while the side's Vision keeps it in mind (the rule the creatures pick their targets
## by).
## Ref: shiny.d:583
static func sees(t: AiTrack, side: int) -> bool:
	if (
		t == null
		or t.relation == AiTrack.Relation.OWN
		or t.relation == AiTrack.Relation.ALLY
		or not t.is_body()
	):
		return true
	return VisionSides.sees(side, t.node)


## The AI may read the real health and mana of `t` (and aim at it): the side sees it.
func knows_live(t: AiTrack, side: int) -> bool:
	return sees(t, side)


## The AI may read where `t` is: the side sees it, or it is on the minimap (SIGHT_AND_MAP).
func knows_where(t: AiTrack, side: int) -> bool:
	return sees(t, side) or on_map(t)


## With SIGHT_AND_MAP, `t` shows on the minimap: an enemy wizard anywhere (the arrow), any other
## body within map_sight_m.
func on_map(t: AiTrack) -> bool:
	if (
		knowledge != AiDifficulty.Knowledge.SIGHT_AND_MAP
		or t == null
		or not t.is_valid()
		or not t.is_body()
	):
		return false
	if t.kind == AiTrack.Kind.WIZARD and t.relation == AiTrack.Relation.ENEMY:
		return AiBody.shows_on_map(t.node)
	return within_map(t.node)


## With SIGHT_AND_MAP, `node` is a body the minimap draws within map_sight_m (flat) of the own
## wizard.
func within_map(node: Node3D) -> bool:
	if (
		knowledge != AiDifficulty.Knowledge.SIGHT_AND_MAP
		or map_center == null
		or not is_instance_valid(map_center)
	):
		return false
	var at := map_center.global_position
	var p := node.global_position
	return (
		Vector2(p.x - at.x, p.z - at.z).length_squared() <= map_sight_m * map_sight_m
		and AiBody.shows_on_map(node)
	)


## Where the AI believes `t` is: the real position when it knows where it is, else where it was seen
## last.
func pos_of(t: AiTrack, side: int) -> Vector3:
	return t.node.global_position if knows_where(t, side) else t.cur_pos


## (current, maximum) health the AI believes `t` has: the real one while the side sees it, else the
## one seen last.
func health_of(t: AiTrack, side: int) -> Vector2i:
	return AiBody.health_pair(t.node) if knows_live(t, side) else t.seen_health


## (current, maximum) mana the AI believes `t` has: the real one while the side sees it, else the
## one seen last.
func mana_of(t: AiTrack, side: int) -> Vector2i:
	return AiBody.mana_pair(t) if knows_live(t, side) else t.seen_mana


## What the side sees of `t` now becomes what it believes of it (its health and mana of this
## moment). A snapshot of a body of another side the side does not see is a cheat: it is counted in
## `unseen_reads` (the callers only take one of a seen body).
func snapshot(t: AiTrack, side: int) -> void:
	if not sees(t, side):
		unseen_reads += 1
	t.seen_health = AiBody.health_pair(t.node)
	t.seen_mana = AiBody.mana_pair(t)


## Own and seen bodies follow the real position, `dt` ticks after the last run, while the AI knows
## where they are (seen, or on the minimap). A seen body it does not know where is now stays where
## it was seen last, one step of its last velocity ahead; known again, it does not jump from there.
## Ref: shiny.d:1024-1038 updateBase (it follows own bodies and the ones flagged «seen», 1025)
func follow(t: AiTrack, dt: int, side: int) -> void:
	if t.relation != AiTrack.Relation.OWN and not t.seen:
		return
	t.age += dt
	if not knows_where(t, side):
		t.frozen = true
		t.extrap_pos = t.cur_pos + t.velocity
		return
	var p := t.node.global_position
	if t.frozen:
		# known again: it does not jump from where it was last seen
		t.frozen = false
		t.prev_pos = p
	t.cur_pos = p
	t.velocity = p - t.prev_pos
	if dt != 0:
		t.velocity /= float(dt)
	t.prev_pos = p
	t.extrap_pos = p + t.velocity
