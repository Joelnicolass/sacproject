class_name Attackable
extends RefCounted

## Which bodies a blow, a shot or a direct spell can take as a target: one list for the cursor
## (match_command), the ranged shot and the Rock. Splash spells keep their own groups.
## A body is one of these groups and not a corpse. Callers still check Health and is_targetable.

const GROUPS: Array[StringName] = [WizardBody.GROUP, UnitBody.GROUP, MapBuilding.STRUCTURE_GROUP, DoctorBody.GROUP]
const CORPSE := &"corpse"


static func is_body(node: Node) -> bool:
	if node == null or node.is_in_group(CORPSE):
		return false
	for group in GROUPS:
		if node.is_in_group(group):
			return true
	return false
