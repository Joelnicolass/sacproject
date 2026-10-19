class_name AiTask
extends Node

## Contract of a task of the board (RFC-024 §3.1 `AiTask`; shiny.d:98-104 `AITask`, 2096-2238 replan, 2240-2346 claim).
## The board calls `replan()` (record the targets worth working on, every 60 ticks), then `claim()` (hand the free
## creatures to them, in the order capture, guard, idle) and, every 12 ticks, `command()` gives the number each member's
## brain reads. A task is a child of AiTaskBoard: take it out and that kind of work is no longer done.

## shiny.d:98 TaskKind.
## FOCUS (RFC-053 053d) is not in the original.
enum Kind { IDLE = 0, GUARD = 1, CAPTURE = 2, FOCUS = 3 }

@export var board: AiTaskBoard

## The records of the task, best score first (the «claimed» list, shiny.d:1888-1900).
var records: Array[AiRecord] = []


func kind() -> Kind:
	return Kind.IDLE


## taskCmd (shiny.d:1412-1418): capture 2, guard 1, idle 0x64692e70 (a number no brain reads); FocusTask 3 (F373).
func command() -> int:
	return 0x64692e70


func replan() -> void:
	records.clear()


## `free` is the list of own creatures nobody has claimed yet; claimed ones are removed from it.
## Returns the souls claimed.
func claim(_free: Array[AiTrack]) -> float:
	return 0.0


## sortedInsert (shiny.d:1879-1886): best score first, a new record before its ties.
func insert_sorted(record: AiRecord) -> void:
	var at := 0
	while at < records.size() and records[at].score > record.score:
		at += 1
	records.insert(at, record)


## normalizeScores (shiny.d:1888-1892).
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
