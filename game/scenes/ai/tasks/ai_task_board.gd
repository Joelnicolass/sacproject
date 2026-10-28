class_name AiTaskBoard
extends Node

## The board of tasks: every 60 ticks each task makes its records (`replan`), then in the order
## capture, guard, idle (the order of its children) the free creatures are handed to them; every 12
## ticks each record updates: the brains of its members think (a clustered record) or, with a wizard
## as leader, the rest follow the wizard. Each brain gets the kind of the task (AiTask.Kind) whose
## record it is in. 024c has IdleTask and GuardTask; 024d adds CaptureTask (first: the order of its
## children is the order of the claim) and the Manahoar's own brain. Without a child task that kind
## of work does not happen.
## Ref: RFC-024 §3.1 `AiTaskBoard`; shiny.d:2096-2346 replan and claim, 2350-2440 the order bridge,
## 3380-3427 `recordUpdate`.

## A member a record sends to its center holds within this of it.
const CENTER_HOLD_M := 5.0
## A record more spread than this times its group radius does not gather at its center.
const SPREAD_MAX_FACTOR := 4.0

@export var perception: AiPerception
@export var groups: AiGroups
@export var stance: AiStance
@export var wizard_brain: AiWizardBrain
@export var creature_brain: CreatureBrain
## The Manahoar thinks apart (mahoBrain); without it a Manahoar thinks like any creature.
@export var maho_brain: ManahoarBrain
@export var port: AiCommandPort

## What the side plays with (AiSide.setup).
var play: AiPlay
var tasks: Array[AiTask] = []
var records_updated := 0


func _ready() -> void:
	for child in get_children():
		if child is AiTask:
			(child as AiTask).board = self
			tasks.append(child)


## replanTasks: every task makes its records again.
## Ref: shiny.d:2096-2116
func replan_tasks() -> void:
	for t: AiTrack in perception.tracks.values():
		t.record = null
	for task in tasks:
		task.replan()


## claimPass.
## Ref: shiny.d:2240-2260
func claim_pass() -> void:
	var free: Array[AiTrack] = []
	for t: AiTrack in perception.bodies(AiTrack.Relation.OWN):
		if claimable(t):
			free.append(t)
	for task in tasks:
		task.claim(free)


## ntt vtbl[19]: any own body but a Sac Doctor or a dying one. The port also leaves out a creature
## being summoned (it cannot take orders yet) and one a Sac Doctor holds.
## Ref: shiny.d:1475-1478
static func claimable(t: AiTrack) -> bool:
	if not t.is_valid() or t.node.is_in_group(DoctorBody.GROUP):
		return false
	if AiBody.is_dead(t.node):
		return false
	if t.node is UnitBody and (t.node as UnitBody).is_summoning():
		return false
	if t.node is UnitBody and (t.node as UnitBody).is_taken():
		return false
	return true


## updateTasks.
## Ref: shiny.d:1402-1411
func update_tasks() -> void:
	for task in tasks:
		var task_kind := task.kind()
		for record in task.records.duplicate():
			_record_update(record, task_kind)


## recordSetup. `capture`: a capture record (its members go to the anchor, see record_update).
## Ref: shiny.d:1938-1951
func new_record(target: AiTrack, capture := false) -> AiRecord:
	var record := AiRecord.new()
	record.target = target
	record.anchor = target.cur_pos if target != null else Vector3.ZERO
	record.capture = capture
	return record


## claim: the track leaves the free list and joins the record. Returns its soul worth.
## Ref: shiny.d:1964-1977
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


## Distances from `from` to the altars of `relation`.
## Ref: probOr, shiny.d:2012-2022
func distances_to_altars(from: AiTrack, relation: AiTrack.Relation) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for t: AiTrack in perception.structures(relation):
		if t == from or not t.is_altar():
			continue
		out.append(from.cur_pos.distance_to(t.cur_pos))
	return out


