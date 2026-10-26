class_name AiRecordRunner
extends RefCounted

## How a record of the board moves every 12 ticks: its center, spread and movement are refreshed, then the brains of its members
## think (a clustered record) or, with a wizard as leader, the rest follow the wizard; a spread capture record first sends its
## members to the center. Each brain gets the kind of the task whose record it is in. It does not make records nor claim
## creatures (the tasks do). Ref: shiny.d:3380-3447 recordUpdate and proximityTrigger, 1915-1952 recordRefresh, 2471-2491 node vtbl.

## The board whose brains, port and play it uses (read at every call).
var board: AiTaskBoard
var records_updated := 0


func _init(p_board: AiTaskBoard) -> void:
	board = p_board


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
	var crowd := board.play.tactics.crowd
	if record.leader != null:
		for m in record.members.duplicate():
			if m.is_inert():
				continue
			if m == record.leader:
				var dx: float = m.cur_pos.x - record.center.x
				var dz: float = m.cur_pos.z - record.center.z
				if dx * dx + dz * dz <= crowd.record_near_m * crowd.record_near_m:
					node_brain(m, task_kind, record)
				else:
					node_slot19(m, task_kind, record, record.center)
			else:
				board.port.orders.order_pos_radius(m, AiCommandPort.AiOrder.ADVANCE, record.leader.extrap_pos, crowd.follow_radius_m)
		return
	if record.capture:
		var dx: float = record.anchor.x - record.center.x
		var dz: float = record.anchor.z - record.center.z
		if dx * dx + dz * dz <= crowd.record_near_m * crowd.record_near_m and _proximity_trigger(record, task_kind):
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
	var r := AiField.group_radius(record.count, board.play.tactics.crowd)
	if s < r * r:
		return false
	if s > (r * 4.0) * (r * 4.0):
		return false
	for m in record.members.duplicate():
		if not m.is_inert():
			node_slot19(m, task_kind, record, record.center)
	return true


## node vtbl[3] (shiny.d:2483-2491): the brain of the body's kind thinks.
func node_brain(t: AiTrack, task_kind: AiTask.Kind, record: AiRecord) -> void:
	match t.kind:
		AiTrack.Kind.MANAHOAR:
			if board.maho_brain != null:
				board.maho_brain.think(t, task_kind, record)
			else:
				board.creature_brain.think(t, task_kind, record)
		AiTrack.Kind.CREATURE:
			board.creature_brain.think(t, task_kind, record)
		AiTrack.Kind.WIZARD:
			board.wizard_brain.think(t, task_kind, record)


## node vtbl[19] (shiny.d:2471-2481): a body that is already heading somewhere by its own brain keeps thinking; the
## others walk to the center of the record.
func node_slot19(t: AiTrack, task_kind: AiTask.Kind, record: AiRecord, pos: Vector3) -> void:
	if t.kind == AiTrack.Kind.NONE or t.kind == AiTrack.Kind.STRUCTURE:
		return
	var state := t.ord_state
	if state == AiCommandPort.AiOrder.MOVE_NEAR or state == AiCommandPort.AiOrder.GUARD or state == AiCommandPort.AiOrder.ATTACK or state == AiCommandPort.AiOrder.TAKE_SOUL:
		node_brain(t, task_kind, record)
	else:
		board.port.orders.order_pos_radius(t, AiCommandPort.AiOrder.MOVE_NEAR, pos, 5.0)
