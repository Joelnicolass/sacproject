@tool
class_name MapSides
extends RefCounted

## Who is allied or enemy of whom on a map, read from the nodes the map already has instead of a table: every PlayerStart is
## a seat (side = slot - 1; `team` above 0 allies the seats that share it, 0 stands alone), every other side an NpcSpawn
## names (Farmers, Taurocks) is a side no player takes, and side 31 is the neutral owner of the houses. All sides are enemies
## of each other except teammates; nobody is an enemy of the neutral side. SideRelations reads the rows.
## Does not instance the map: it reads the stored properties of the scene (PackedScene.get_state).

const NEUTRAL_SIDE := 31


## The rows SideRelations.use reads: [{id, allies, enemies, assignment}]. Empty when the scene has no PlayerStart.
static func rows_of(scene: PackedScene) -> Array:
	var seats: Dictionary = {}
	var npc_sides: Dictionary = {}
	if scene == null:
		return []
	var state := scene.get_state()
	for i in state.get_node_count():
		var kind := state.get_node_instance(i)
		if kind == null:
			continue
		if kind.resource_path == PlayerStart.SCENE_PATH:
			seats[int(_stored(state, i, &"slot", 1)) - 1] = int(_stored(state, i, &"team", 0))
		elif kind.resource_path == NpcSpawn.SCENE_PATH:
			npc_sides[int(_stored(state, i, &"side", 0))] = true
	if seats.is_empty():
		return []
	for seat: int in seats:
		npc_sides.erase(seat)
	var ids: Array = seats.keys() + npc_sides.keys()
	var rows := []
	for id: int in ids:
		var team := int(seats.get(id, 0))
		var allies := 1 << id
		var enemies := 0
		for other: int in ids:
			if other == id:
				continue
			if team > 0 and int(seats.get(other, 0)) == team:
				allies |= 1 << other
			else:
				enemies |= 1 << other
		rows.append(
			{
				"id": id,
				"allies": allies,
				"enemies": enemies,
				"assignment": id + 1 if seats.has(id) else 0
			}
		)
	rows.append({"id": NEUTRAL_SIDE, "allies": 0, "enemies": 0, "assignment": 0})
	return rows


## The value a node of the scene stores for `property`, or `fallback` when it keeps the default of its scene.
static func _stored(
	state: SceneState, node: int, property: StringName, fallback: Variant
) -> Variant:
	for k in state.get_node_property_count(node):
		if state.get_node_property_name(node, k) == property:
			return state.get_node_property_value(node, k)
	return fallback