## densityGroups without the soul groups (slot 5): the soul worth of the enemy and neutral body
## groups near `pos`, over the most souls the side has seen.
## Ref: shiny.d:2042-2062
func density(pos: Vector3, near: float, far: float) -> float:
	var acc := 0.0
	for relation in [AiTrack.Relation.NEUTRAL, AiTrack.Relation.ENEMY]:
		for group: AiGroup in groups.list(relation):
			if group.souls_sum == 0:
				continue
			acc += AiField.ramp(pos.distance_to(group.center), near, far) * float(group.souls_sum)
	# Deviation: with no souls seen (max 0) the engine divides 0/0 and every guard score becomes
	# NaN, so nobody is escorted. Here it is 0.
	# Ref: shiny.d:2062
	if perception.max_souls_seen <= 0:
		return 0.0
	return AiField.f32(AiField.safediv(acc, float(perception.max_souls_seen)))


## recordRefresh: center, spread and movement of the members.
## Ref: shiny.d:1915-1952
func _refresh_record(record: AiRecord) -> void:
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
			sum_sq += Vector3(
				t.cur_pos.x * t.cur_pos.x, t.cur_pos.y * t.cur_pos.y, t.cur_pos.z * t.cur_pos.z
			)
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
			sqrt(absf(sum_sq.z * inv - record.center.z * record.center.z))
		)
	record.predicted = record.center + record.vel_acc


## recordUpdate.
## Ref: shiny.d:3408-3447
func _record_update(record: AiRecord, task_kind: AiTask.Kind) -> void:
	if record.count == 0 and record.members.is_empty():
		return
	_refresh_record(record)
	records_updated += 1
	if record.count == 0:
		return
	var crowd := play.tactics.crowd
	if record.leader != null:
		for m in record.members.duplicate():
			if m.is_inert():
				continue
			if m == record.leader:
				var dx: float = m.cur_pos.x - record.center.x
				var dz: float = m.cur_pos.z - record.center.z
				if dx * dx + dz * dz <= crowd.record_near_m * crowd.record_near_m:
					_node_brain(m, task_kind, record)
				else:
					_node_slot19(m, task_kind, record, record.center)
			else:
				port.orders.order_pos_radius(
					m,
					AiCommandPort.AiOrder.ADVANCE,
					record.leader.extrap_pos,
					crowd.follow_radius_m
				)
		return
	if record.capture:
		var dx: float = record.anchor.x - record.center.x
		var dz: float = record.anchor.z - record.center.z
		if (
			dx * dx + dz * dz <= crowd.record_near_m * crowd.record_near_m
			and _proximity_trigger(record, task_kind)
		):
			return
	for m in record.members.duplicate():
		if m.is_inert():
			continue
		_node_brain(m, task_kind, record)


## proximityTrigger: a spread record sends each member to the center; a clustered one thinks alone.
## Ref: shiny.d:3389-3406
func _proximity_trigger(record: AiRecord, task_kind: AiTask.Kind) -> bool:
	if record.count == 1:
		return false
	var s := (
		record.stddev.x * record.stddev.x
		+ record.stddev.y * record.stddev.y
		+ record.stddev.z * record.stddev.z
	)
	var r := AiField.group_radius(record.count, play.tactics.crowd)
	if s < r * r:
		return false
	if s > (r * SPREAD_MAX_FACTOR) * (r * SPREAD_MAX_FACTOR):
		return false
	for m in record.members.duplicate():
		if not m.is_inert():
			_node_slot19(m, task_kind, record, record.center)
	return true


## node vtbl[3]: the brain of the body's kind thinks.
## Ref: shiny.d:2483-2491
func _node_brain(t: AiTrack, task_kind: AiTask.Kind, record: AiRecord) -> void:
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


## node vtbl[19]: a body that is already heading somewhere by its own brain keeps thinking; the
## others walk to the center of the record.
## Ref: shiny.d:2471-2481
func _node_slot19(t: AiTrack, task_kind: AiTask.Kind, record: AiRecord, pos: Vector3) -> void:
	if t.kind == AiTrack.Kind.NONE or t.kind == AiTrack.Kind.STRUCTURE:
		return
	var state := t.ord_state
	if (
		state == AiCommandPort.AiOrder.MOVE_NEAR
		or state == AiCommandPort.AiOrder.GUARD
		or state == AiCommandPort.AiOrder.ATTACK
		or state == AiCommandPort.AiOrder.TAKE_SOUL
	):
		_node_brain(t, task_kind, record)
	else:
		port.orders.order_pos_radius(t, AiCommandPort.AiOrder.MOVE_NEAR, pos, CENTER_HOLD_M)
