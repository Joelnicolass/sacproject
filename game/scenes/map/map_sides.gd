@tool
class_name MapSides
extends Resource

## The SIDS of a map (RFC-035 035d): who is allied or enemy of whom, and which sides a player can take.
## One entry per side, the four arrays are parallel. `allies` and `enemies` are bit masks over the side ids
## (sacengine sids.d); `assignment` 0 is a side no player takes (the Farmers and the Taurocks of High Noon).
## SideRelations reads it. It is written once by tools/bake_map_layout.gd and edited in the inspector from then on.

@export var ids := PackedInt64Array()
@export var allies := PackedInt64Array()
@export var enemies := PackedInt64Array()
@export var assignment := PackedInt64Array()
## Palette index of the side in the original; the port colors sides by slot (SideColors), so it is kept as data only.
@export var colors := PackedInt64Array()


## The rows SideRelations.set_rows takes: [{id, allies, enemies, assignment}].
func to_rows() -> Array:
	var rows := []
	for k in ids.size():
		rows.append({
			"id": ids[k],
			"allies": allies[k] if k < allies.size() else 0,
			"enemies": enemies[k] if k < enemies.size() else 0,
			"assignment": assignment[k] if k < assignment.size() else 0,
		})
	return rows


## Builds the resource from the exporter's rows (tools/bake_map_layout.gd).
static func from_rows(rows: Array) -> MapSides:
	var sides := MapSides.new()
	for row: Variant in rows:
		if not row is Dictionary:
			continue
		sides.ids.append(int(row.get("id", -1)))
		sides.allies.append(int(row.get("allies", 0)))
		sides.enemies.append(int(row.get("enemies", 0)))
		sides.assignment.append(int(row.get("assignment", 0)))
		sides.colors.append(int(row.get("color", 0)))
	return sides
