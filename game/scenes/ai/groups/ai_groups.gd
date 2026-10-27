class_name AiGroups
extends Node

## Groups of nearby bodies per category. Every replan (k4) the groups are thrown away and made again:
## the bodies of a category sorted by worth (best first), the first starts a group and takes in each next one that lies
## within 30*min(1+0.1n, 1.8) m of the center, until none does. Every 6 ticks (k3) each
## group refreshes its center, its aggregates and drops its dead. Wizards and creatures go in; souls (slot-5 groups)
## are not tracked in 024c («aprox.»).
## Ref: RFC-024 §3.1 `AiGroups`; shiny.d:1479-1580 slot-4 groups, 1563-1621 `groupRefresh4`, 1702-1760 `canAccept`/`formGroups4`; shiny.d:1711-1735, 1740-1778

@export var perception: AiPerception

## groups[category] = Array[AiGroup]
var groups: Array = [[], [], [], []]


func list(category: int) -> Array:
	return groups[category]


## recycleGroups + formGroups4 of every category; the bodies come sorted by AiPerception.sort_bodies().
## Ref: shiny.d:1305-1330
func rebuild() -> void:
	for k in 4:
		groups[k] = _form(perception.bodies(k))


func _form(bodies: Array) -> Array:
	var pending: Array[AiTrack] = []
	## the live position while the side knows where it is (seen, or on the minimap), else the last seen (024e, f6); read once per
	## body here (nothing moves during the rebuild), not once per test.
	var at: Array[Vector3] = []
	for t: AiTrack in bodies:
		pending.append(t)
		at.append(perception.pos_of(t) if perception != null else t.node.global_position)
	var out: Array = []
	var crowd := perception.play.tactics.crowd
	while not pending.is_empty():
		var first: AiTrack = pending.pop_front()
		at.pop_front()
		var group := AiGroup.new()
		group.prio = 0
		_add(group, first)
		## the center of the ACTIVE members, summed in the order they joined (the sums the original recomputes after each take, in the same order)
		var sum := Vector3.ZERO
		var active := 0.0
		if first.fights:
			sum += first.cur_pos
			active += 1.0
		var center := first.cur_pos
		var taken := true
		while taken:
			taken = false
			for i in pending.size():
				if AiField.can_accept(group.count, center.distance_squared_to(at[i]), crowd):
					var candidate: AiTrack = pending[i]
					pending.remove_at(i)
					at.remove_at(i)
					_add(group, candidate)
					if candidate.fights:
						sum += candidate.cur_pos
						active += 1.0
					center = sum / active if active > 0.0 else group.center
					taken = true
					break
		refresh_group(group)
		out.append(group)
	return out


func _add(group: AiGroup, t: AiTrack) -> void:
	group.members.append(t)
	group.count += 1
	t.group = group


## updateGroups: every group refreshes.
## Ref: shiny.d:1300-1303
func refresh() -> void:
	for k in 4:
		for group: AiGroup in groups[k]:
			refresh_group(group)


## groupRefresh4.
## Ref: shiny.d:1563-1621
func refresh_group(group: AiGroup) -> void:
	group.avg_vel = Vector3.ZERO
	group.prev_center = group.center
	group.center = Vector3.ZERO
	var sum_sq := Vector3.ZERO
	var count_f := 0.0
	group.count = 0
	group.has_fighter = false
	group.has_wizard = false
	var alive: Array[AiTrack] = []
	for t in group.members:
		if not alive(t):
			t.group = null
			continue
		alive.append(t)
		group.count += 1
		group.has_fighter = group.has_fighter or t.fights
		group.has_wizard = group.has_wizard or t.is_wizard()
		if t.fights:
			count_f += 1.0
			group.avg_vel += t.velocity
			group.center += t.cur_pos
			sum_sq += Vector3(t.cur_pos.x * t.cur_pos.x, t.cur_pos.y * t.cur_pos.y, t.cur_pos.z * t.cur_pos.z)
	group.members = alive
	if count_f != 0.0:
		var inv := 1.0 / count_f
		group.avg_vel *= inv
		group.center *= inv
		group.stddev = Vector3(
			sqrt(absf(sum_sq.x * inv - group.center.x * group.center.x)),
			sqrt(absf(sum_sq.y * inv - group.center.y * group.center.y)),
			sqrt(absf(sum_sq.z * inv - group.center.z * group.center.z)))
	group.predicted = group.center + group.avg_vel
	## the aggregates of the slot-4 tail: members with a status only.
	## Ref: shiny.d:1604-1620
	group.acc = AiRater.new_acc()
	group.mana_sum = 0
	group.max_mana_sum = 0
	group.health_sum = 0
	group.health_sum2 = 0
	group.ready_count = 0
	group.souls_sum = 0
	for t in group.members:
		if t.is_inert():
			continue
		var mana := perception.mana_of(t) if perception != null else AiBody.mana_pair(t)
		group.mana_sum += mana.x
		group.max_mana_sum += mana.y
		var type: Variant = t.node.get("type")
		group.health_sum += (type as CreatureType).health if type != null else 1500
		group.health_sum2 += (perception.health_of(t) if perception != null else AiBody.health_pair(t.node)).x
		AiRater.combine(group.acc, 1.0, t.acc, 1.0)
		if t.ready:
			group.ready_count += 1
		var worth := souls_pair(t)
		group.souls_sum += worth.x + worth.y


static func alive(t: AiTrack) -> bool:
	if not t.is_valid():
		return false
	if t.kind != AiTrack.Kind.WIZARD and AiBody.is_dead(t.node):
		return false
	return true


## node vtbl[21]: (soul worth, 0) of a creature; a wizard's snapshot (mana 0, souls).
## Ref: shiny.d:1465-1474
static func souls_pair(t: AiTrack) -> Vector2i:
	match t.kind:
		AiTrack.Kind.CREATURE, AiTrack.Kind.MANAHOAR:
			## A track whose body was freed this tick (perception drops it on its next pass) has no worth.
			if t.node == null or not is_instance_valid(t.node):
				return Vector2i.ZERO
			var type: Variant = t.node.get("type")
			return Vector2i(int((type as CreatureType).souls) if type != null else 0, 0)
		AiTrack.Kind.WIZARD:
			return Vector2i(t.mana_snap, t.souls_snap)
	return Vector2i.ZERO
