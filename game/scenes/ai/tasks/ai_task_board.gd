class_name AiTaskBoard
extends Node

## The board of tasks (RFC-024 §3.1 `AiTaskBoard`; shiny.d:2096-2346 replan and claim, 2350-2440 the order bridge, 3380-3427
## `recordUpdate`): every 60 ticks each task makes its records (`replan`), then in the order capture, guard, idle (the
## order of its children) the free creatures are handed to them; every 12 ticks each record updates: the brains of its
## members think (a clustered record) or, with a wizard as leader, the rest follow the wizard. Each brain gets the kind of the
## task (AiTask.Kind) whose record it is in.
## 024c has IdleTask and GuardTask; 024d adds CaptureTask (first: the order of its children is the order of the claim) and the
## Manahoar's own brain. Without a child task that kind of work does not happen.

## After the claim of a replan: every task with its records and members (diagnostic: the bench's decision log listens).
signal replanned(tasks: Array[AiTask])

@export var perception: AiPerception
@export var groups: AiGroups
@export var stance: AiStance
@export var profile: AiProfile
@export var wizard_brain: AiWizardBrain
@export var creature_brain: CreatureBrain
## The Manahoar thinks apart (mahoBrain); without it a Manahoar thinks like any creature.
@export var maho_brain: ManahoarBrain
@export var port: AiCommandPort

var tasks: Array[AiTask] = []
## Wall-clock counters for the report.
var records_updated := 0


func _ready() -> void:
	for child in get_children():
		if child is AiTask:
			(child as AiTask).board = self
			tasks.append(child)


## replanTasks (shiny.d:2096-2116): every task makes its records again.
func replan_tasks() -> void:
	for t: AiTrack in perception.tracks.values():
		t.record = null
	for task in tasks:
		task.replan()


## claimPass (shiny.d:2240-2260).
func claim_pass() -> void:
	var free: Array[AiTrack] = []
	for t: AiTrack in perception.bodies(0):
		if claimable(t):
			free.append(t)
	for task in tasks:
		task.claim(free)
	replanned.emit(tasks)


## ntt vtbl[19] (shiny.d:1475-1478): any own body but a Sac Doctor or a dying one. The port also leaves out a creature being
## summoned (it cannot take orders yet) and one a Sac Doctor holds.
static func claimable(t: AiTrack) -> bool:
	if not t.is_valid() or t.node.is_in_group(&"doctor"):
		return false
	if AiBody.is_dead(t.node):
		return false
	if t.node is UnitBody and (t.node as UnitBody).is_summoning():
		return false
	if t.node is UnitBody and (t.node as UnitBody).is_taken():
		return false
	return true


## updateTasks (shiny.d:1402-1411).
func update_tasks() -> void:
	for task in tasks:
		var task_kind := task.kind()
		for record in task.records.duplicate():
			record_update(record, task_kind)


## recordSetup (shiny.d:1938-1951). `capture`: a capture record (its members go to the anchor, see record_update).
func new_record(target: AiTrack, capture := false) -> AiRecord:
	var record := AiRecord.new()
	record.target = target
	record.anchor = target.cur_pos if target != null else Vector3.ZERO
	record.capture = capture
	return record


## claim (shiny.d:1964-1977): the track leaves the free list and joins the record. Returns its soul worth.
func claim_member(record: AiRecord, free: Array[AiTrack], t: AiTrack) -> float:
	free.erase(t)
	AiRater.combine(record.members_acc, 1.0, t.acc, 1.0)
	record.members.append(t)
	record.count += 1
	t.record = record
	if t.is_wizard() and record.leader == null:
		record.leader = t
	var pair := AiGroups.souls_pair(t)
	return float(pair.x + pair.y)


## Distances from `from` to the altars of `relation` (probOr, shiny.d:2012-2022).
func distances_to_altars(from: AiTrack, relation: AiTrack.Relation) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for t: AiTrack in perception.structures(relation):
		if t == from or not t.is_altar():
			continue
		out.append(from.cur_pos.distance_to(t.cur_pos))
	return out


## densityGroups (shiny.d:2042-2062) without the soul groups (slot 5): the soul worth of the enemy and neutral body groups
## near `pos`, over the most souls the side has seen.
func density(pos: Vector3, near: float, far: float) -> float:
	var acc := 0.0
	for category in [2, 3]:
		for group: AiGroup in groups.list(category):
			if group.souls_sum == 0:
				continue
			acc += AiField.ramp(pos.distance_to(group.center), near, far) * float(group.souls_sum)
	## Deviation: with no souls seen (max 0) sacengine divides 0/0 and every guard score becomes NaN, so nobody is escorted
	## (shiny.d:2062). Here it is 0.
	if perception.max_souls_seen <= 0:
		return 0.0
	return AiField.f32(AiField.safediv(acc, float(perception.max_souls_seen)))


