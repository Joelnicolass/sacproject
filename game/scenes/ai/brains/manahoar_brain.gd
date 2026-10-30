class_name ManahoarBrain
extends Node

## The brain of a Manahoar: it goes to the group of its side that lacks the most mana. Each own
## group is worth (2 * max mana - mana) (twice that if a wizard is in it), weighed by the distance
## from the Manahoar to where the group is going (1 within 10 m, falling linearly to 0 at 3620 m,
## retail; the beta 256 m), and divided by the number of Manahoars that are ready in it when there
## is more than one. In the best group the member that lacks most (2 * max - current) is guarded
## (AiOrder.GUARD: stay near it and feed it). If there is no group worth going to, it thinks like
## any creature (t4oBrain).

## A group within this of the Manahoar weighs 1.
const NEAR_M := 10.0
## Retail cutoff and scale: 3620 m, 0.00027700831.
const CUTOFF_M := 3620.0
const SCALE := 0.00027700831

@export var perception: AiPerception
@export var groups: AiGroups
@export var creature_brain: CreatureBrain
@export var port: AiCommandPort


## Returns true when it handled the case.
func think(t: AiTrack, task_kind: AiTask.Kind, record: AiRecord) -> bool:
	var best_group: AiGroup
	var best_value := 0.0
	for group: AiGroup in groups.list(AiTrack.Relation.OWN):
		var v := float(2 * group.max_mana_sum - group.mana_sum)
		if group.has_wizard:
			v += v
		var d := t.extrap_pos.distance_to(group.predicted)
		var w := 0.0
		if d <= NEAR_M:
			w = 1.0
		elif d < CUTOFF_M:
			w = (CUTOFF_M - d) * SCALE
		v *= w
		if group.ready_count > 1:
			v = AiField.safediv(v, float(group.ready_count))
		if best_value < v:
			best_value = v
			best_group = group
	if best_group != null:
		var best_member: AiTrack
		var best_deficit := 0
		for m: AiTrack in best_group.members:
			if m.is_inert() or not m.is_valid():
				continue
			var pair := AiBody.mana_pair(m)
			var deficit := 2 * pair.y - pair.x
			if best_deficit < deficit:
				best_deficit = deficit
				best_member = m
		if best_member != null:
			port.orders.order_if_changed(t, AiCommandPort.AiOrder.GUARD, best_member, null)
			return true
	return creature_brain.think(t, task_kind, record)
