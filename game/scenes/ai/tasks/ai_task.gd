class_name AiTask
extends Node

## Contract of a task of the board.
## The board calls `replan()` (record the targets worth working on, every 60 ticks), then `claim()` (hand the free
## creatures to them, in the order capture, guard, idle) and, every 12 ticks, each member's brain thinks with the `kind()` of the
## task. A task is a child of AiTaskBoard: take it out and that kind of work is no longer done.
## Ref: RFC-024 §3.1 `AiTask`; shiny.d:98-104 `AITask`, 2096-2238 replan, 2240-2346 claim.

## FOCUS is not in the original. A brain reads the kind of its record's task (the original's
## taskCmd: capture 2, guard 1, and for idle a number no brain reads; here IDLE is 0 and no brain acts on it).
## Ref: shiny.d:98 TaskKind; RFC-053 053d
enum Kind { IDLE = 0, GUARD = 1, CAPTURE = 2, FOCUS = 3 }

@export var board: AiTaskBoard

## The records of the task, best score first.
## Ref: the «claimed» list, shiny.d:1888-1900
var records: Array[AiRecord] = []


func kind() -> Kind:
	return Kind.IDLE


func replan() -> void:
	records.clear()


## `free` is the list of own creatures nobody has claimed yet; claimed ones are removed from it.
## Returns the souls claimed.
func claim(_free: Array[AiTrack]) -> float:
	return 0.0


## sortedInsert: best score first, a new record before its ties.
## Ref: shiny.d:1879-1886
func insert_sorted(record: AiRecord) -> void:
	var at := 0
	while at < records.size() and records[at].score > record.score:
		at += 1
	records.insert(at, record)


## normalizeScores.
## Ref: shiny.d:1888-1892
func normalize(total: float) -> void:
	if total == 0.0:
		return
	for record in records:
		record.score = AiField.f32(AiField.safediv(record.score, total))


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not get_parent() is AiTaskBoard:
		warnings.append("Una tarea cuelga de un AiTaskBoard.")
	return warnings
