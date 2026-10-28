class_name AiTaskBoard
extends Node

## The board of tasks: every 60 ticks each task makes its records (`replan`), then in the order capture, guard, idle (the
## order of its children) the free creatures are handed to them; every 12 ticks each record updates: the brains of its
## members think (a clustered record) or, with a wizard as leader, the rest follow the wizard. Each brain gets the kind of the
## task (AiTask.Kind) whose record it is in.
## 024c has IdleTask and GuardTask; 024d adds CaptureTask (first: the order of its children is the order of the claim) and the
## Manahoar's own brain. Without a child task that kind of work does not happen. How a record moves is AiRecordRunner.
## Ref: RFC-024 §3.1 `AiTaskBoard`; shiny.d:2096-2346 replan and claim, 2350-2440 the order bridge, 3380-3427 `recordUpdate`.

@export var perception: AiPerception
@export var groups: AiGroups
@export var stance: AiStance
var play: AiPlay  # what the side plays with (AiSide.setup)
@export var wizard_brain: AiWizardBrain
@export var creature_brain: CreatureBrain
## The Manahoar thinks apart (mahoBrain); without it a Manahoar thinks like any creature.
@export var maho_brain: ManahoarBrain
@export var port: AiCommandPort

var tasks: Array[AiTask] = []
var runner: AiRecordRunner


func _init() -> void:
	runner = AiRecordRunner.new(self)


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
	for t: AiTrack in perception.bodies(0):
		if claimable(t):
			free.append(t)
	for task in tasks:
		task.claim(free)


## ntt vtbl[19]: any own body but a Sac Doctor or a dying one. The port also leaves out a creature being
## summoned (it cannot take orders yet) and one a Sac Doctor holds.
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
			runner.record_update(record, task_kind)


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


## densityGroups without the soul groups (slot 5): the soul worth of the enemy and neutral body groups
## near `pos`, over the most souls the side has seen.
## Ref: shiny.d:2042-2062
func density(pos: Vector3, near: float, far: float) -> float:
	var acc := 0.0
	for category in [2, 3]:
		for group: AiGroup in groups.list(category):
			if group.souls_sum == 0:
				continue
			acc += AiField.ramp(pos.distance_to(group.center), near, far) * float(group.souls_sum)
	## Deviation: with no souls seen (max 0) the engine divides 0/0 and every guard score becomes NaN, so nobody is escorted.
	## Here it is 0.
	## Ref: shiny.d:2062
	if perception.max_souls_seen <= 0:
		return 0.0
	return AiField.f32(AiField.safediv(acc, float(perception.max_souls_seen)))
