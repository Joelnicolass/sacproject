class_name AiBelief
extends Node

## What the AI believes of a body it knows: where it is, how much health and mana it has. A body its side sees now is read
## live; one it does not see keeps what was seen last (the place where it was, one step of its last velocity ahead, its health and
## mana of that moment). With `perfect_information` every body is read live, and each read of an unseen body is counted.
## It does not look (Vision, SightIntake) nor choose which bodies the AI knows (AiPerception).
## Ref: shiny.d:1024-1038 updateBase, 1710-1711 and 2715-2722 healthPair (the original reads everything live).

## Set by AiSide from the difficulty (AiDifficulty.perfect_information).
@export var perfect_information := false

## Reads of the real position, health or mana of a body of another side its side did not see (perfect information only).
var unseen_reads := 0


## The side `side` sees `t` now: its own and its allies' bodies, structures and souls always (structures stand still and are marked
## for good once seen; souls are not gated either); a body of another side while the side's Vision keeps it in mind (the rule the
## creatures pick their targets by). ## Ref: shiny.d:583.
static func sees(t: AiTrack, side: int) -> bool:
	if t == null or t.relation == AiTrack.Relation.OWN or t.relation == AiTrack.Relation.ALLY or not t.is_body():
		return true
	return VisionSides.sees(side, t.node)


## The AI may read the real state of `t`: perfect information, or the side sees it.
func knows_live(t: AiTrack, side: int) -> bool:
	return perfect_information or sees(t, side)


## Where the AI believes `t` is: the real position when it knows it live, else where it was seen last.
func pos_of(t: AiTrack, side: int) -> Vector3:
	if not knows_live(t, side):
		return t.cur_pos
	_count_read(t, side)
	return t.node.global_position


## (current, maximum) health the AI believes `t` has.
func health_of(t: AiTrack, side: int) -> Vector2i:
	if not knows_live(t, side):
		return t.seen_health
	_count_read(t, side)
	return AiBody.health_pair(t.node)


## (current, maximum) mana the AI believes `t` has.
func mana_of(t: AiTrack, side: int) -> Vector2i:
	if not knows_live(t, side):
		return t.seen_mana
	_count_read(t, side)
	return AiBody.mana_pair(t)


func _count_read(t: AiTrack, side: int) -> void:
	if perfect_information and t.is_body() and t.relation != AiTrack.Relation.OWN and t.relation != AiTrack.Relation.ALLY and not sees(t, side):
		unseen_reads += 1


## What the side sees of `t` now becomes what it believes of it (its health and mana of this moment).
static func snapshot(t: AiTrack) -> void:
	t.seen_health = AiBody.health_pair(t.node)
	t.seen_mana = AiBody.mana_pair(t)


## Own and seen bodies follow the real position, `dt` ticks after the last run. A seen body that the side does not see now (and no
## perfect information) stays where it was seen last, one step of its last velocity ahead; seen again, it does not jump from there.
## Ref: shiny.d:1024-1038 updateBase (it follows own bodies and the ones flagged «seen», 1025).
func follow(t: AiTrack, dt: int, side: int) -> void:
	if t.relation != AiTrack.Relation.OWN and not t.seen:
		return
	t.age += dt
	if not knows_live(t, side):
		t.frozen = true
		t.extrap_pos = t.cur_pos + t.velocity
		return
	var p := t.node.global_position
	if t.frozen:
		## seen again: it does not jump from where it was last seen
		t.frozen = false
		t.prev_pos = p
	t.cur_pos = p
	t.velocity = p - t.prev_pos
	if dt != 0:
		t.velocity /= float(dt)
	t.prev_pos = p
	t.extrap_pos = p + t.velocity
