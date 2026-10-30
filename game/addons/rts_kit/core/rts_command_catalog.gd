@tool
class_name RtsCommandCatalog
extends Resource

## The kinds of order a game knows (RtsCommandType), looked up by id. RtsOrders resolves an order's id
## here, so a command that is not in the catalog is never applied. The kit ships one with move,
## attack, guard, guard_area, attack_move and retreat (commands/commands.tres); a game makes its own.

@export var commands: Array[RtsCommandType] = []


func find(id: StringName) -> RtsCommandType:
	for command in commands:
		if command != null and command.id == id:
			return command
	return null


func has_id(id: StringName) -> bool:
	return find(id) != null
