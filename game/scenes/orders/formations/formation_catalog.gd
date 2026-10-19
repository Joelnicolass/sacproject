class_name FormationCatalog
extends Resource

## The formations a match knows, in the order of the original's menu (ties of the majority go to the first).
## The server resolves a formation id against this list: a Resource never travels over the network.

@export var formations: Array[FormationType] = []
@export var default_id: StringName = &"line"


func find(id: StringName) -> FormationType:
	for formation in formations:
		if formation.id == id:
			return formation
	return null


func has_id(id: StringName) -> bool:
	return find(id) != null


func default_formation() -> FormationType:
	return find(default_id)
