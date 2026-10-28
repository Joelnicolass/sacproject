class_name IdleTask
extends AiTask

## The creatures nobody claimed: one record with no target and score 0; every creature nobody else
## claimed goes in it. When a wizard is among them it leads the record and the rest follow it: the
## army stays with the wizard.
## Ref: shiny.d:2231-2237 `replanIdle`, 2300-2310 `claimIdle`; recordUpdate, shiny.d:3408-3427


func kind() -> Kind:
	return Kind.IDLE


func replan() -> void:
	records.clear()
	var record := board.new_record(null)
	insert_sorted(record)


func claim(free: Array[AiTrack]) -> float:
	if records.is_empty():
		return 0.0
	var record := records[0]
	var total := 0.0
	for t in free.duplicate():
		board.claim_member(record, free, t)
		total += t.sort_key()
	return total
