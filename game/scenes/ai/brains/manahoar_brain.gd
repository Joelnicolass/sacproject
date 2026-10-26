class_name ManahoarBrain
extends Node

## The brain of a Manahoar (RFC-024 §3.1 `ManahoarBrain`; shiny.d:2572-2608 `mahoBrain`, 0x487ae0): it goes to the group of its
## side that lacks the most mana. Each own group is worth (2 * max mana - mana) (twice that if a wizard is in it),
## weighed by the distance from the Manahoar to where the group is going (1 within 10 m, falling linearly to 0 at 3620 m, retail;
## the beta 256 m), and divided by the number of Manahoars that are ready in it when there is more than one. In the best group the
## member that lacks most (2 * max - current) is guarded (AiOrder.GUARD: stay near it and feed it). If there is no group worth going
## to, it thinks like any creature (t4oBrain).

@export var perception: AiPerception
@export var groups: AiGroups
@export var creature_brain: CreatureBrain
@export var port: AiCommandPort

## Retail cutoff and scale (shiny.d:2581-2582): 3620 m, 0.00027700831.
const CUTOFF_M := 3620.0
const SCALE := 0.00027700831


func think(t: AiTrack, task_kind: AiTask.Kind, record: AiRecord) -> int:
	var best_group: AiGroup
	var best_value := 0.0
	for group: AiGroup in groups.list(0):
		var v := float(2 * group.max_mana_sum - group.mana_sum)
		if group.has_wizard:
			v += v
		var d := t.extrap_pos.distance_to(group.predicted)
		var w := 0.0
		if d <= 10.0:
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
			port.order_if_changed(t, AiCommandPort.AiOrder.GUARD, best_member, null)
			return 1
	return creature_brain.think(t, task_kind, record)