## recordRefresh (shiny.d:1915-1952): center, spread and movement of the members.
func refresh_record(record: AiRecord) -> void:
	record.vel_acc = Vector3.ZERO
	record.prev_center = record.center
	record.center = Vector3.ZERO
	var sum_sq := Vector3.ZERO
	var count_f := 0.0
	record.count = 0
	var alive: Array[AiTrack] = []
	for t in record.members:
		if not AiGroups.alive(t):
			continue
		alive.append(t)
		record.count += 1
		if t.fights:
			count_f += 1.0
			record.vel_acc += t.velocity
			record.center += t.cur_pos
			sum_sq += Vector3(t.cur_pos.x * t.cur_pos.x, t.cur_pos.y * t.cur_pos.y, t.cur_pos.z * t.cur_pos.z)
	record.members = alive
	if record.leader != null and not alive.has(record.leader):
		record.leader = null
	if count_f != 0.0:
		var inv := 1.0 / count_f
		record.vel_acc *= inv
		record.center *= inv
		record.stddev = Vector3(
			sqrt(absf(sum_sq.x * inv - record.center.x * record.center.x)),
			sqrt(absf(sum_sq.y * inv - record.center.y * record.center.y)),
			sqrt(absf(sum_sq.z * inv - record.center.z * record.center.z)))
	record.predicted = record.center + record.vel_acc


## recordUpdate (shiny.d:3408-3447).
func record_update(record: AiRecord, task_kind: AiTask.Kind) -> void:
	if record.count == 0 and record.members.is_empty():
		return
	refresh_record(record)
	records_updated += 1
	if record.count == 0:
		return
	if record.leader != null:
		for m in record.members.duplicate():
			if m.is_inert():
				continue
			if m == record.leader:
				var dx: float = m.cur_pos.x - record.center.x
				var dz: float = m.cur_pos.z - record.center.z
				if dx * dx + dz * dz <= profile.record_near_m * profile.record_near_m:
					node_brain(m, task_kind, record)
				else:
					node_slot19(m, task_kind, record, record.center)
			else:
				port.order_pos_radius(m, AiCommandPort.AiOrder.ADVANCE, record.leader.extrap_pos, profile.follow_radius_m)
		return
	if record.capture:
		var dx: float = record.anchor.x - record.center.x
		var dz: float = record.anchor.z - record.center.z
		if dx * dx + dz * dz <= profile.record_near_m * profile.record_near_m and _proximity_trigger(record, task_kind):
			return
	for m in record.members.duplicate():
		if m.is_inert():
			continue
		node_brain(m, task_kind, record)


## proximityTrigger (shiny.d:3389-3406): a spread record sends each member to the center; a clustered one thinks alone.
func _proximity_trigger(record: AiRecord, task_kind: AiTask.Kind) -> bool:
	if record.count == 1:
		return false
	var s := record.stddev.x * record.stddev.x + record.stddev.y * record.stddev.y + record.stddev.z * record.stddev.z
	var r := AiField.group_radius(record.count)
	if s < r * r:
		return false
	if s > (r * 4.0) * (r * 4.0):
		return false
	for m in record.members.duplicate():
		if not m.is_inert():
			node_slot19(m, task_kind, record, record.center)
	return true


## node vtbl[3] (shiny.d:2483-2491).
func node_brain(t: AiTrack, task_kind: AiTask.Kind, record: AiRecord) -> void:
	match t.kind:
		AiTrack.Kind.MANAHOAR:
			if maho_brain != null:
				maho_brain.think(t, task_kind, record)
			else:
				creature_brain.think(t, task_kind, record)
		AiTrack.Kind.CREATURE:
			creature_brain.think(t, task_kind, record)
		AiTrack.Kind.WIZARD:
			wizard_brain.think(t, task_kind, record)


## node vtbl[19] (shiny.d:2471-2481): a body that is already heading somewhere by its own brain keeps thinking; the
## others walk to the center of the record.
func node_slot19(t: AiTrack, task_kind: AiTask.Kind, record: AiRecord, pos: Vector3) -> void:
	if t.kind == AiTrack.Kind.NONE or t.kind == AiTrack.Kind.STRUCTURE:
		return
	var state := t.ord_state
	if state == AiCommandPort.AiOrder.MOVE_NEAR or state == AiCommandPort.AiOrder.GUARD or state == AiCommandPort.AiOrder.ATTACK or state == AiCommandPort.AiOrder.TAKE_SOUL:
		node_brain(t, task_kind, record)
	else:
		port.order_pos_radius(t, AiCommandPort.AiOrder.MOVE_NEAR, pos, 5.0)
