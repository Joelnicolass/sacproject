@tool
class_name RtsFormationCatalog
extends Resource

## The formations a game knows, in menu order: a tie of the majority goes to the first, and Alt+N picks
## the Nth. RtsOrders resolves a formation id against this list, so a formation that is not here is
## never used. The kit ships one (formations/formations.tres): line, flank_left, flank_right, phalanx,
## semicircle, circle, wedge, skirmish.

@export var formations: Array[RtsFormation] = []
@export var default_id: StringName = &"line"


func find(id: StringName) -> RtsFormation:
	for formation in formations:
		if formation != null and formation.id == id:
			return formation
	return null


func has_id(id: StringName) -> bool:
	return find(id) != null


func default_formation() -> RtsFormation:
	var found := find(default_id)
	if found == null and not formations.is_empty():
		return formations[0]
	return found
