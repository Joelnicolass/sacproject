class_name DecisionLog
extends Node

## The bench's record of what each AI side decided, one text line per decision, to compare two commits with `diff` (plan 055f §10.1).
## It only listens: the wizard's replans (the cast queue), the claims of the task board, what the perception starts and stops knowing,
## every run of the stance; at the end it adds the audit lines of the requests and of what happened (cast, summon, reject, lapse, order,
## manalith, desecrate, died, purse). It never reads through the perception's belief (no pos_of/health_of), so recording changes nothing.
## Off unless ai_match passes `--decisions=<file>`. Not in the product.
##
## Lines (floats to 1e-4, names of the nodes, «-» for none):
##   tick slot replan i phase spell target score range obj
##   tick slot task kind target score members leader
##   tick slot know +|- name origin
##   tick slot stance enemy_ratio threat
## then «# audit» and the audit lines of those kinds, as the recorder wrote them («tick kind text»).

const AUDIT_KINDS := ["cast", "summon", "reject", "lapse", "order", "manalith", "desecrate", "died", "purse"]

## The clock of every line (the bench's audit).
@export var audit: AiAudit

var path := ""
var lines := PackedStringArray()


## Starts recording into `file` (relative paths are relative to the project). The audit keeps its lines for the end.
func begin(file: String) -> void:
	path = DetCli.absolute(file)
	lines = PackedStringArray()
	if audit != null:
		audit.keep_lines = true


func is_on() -> bool:
	return not path.is_empty()


## Listens to one AI side (call after its setup).
func watch(side: AiSide) -> void:
	if not is_on():
		return
	var slot := side.slot
	side.brain.replanned.connect(_on_replanned.bind(slot))
	side.board.replanned.connect(_on_tasks.bind(slot))
	side.perception.tracked.connect(_on_known.bind("+", slot))
	side.perception.untracked.connect(_on_known.bind("-", slot))
	side.stance.updated.connect(_on_stance.bind(side))


## Writes the decision lines, then the audit lines of AUDIT_KINDS.
func write() -> void:
	if not is_on():
		return
	var out := lines.duplicate()
	out.append("# audit")
	if audit != null:
		for line in audit.lines:
			var parts := line.split(" ", false, 2)
			if parts.size() >= 2 and AUDIT_KINDS.has(parts[1]):
				out.append(line)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("DecisionLog: no se puede escribir %s" % path)
		return
	file.store_string("\n".join(out) + "\n")


func _tick() -> int:
	return audit.tick if audit != null else 0


func _on_replanned(_wizard: AiTrack, queue: Array, slot: int) -> void:
	for i in queue.size():
		var e: Dictionary = queue[i]
		var spell: Resource = e["spell"]
		lines.append("%d %d replan %d %s %s %s %s %s %s" % [_tick(), slot, i, _phase_of(spell), _tag(spell), _name(e["target"]),
			_num(float(e["score"])), _num(float(e["range"])), _name(e["obj"])])


func _on_tasks(tasks: Array[AiTask], slot: int) -> void:
	for task in tasks:
		var kind: String = AiTask.Kind.keys()[task.kind()]
		for record in task.records:
			var members := PackedStringArray()
			for m in record.members:
				members.append(_name(m))
			lines.append("%d %d task %s %s %s %s %s" % [_tick(), slot, kind, _name(record.target), _num(record.score),
				",".join(members) if not members.is_empty() else "-", _name(record.leader)])


func _on_known(track: AiTrack, mark: String, slot: int) -> void:
	lines.append("%d %d know %s %s %s" % [_tick(), slot, mark, _name(track), str(track.origin)])


func _on_stance(side: AiSide) -> void:
	var own: AiTrack = side.perception.find(side.wizard) if side.wizard != null and is_instance_valid(side.wizard) else null
	lines.append("%d %d stance %s %s" % [_tick(), side.slot, _num(side.stance.enemy_ratio()), _num(own.threat) if own != null else "-"])


## The phase that queued the entry, from the spell (the queue does not keep it): a creature is a summon, an altar spell is its use,
## any other spell its ai_phase.
static func _phase_of(spell: Resource) -> String:
	if spell is CreatureType:
		return "summon"
	if spell is SpellType:
		var type := spell as SpellType
		if type.ai_use == SpellType.AiUse.CONVERT or type.ai_use == SpellType.AiUse.DESECRATE:
			return str(SpellType.AiUse.keys()[type.ai_use]).to_lower()
		if type.is_structure:
			return "build"
		return str(SpellType.AiPhase.keys()[type.ai_phase]).to_lower()
	return "-"


static func _tag(spell: Resource) -> String:
	return str(spell.get("tag")) if spell != null else "-"


static func _name(t: Variant) -> String:
	var track := t as AiTrack
	if track == null or track.node == null or not is_instance_valid(track.node):
		return "-"
	return str(track.node.name)


static func _num(x: float) -> String:
	return "%.4f" % x
